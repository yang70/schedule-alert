class UrlCheckJob < ApplicationJob
  queue_as :checks

  def perform(monitored_url_id, revision = nil, token = nil)
    monitored_url = MonitoredUrl.find_by(id: monitored_url_id)
    return unless monitored_url
    # Jobs queued before this migration use the old one-argument signature.
    return monitored_url.request_check! unless revision && token
    claimed = monitored_url.with_lock do
      next false unless current_claim?(monitored_url, revision, token) && monitored_url.eligible_for_check?
      next false if monitored_url.check_status == "running" && monitored_url.check_started_at && monitored_url.check_started_at > MonitoredUrl::CHECK_LEASE.ago
      monitored_url.update_columns(check_status: "running", check_started_at: Time.current, last_attempt_at: Time.current)
      true
    end
    return unless claimed

    fetched = ScheduleFetcher.new.fetch(monitored_url.url)
    content = fetched.respond_to?(:text) ? fetched.text : fetched
    complete = !fetched.respond_to?(:complete) || fetched.complete
    content_hash = Digest::SHA256.hexdigest(content)
    release = ScheduleAnalysis.for_content(url: monitored_url.url, tournament_date: monitored_url.tournament_start_date, content: content) do
      OpenAiService.new.analyze_schedule(content, tournament_date: monitored_url.tournament_start_date)
    end
    raise OpenAiService::Error, "Some linked schedule content was unreadable; the release status is uncertain" if release[:status] != "posted" && !complete
    details = nil
    detail_warning = nil
    if release[:status] == "posted" && !complete
      detail_warning = "Schedule detected, but some linked content could not be read. Full change comparison will be retried."
    elsif release[:status] == "posted"
      begin
        details = ScheduleAnalysis.for_content(url: monitored_url.url, tournament_date: monitored_url.tournament_start_date, content: content, purpose: "games") do
          OpenAiService.new.extract_schedule(content, tournament_date: monitored_url.tournament_start_date)
        end
      rescue MonitoringError
        detail_warning = "Schedule detected, but a full game comparison was unavailable. Details will be retried at the next check."
      end
    end
    commit_result(monitored_url, revision, token, content, content_hash, release, details, detail_warning)
  rescue MonitoringError => error
    record_failure(monitored_url, revision, token, error.message)
    Rails.logger.warn("Schedule check failed id=#{monitored_url_id} error=#{error.class.name}")
  rescue StandardError => error
    record_failure(monitored_url, revision, token, "The check failed unexpectedly and will be retried.")
    Rails.logger.error("Schedule check failed id=#{monitored_url_id} error=#{error.class.name}")
    raise
  end

  private

  def current_claim?(monitored_url, revision, token)
    monitored_url.source_revision == revision && monitored_url.check_token == token
  end

  def commit_result(monitored_url, revision, token, content, content_hash, release, details, warning)
    monitored_url.with_lock do
      next unless current_claim?(monitored_url, revision, token)
      unless monitored_url.eligible_for_check?
        monitored_url.update_columns(check_token: nil, check_status: "idle", next_check_at: nil)
        next
      end
      last_snapshot = monitored_url.schedule_snapshots.where(source_revision: revision).ordered.first
      previous = monitored_url.schedule_data || last_snapshot&.schedule_data
      previous = ScheduleData.normalize(previous) unless previous.nil?
      games = details ? ScheduleData.normalize(details[:games]) : nil
      posted = release[:status] == "posted"
      released = posted && monitored_url.release_notified_revision != revision
      removed = !posted && monitored_url.schedule_available?
      changed = !released && (removed || (games && previous && games != previous))
      summary = if removed
        "The previously published schedule is no longer visible on the source page."
      elsif changed
        ScheduleData.change_summary(previous, games)
      else
        release[:summary]
      end
      metadata = { release: release[:metadata], games: details&.dig(:metadata), cache_version: OpenAiService.cache_version }
      if !last_snapshot || last_snapshot.content_hash != content_hash || changed || last_snapshot.analysis_metadata["cache_version"] != OpenAiService.cache_version
        snapshot = monitored_url.schedule_snapshots.create!(
          content: content, content_hash: content_hash, source_revision: revision,
          checked_at: Time.current, ai_summary: summary, evidence: release[:evidence],
          schedule_data: games, analysis_metadata: metadata, changes_detected: changed
        )
      end
      if released || changed
        key = released ? "#{revision}:released" : "#{revision}:change:#{snapshot.id}"
        monitored_url.notification_events.create!(
          event_key: key, kind: released ? "released" : "changed", next_delivery_at: Time.current,
          payload: {
            name: monitored_url.name, url: monitored_url.url,
            recipient: monitored_url.notification_email.presence || monitored_url.user.email,
            summary: summary, evidence: release[:evidence], checked_at: Time.current.iso8601
          }
        )
      end
      monitored_url.schedule_available = posted
      monitored_url.release_notified_revision = revision if released
      monitored_url.update_columns(
        schedule_available: posted, release_notified_revision: monitored_url.release_notified_revision,
        schedule_data: posted ? (games || monitored_url.schedule_data || previous) : [],
        last_checked_at: Time.current, failure_count: 0, last_error: warning,
        check_status: warning ? "warning" : "complete", check_token: nil,
        check_started_at: nil, next_check_at: monitored_url.calculate_next_check_time
      )
      old_ids = monitored_url.schedule_snapshots.ordered.offset(2).pluck(:id)
      monitored_url.schedule_snapshots.where(id: old_ids).delete_all if old_ids.any?
    end
  end

  def record_failure(monitored_url, revision, token, message)
    return unless monitored_url && revision && token
    monitored_url.reload
    monitored_url.with_lock do
      next unless current_claim?(monitored_url, revision, token)
      failures = monitored_url.failure_count + 1
      retry_time = failures <= 3 ? [ 1, 5, 15 ][failures - 1].minutes.from_now : monitored_url.calculate_next_check_time
      retry_time = nil unless monitored_url.eligible_for_check? && retry_time&.to_date&.<=(monitored_url.tournament_start_date)
      monitored_url.update_columns(
        check_status: "error", last_error: message.first(250), failure_count: failures,
        check_token: nil, check_started_at: nil, next_check_at: retry_time
      )
    end
  rescue ActiveRecord::RecordNotFound
    nil
  end
end
