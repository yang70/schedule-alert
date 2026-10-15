class NotificationMailer < ApplicationMailer
  def schedule_event(payload, kind, event_id)
    @payload = payload
    @checked_at = Time.iso8601(payload.fetch("checked_at")).in_time_zone
    @released = kind == "released"
    subject = @released ? "Schedule Now Available" : "Schedule Updated"
    mail(to: valid_recipient(payload.fetch("recipient")), subject: "#{subject}: #{payload.fetch('name').to_s.squish}",
      message_id: "notification-#{event_id}@#{ENV.fetch('APP_HOST', 'tourneyping.com')}")
  end

  # Compatibility for mail jobs already queued before the deployment.
  def schedule_now_available(monitored_url, snapshot)
    legacy_event(monitored_url, snapshot, "released")
  end

  def schedule_changed(monitored_url, snapshot, _old_snapshot = nil)
    legacy_event(monitored_url, snapshot, "changed")
  end

  private

  def legacy_event(monitored_url, snapshot, kind)
    @payload = {
      "name" => monitored_url.name, "url" => monitored_url.url,
      "recipient" => monitored_url.notification_email.presence || monitored_url.user.email,
      "summary" => snapshot.ai_summary, "evidence" => [], "checked_at" => snapshot.checked_at.iso8601
    }
    @checked_at = snapshot.checked_at.in_time_zone
    @released = kind == "released"
    mail(to: valid_recipient(@payload["recipient"]), subject: "#{@released ? 'Schedule Now Available' : 'Schedule Updated'}: #{monitored_url.name.to_s.squish}", template_name: "schedule_event")
  end

  def valid_recipient(value)
    raise ArgumentError, "Invalid notification email address" unless value.to_s.match?(URI::MailTo::EMAIL_REGEXP)
    value
  end
end
