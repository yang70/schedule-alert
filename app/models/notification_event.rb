class NotificationEvent < ApplicationRecord
  belongs_to :monitored_url
  validates :kind, inclusion: { in: %w[released changed] }
  validates :event_key, :payload, presence: true
  scope :pending, -> { where(delivered_at: nil).where("next_delivery_at <= ? AND delivery_attempts < 8", Time.current) }

  after_create_commit :enqueue_delivery

  private

  def enqueue_delivery
    DeliverNotificationJob.perform_later(id)
  rescue StandardError => error
    # The minute dispatcher recovers a committed event if Redis is unavailable.
    Rails.logger.error("Notification enqueue failed event=#{id} error=#{error.class.name}")
  end
end
