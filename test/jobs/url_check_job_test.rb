require "test_helper"

class UrlCheckJobTest < ActiveSupport::TestCase
  Service = Struct.new(:release_result, :games_result, :calls, :release_error, :games_error) do
    def analyze_schedule(*, **)
      calls << :release
      raise release_error if release_error
      release_result
    end

    def extract_schedule(*, **)
      calls << :games
      raise games_error if games_error
      games_result
    end
  end

  def game(monitored, time = "10:00")
    { date: monitored.tournament_start_date.iso8601, time: time, team1: "Falcons", team2: nil, location: nil, status: "scheduled" }
  end

  def service(monitored, posted: true, games: nil)
    Service.new({ status: posted ? "posted" : "not_posted", summary: posted ? "Schedule posted" : "Coming soon", evidence: [], metadata: {} }, { games: games || [ game(monitored) ], metadata: {} }, [])
  end

  def run_check(monitored, content:, ai:)
    monitored.request_check!
    monitored.reload
    args = [ monitored.id, monitored.source_revision, monitored.check_token ]
    ScheduleFetcher.stub(:new, Struct.new(:text) { def fetch(*); text; end }.new(content)) do
      OpenAiService.stub(:new, ai) { UrlCheckJob.perform_now(*args) }
    end
    monitored.reload
    args
  end

  test "release commits one durable email event and switches to daily checks" do
    monitored = create_url(notification_email: "alternate@example.com")
    ai = service(monitored)
    args = run_check(monitored, content: "Posted game", ai: ai)
    assert monitored.schedule_available?
    assert_equal "complete", monitored.check_status
    assert_equal monitored.source_revision, monitored.release_notified_revision
    event = monitored.notification_events.sole
    assert_equal "released", event.kind
    assert_equal "alternate@example.com", event.payload["recipient"]
    assert_equal [ [ 10, 0 ] ], monitored.todays_check_hours
    UrlCheckJob.perform_now(*args)
    assert_equal 1, monitored.notification_events.count
    assert_equal [ :release, :games ], ai.calls
  end

  test "unchanged waiting pages reuse successful negative analyses" do
    monitored = create_url
    ai = service(monitored, posted: false)
    2.times { run_check(monitored, content: "Coming soon", ai: ai) }
    assert_equal [ :release ], ai.calls
    assert_equal 1, monitored.schedule_snapshots.count
    assert_empty monitored.notification_events
    assert_equal "complete", monitored.check_status
  end

  test "fetch and AI errors preserve availability and baseline and schedule a retry" do
    monitored = create_url
    run_check(monitored, content: "Posted game", ai: service(monitored))
    baseline = monitored.schedule_data
    checked_at = monitored.last_checked_at
    failing = service(monitored)
    failing.release_error = OpenAiService::Error.new("AI temporarily unavailable")
    run_check(monitored, content: "Changed page during outage", ai: failing)
    assert monitored.schedule_available?
    assert_equal baseline, monitored.schedule_data
    assert_equal checked_at, monitored.last_checked_at
    assert_equal "error", monitored.check_status
    assert monitored.next_check_at > Time.current
    assert_equal 1, monitored.notification_events.count
    run_check(monitored, content: "Posted game", ai: service(monitored))
    assert_equal 1, monitored.notification_events.count
    monitored.request_check!
    ScheduleFetcher.stub(:new, Object.new.tap { |fetcher| def fetcher.fetch(*); raise MonitoringError, "HTTP 403"; end }) do
      UrlCheckJob.perform_now(monitored.id, monitored.source_revision, monitored.check_token)
    end
    assert monitored.reload.schedule_available?
    assert_equal baseline, monitored.schedule_data
  end

  test "detail extraction failure cannot suppress a release and is retried separately" do
    monitored = create_url
    incomplete = service(monitored)
    incomplete.games_error = OpenAiService::Error.new("Incomplete game table")
    run_check(monitored, content: "Posted date/time with TBD opponents", ai: incomplete)
    assert monitored.schedule_available?
    assert_equal "warning", monitored.check_status
    assert_equal "released", monitored.notification_events.sole.kind
    recovered = service(monitored)
    run_check(monitored, content: "Posted date/time with TBD opponents", ai: recovered)
    assert_equal [ :games ], recovered.calls
    assert monitored.schedule_data.present?
    assert_equal 1, monitored.notification_events.count
  end

  test "reordering and cosmetic formats do not alert but changed times do" do
    monitored = create_url
    original = [ game(monitored), game(monitored, "14:30").merge(team1: "Owls") ]
    run_check(monitored, content: "Original timetable", ai: service(monitored, games: original))
    reordered = original.reverse.map { |item| item.merge(team1: item[:team1].downcase) }
    run_check(monitored, content: "Timetable with a new advertisement", ai: service(monitored, games: reordered))
    assert_equal 1, monitored.notification_events.count
    updated = [ game(monitored, "11:00"), original.last ]
    run_check(monitored, content: "Updated timetable", ai: service(monitored, games: updated))
    event = monitored.notification_events.order(:id).last
    assert_equal "changed", event.kind
    assert_includes event.payload["summary"], "10:00"
    assert_includes event.payload["summary"], "11:00"
  end

  test "queued emails survive page snapshot pruning" do
    monitored = create_url
    run_check(monitored, content: "First timetable", ai: service(monitored))
    first_event = monitored.notification_events.sole
    run_check(monitored, content: "Second timetable", ai: service(monitored, games: [ game(monitored, "11:00") ]))
    run_check(monitored, content: "Third timetable", ai: service(monitored, games: [ game(monitored, "12:00") ]))
    assert_equal 2, monitored.schedule_snapshots.count
    assert_difference "ActionMailer::Base.deliveries.size", 1 do
      DeliverNotificationJob.perform_now(first_event.id)
    end
    assert first_event.reload.delivered_at
    assert_no_difference "ActionMailer::Base.deliveries.size" do
      DeliverNotificationJob.perform_now(first_event.id)
    end
  end

  test "source edits discard an in-flight result" do
    monitored = create_url
    monitored.request_check!
    args = [ monitored.id, monitored.source_revision, monitored.check_token ]
    fetcher = Object.new
    fetcher.define_singleton_method(:fetch) do |_url|
      MonitoredUrl.find(monitored.id).update!(url: "https://example.org/new")
      "Old page result"
    end
    ScheduleFetcher.stub(:new, fetcher) do
      OpenAiService.stub(:new, service(monitored)) { UrlCheckJob.perform_now(*args) }
    end
    assert_not monitored.reload.schedule_available?
    assert_empty monitored.notification_events
    assert_empty monitored.schedule_snapshots
    assert_equal args[1] + 1, monitored.source_revision
  end

  test "event creation failure rolls back snapshot and release state" do
    monitored = create_url
    callback = -> { raise "Simulated database-side failure" }
    NotificationEvent.set_callback(:create, :after, callback)
    assert_raises(RuntimeError) { run_check(monitored, content: "Posted timetable", ai: service(monitored)) }
    assert_not monitored.reload.schedule_available?
    assert_equal 0, monitored.release_notified_revision
    assert_empty monitored.schedule_snapshots
    assert_empty monitored.notification_events
  ensure
    NotificationEvent.skip_callback(:create, :after, callback) if callback
  end
end
