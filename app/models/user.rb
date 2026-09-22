class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :monitored_urls, dependent: :destroy
  has_many :people, dependent: :destroy

  after_create :notify_admin_of_signup

  # Fails closed if ADMIN_EMAIL isn't configured, so no one gets admin access by accident.
  def admin?
    ENV["ADMIN_EMAIL"].present? && email == ENV["ADMIN_EMAIL"].downcase.strip
  end

  private

  def notify_admin_of_signup
    return if ENV["ADMIN_EMAIL"].blank?

    AdminMailer.new_user_signup(self).deliver_later
  end
end
