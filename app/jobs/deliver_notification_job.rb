class DeliverNotificationJob < ApplicationJob
  queue_as :mailers

  def perform(event_id)
    event = NotificationEvent.find_by(id: event_id)
    return unless event
    event.with_lock do
      next if event.delivered_at || event.delivery_attempts >= 8 || event.next_delivery_at > Time.current
      unless event.payload["recipient"].to_s.match?(URI::MailTo::EMAIL_REGEXP)
        event.update!(delivery_attempts: 8, last_error: "Notification email address is invalid")
        next
      end
      begin
        NotificationMailer.schedule_event(event.payload, event.kind, event.id).deliver_now
        event.update!(delivered_at: Time.current, delivery_attempts: event.delivery_attempts + 1, last_error: nil)
      rescue StandardError => error
        attempts = error.is_a?(Net::SMTPFatalError) ? 8 : event.delivery_attempts + 1
        event.update!(delivery_attempts: attempts, next_delivery_at: [ 2**attempts, 360 ].min.minutes.from_now, last_error: "Email delivery failed (#{error.class.name})")
        Rails.logger.error("Notification delivery failed event=#{event.id} error=#{error.class.name}")
      end
    end
  end
end
