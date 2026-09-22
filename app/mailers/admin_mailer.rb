class AdminMailer < ApplicationMailer
  def new_user_signup(user)
    @user = user

    mail(
      to: ENV["ADMIN_EMAIL"],
      subject: "New User Signup: #{@user.email}"
    )
  end

  def bot_signup_attempt(email:, reason:, ip:, user_agent:)
    @email = email
    @reason = reason
    @ip = ip
    @user_agent = user_agent
    @attempted_at = Time.current

    mail(
      to: ENV["ADMIN_EMAIL"],
      subject: "Blocked bot sign-up attempt"
    )
  end
end
