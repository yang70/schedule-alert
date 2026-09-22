class Users::RegistrationsController < Devise::RegistrationsController
  before_action :block_bot_signups, only: :create

  private

  def block_bot_signups
    return unless bot_signup?

    notify_admin_of_bot_attempt
    build_resource(sign_up_params)
    resource.errors.add(:base, "There was a problem creating your account. Please try again.")
    clean_up_passwords(resource)
    set_minimum_password_length
    render :new, status: :unprocessable_entity
  end

  def bot_signup?
    honeypot_filled? || submitted_too_quickly?
  end

  def honeypot_filled?
    params.dig(:user, :website).present?
  end

  def submitted_too_quickly?
    rendered_at = params[:form_rendered_at].presence&.to_i
    return true if rendered_at.blank?

    (Time.current.to_i - rendered_at) < 2
  end

  def bot_reason
    return "honeypot field filled in" if honeypot_filled?

    "submitted too quickly after page load"
  end

  def notify_admin_of_bot_attempt
    return if ENV["ADMIN_EMAIL"].blank?

    AdminMailer.bot_signup_attempt(
      email: params.dig(:user, :email),
      reason: bot_reason,
      ip: request.remote_ip,
      user_agent: request.user_agent
    ).deliver_later
  end
end
