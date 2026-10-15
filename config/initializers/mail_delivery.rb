unless Rails.env.test?
  smtp_address = ENV["SMTP_ADDRESS"].presence
  resend = smtp_address.nil? && ENV["RESEND_API_KEY"].present?
  if Rails.env.production? && !ENV["SECRET_KEY_BASE_DUMMY"]
    raise "Configure SMTP_ADDRESS or RESEND_API_KEY for notification delivery" unless smtp_address || resend
    raise "Configure FROM_EMAIL and APP_HOST for notification delivery" if ENV["FROM_EMAIL"].blank? || ENV["APP_HOST"].blank?
  end
  Rails.application.config.action_mailer.delivery_method = :smtp
  Rails.application.config.action_mailer.raise_delivery_errors = true
  Rails.application.config.action_mailer.smtp_settings = {
    address: resend ? "smtp.resend.com" : (smtp_address || "localhost"),
    port: Integer(ENV.fetch("SMTP_PORT", "587")),
    domain: ENV.fetch("SMTP_DOMAIN", ENV.fetch("APP_HOST", "localhost")),
    user_name: resend ? "resend" : ENV["SMTP_USERNAME"],
    password: resend ? ENV["RESEND_API_KEY"] : ENV["SMTP_PASSWORD"],
    authentication: :plain, enable_starttls: Rails.env.production?, enable_starttls_auto: !Rails.env.production?, open_timeout: 10, read_timeout: 10
  }
end
