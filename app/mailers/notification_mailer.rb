class NotificationMailer < ApplicationMailer
  def schedule_now_available(monitored_url, snapshot)
    @monitored_url = monitored_url
    @snapshot = snapshot
    @user = monitored_url.user

    recipient = monitored_url.notification_email.presence || @user.email

    mail(
      to: recipient,
      subject: "Schedule Now Available: #{@monitored_url.name}"
    )
  end

  def schedule_changed(monitored_url, new_snapshot, old_snapshot)
    @monitored_url = monitored_url
    @new_snapshot = new_snapshot
    @old_snapshot = old_snapshot
    @user = monitored_url.user

    recipient = monitored_url.notification_email.presence || @user.email

    mail(
      to: recipient,
      subject: "Schedule Updated: #{@monitored_url.name}"
    )
  end
end
