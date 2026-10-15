require "test_helper"

class DeliverNotificationJobTest < ActiveSupport::TestCase
  test "malformed historical recipients are rejected before mail delivery" do
    monitored = create_url
    event = monitored.notification_events.create!(event_key: "1:released", kind: "released", next_delivery_at: Time.current,
      payload: { recipient: "a@example.com\nBcc: other@example.com", name: "Tournament", url: monitored.url, summary: "Released", checked_at: Time.current.iso8601 })
    assert_no_difference "ActionMailer::Base.deliveries.size" do
      DeliverNotificationJob.perform_now(event.id)
    end
    assert_equal 8, event.reload.delivery_attempts
    assert_nil event.delivered_at
  end

  test "a delivery outage keeps the event pending without losing its payload" do
    monitored = create_url
    event = monitored.notification_events.create!(event_key: "1:released", kind: "released", next_delivery_at: Time.current,
      payload: { recipient: "alternate@example.com", name: "Tournament", url: monitored.url, summary: "Released", checked_at: Time.current.iso8601 })
    delivery = Object.new
    def delivery.deliver_now; raise IOError, "SMTP unavailable"; end
    NotificationMailer.stub(:schedule_event, delivery) { DeliverNotificationJob.perform_now(event.id) }
    assert_nil event.reload.delivered_at
    assert_equal 1, event.delivery_attempts
    assert event.next_delivery_at > Time.current
    assert_equal "alternate@example.com", event.payload["recipient"]
  end
end
