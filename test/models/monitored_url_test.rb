require "test_helper"

class MonitoredUrlTest < ActiveSupport::TestCase
  test "rejects private, numeric encoded and unsafe URLs" do
    monitored = create_url
    [ "http://127.0.0.1", "http://169.254.169.254/latest/meta-data", "http://2130706433", "http://0x7f.0.0.1", "https://user:pass@example.com", "javascript:alert('https://example.com')", "https://example.com:3000", "http://[::ffff:127.0.0.1]" ].each do |url|
      monitored.url = url
      assert_not monitored.valid?, url
      assert monitored.errors[:url].present?, url
    end
  end

  test "does not allow attaching another users person" do
    person = create_user(email: "other@example.com").people.create!(name: "Private player", color: "#123456")
    monitored = create_url
    monitored.person_id = person.id
    assert_not monitored.valid?
    monitored.person_id = 999_999
    assert_not monitored.valid?
  end

  test "alternate emails only require valid format" do
    monitored = create_url(notification_email: "someone-else@example.com")
    assert monitored.valid?
    monitored.notification_email = "not an email"
    assert_not monitored.valid?
  end

  test "Pacific start date remains eligible throughout its evening" do
    travel_to Time.utc(2026, 10, 15, 1) do
      monitored = create_url(tournament_start_date: Date.new(2026, 10, 14))
      assert monitored.eligible_for_check?
      assert_equal 0, monitored.days_until_tournament
      assert_equal Time.zone.local(2026, 10, 14, 22), monitored.next_check_at
    end
  end

  test "released schedules use one daily slot and stop after the start date" do
    travel_to Time.zone.local(2026, 10, 13, 9) do
      monitored = create_url(tournament_start_date: Date.new(2026, 10, 17))
      assert_equal 6, monitored.todays_check_hours.size
      monitored.update!(schedule_available: true, release_notified_revision: monitored.source_revision)
      assert_equal [ [ 10, 0 ] ], monitored.todays_check_hours
      monitored.update!(schedule_available: false)
      assert_equal [ [ 10, 0 ] ], monitored.todays_check_hours
      travel_to Time.zone.local(2026, 10, 18, 0)
      assert_not monitored.eligible_for_check?
      assert_nil monitored.calculate_next_check_time
    end
  end

  test "no automatic checks are dispatched after the last slot on the start date" do
    travel_to Time.zone.local(2026, 10, 13, 18) do
      monitored = create_url(tournament_start_date: Date.current)
      assert_nil monitored.next_check_at
      assert_not_includes MonitoredUrl.due_for_check, monitored
    end
  end

  test "date and source edits reset the comparison revision and reschedule" do
    travel_to Time.zone.local(2026, 10, 12, 11) do
      monitored = create_url(tournament_start_date: Date.new(2026, 10, 30), schedule_available: true)
      revision = monitored.source_revision
      monitored.update!(tournament_start_date: Date.new(2026, 10, 13))
      assert_equal revision + 1, monitored.source_revision
      assert_not monitored.schedule_available?
      assert_equal Time.zone.local(2026, 10, 12, 12), monitored.next_check_at
      monitored.update!(url: "https://example.org/new-schedule")
      assert_equal revision + 2, monitored.source_revision
    end
  end

  test "manual checks enqueue once and enforce cooldown" do
    monitored = create_url
    assert_enqueued_with(job: UrlCheckJob) { assert_equal :queued, monitored.request_check!(manual: true) }
    token = monitored.check_token
    assert_no_enqueued_jobs { assert_equal :busy, monitored.request_check!(manual: true) }
    assert_equal token, monitored.reload.check_token
    monitored.update_columns(check_token: nil, last_attempt_at: Time.current)
    assert_no_enqueued_jobs { assert_equal :cooldown, monitored.request_check!(manual: true) }
  end

  test "account counts update without loading associations" do
    monitored = create_url
    user = monitored.user
    assert_equal 1, user.reload.monitored_urls_count
    monitored.destroy!
    assert_equal 0, user.reload.monitored_urls_count
  end

  test "pausing a URL cancels its pending lease without resetting release history" do
    monitored = create_url(schedule_available: true)
    monitored.request_check!
    monitored.update!(active: false)
    assert_nil monitored.check_token
    assert_nil monitored.next_check_at
    assert_equal "idle", monitored.check_status
    assert monitored.schedule_available?
  end

  test "a busy queue does not repeatedly replace waiting jobs" do
    monitored = create_url
    monitored.request_check!
    monitored.update_columns(check_enqueued_at: 20.minutes.ago, next_check_at: 1.minute.ago)
    assert_equal :busy, monitored.request_check!
    assert_not_includes MonitoredUrl.due_for_check, monitored
    monitored.update_columns(check_status: "running", check_started_at: 20.minutes.ago)
    assert_includes MonitoredUrl.due_for_check, monitored
    assert_equal :queued, monitored.request_check!
  end
end
