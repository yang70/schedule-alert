class AdminMailer < ApplicationMailer
  def new_user_signup(user)
    @user = user

    mail(
      to: ENV['ADMIN_EMAIL'],
      subject: "New User Signup: #{@user.email}"
    )
  end
end
