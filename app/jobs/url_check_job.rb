class UrlCheckJob < ApplicationJob
  queue_as :default

  def perform(monitored_url_id)
    monitored_url = MonitoredUrl.find_by(id: monitored_url_id)
    return unless monitored_url&.active?

    # Fetch the URL content
    response = HTTParty.get(monitored_url.url, timeout: 10, follow_redirects: true)

    # Handle 4xx errors (content not yet available)
    if response.code >= 400 && response.code < 500
      monitored_url.update!(
        last_checked_at: Time.current,
        schedule_available: false
      )
      return
    end

    return unless response.success?

    content = response.body
    content_hash = Digest::SHA256.hexdigest(content)

    # Get the last snapshot
    last_snapshot = monitored_url.schedule_snapshots.ordered.first

    # Check if this is the first check or if content has changed
    is_first_check = last_snapshot.nil?
    content_changed = !is_first_check && last_snapshot.content_hash != content_hash

    # If content hasn't changed and schedule already detected, skip AI analysis
    if !is_first_check && !content_changed && monitored_url.schedule_available
      monitored_url.update!(last_checked_at: Time.current)
      return
    end

    # Use AI to analyze the content (only when content changed or first check)
    ai_service = OpenAiService.new
    analysis_result = ai_service.analyze_schedule(content, last_snapshot&.content)

    schedule_now_available = analysis_result[:schedule_available]
    schedule_changed = analysis_result[:schedule_changed]
    ai_summary = analysis_result[:summary]

    # Check if schedule just became available
    schedule_became_available = !monitored_url.schedule_available && schedule_now_available

    # Check if the actual schedule data (games) changed by comparing JSON
    actual_schedule_changed = false
    if !is_first_check && last_snapshot&.schedule_data && analysis_result[:schedule_data]
      # Compare the schedule_data JSON to see if games actually changed
      actual_schedule_changed = last_snapshot.schedule_data != analysis_result[:schedule_data]
    end

    # Create snapshot when content changed or schedule became available
    snapshot = nil
    if is_first_check || content_changed || schedule_became_available
      snapshot = monitored_url.schedule_snapshots.create!(
        content: content,
        content_hash: content_hash,
        ai_summary: ai_summary,
        schedule_data: analysis_result[:schedule_data],
        checked_at: Time.current,
        changes_detected: actual_schedule_changed
      )

      # Keep only the 2 most recent snapshots (need 2 for comparison)
      old_snapshots = monitored_url.schedule_snapshots.ordered.offset(2)
      old_snapshots.destroy_all if old_snapshots.any?
    end

    # Update the monitored URL
    monitored_url.update!(
      last_checked_at: Time.current,
      schedule_available: schedule_now_available
    )

    # Send notifications if needed
    if schedule_became_available && snapshot
      NotificationMailer.schedule_now_available(monitored_url, snapshot).deliver_later
    elsif actual_schedule_changed && !is_first_check && snapshot
      NotificationMailer.schedule_changed(monitored_url, snapshot, last_snapshot).deliver_later
    end

  rescue HTTParty::Error, Net::OpenTimeout, SocketError => e
    Rails.logger.error "Failed to check URL #{monitored_url.url}: #{e.message}"
  end
end
