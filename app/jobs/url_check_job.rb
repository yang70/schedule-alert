class UrlCheckJob < ApplicationJob
  queue_as :default

  def perform(monitored_url_id)
    monitored_url = MonitoredUrl.find_by(id: monitored_url_id)
    return unless monitored_url&.active?

    # Fetch the URL content
    response = HTTParty.get(monitored_url.url, timeout: 10, follow_redirects: true)

    return unless response.success?

    content = response.body
    content_hash = Digest::SHA256.hexdigest(content)

    # Get the last snapshot
    last_snapshot = monitored_url.schedule_snapshots.ordered.first

    # Check if this is the first check or if content has changed
    is_first_check = last_snapshot.nil?
    content_changed = !is_first_check && last_snapshot.content_hash != content_hash

    # Use AI to analyze the content
    ai_service = OpenAiService.new
    analysis_result = ai_service.analyze_schedule(content, last_snapshot&.content)

    schedule_now_available = analysis_result[:schedule_available]
    schedule_changed = analysis_result[:schedule_changed]
    ai_summary = analysis_result[:summary]

    # Create a new snapshot
    snapshot = monitored_url.schedule_snapshots.create!(
      content: content,
      content_hash: content_hash,
      ai_summary: ai_summary,
      checked_at: Time.current,
      changes_detected: content_changed && (schedule_changed || schedule_now_available)
    )

    # Update the monitored URL
    monitored_url.update!(
      last_checked_at: Time.current,
      schedule_available: schedule_now_available
    )

    # Send notifications if needed
    if is_first_check && schedule_now_available
      NotificationMailer.schedule_now_available(monitored_url, snapshot).deliver_later
    elsif schedule_changed && !is_first_check
      NotificationMailer.schedule_changed(monitored_url, snapshot, last_snapshot).deliver_later
    end

  rescue HTTParty::Error, Net::OpenTimeout, SocketError => e
    Rails.logger.error "Failed to check URL #{monitored_url.url}: #{e.message}"
  end
end
