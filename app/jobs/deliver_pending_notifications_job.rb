class DeliverPendingNotificationsJob < ApplicationJob
  queue_as :default

  def perform
    NotificationEvent.pending.find_each { |event| DeliverNotificationJob.perform_later(event.id) }
  end
end
