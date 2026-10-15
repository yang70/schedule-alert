class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :confirmable

  has_many :monitored_urls, dependent: :destroy
  has_many :people, dependent: :destroy

  after_create_commit :notify_admin_of_signup

  def send_devise_notification(notification, *args)
    ActiveRecord.after_all_transactions_commit do
      devise_mailer.public_send(notification, self, *args).deliver_later
    end
  end

  private

  def notify_admin_of_signup
    return if ENV["ADMIN_EMAIL"].blank?

    AdminMailer.new_user_signup(self).deliver_later
  rescue StandardError => error
    Rails.logger.warn("Admin signup notice could not be queued account=#{id} error=#{error.class.name}")
  end
end
