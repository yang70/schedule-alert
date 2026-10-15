class Person < ApplicationRecord
  belongs_to :user, counter_cache: true
  has_many :monitored_urls, dependent: :nullify

  validates :name, presence: true
  validates :name, length: { maximum: 100 }
  validates :color, presence: true, format: { with: /\A#[0-9A-Fa-f]{6}\z/, message: "must be a valid hex color" }
  validates :name, uniqueness: { scope: :user_id, case_sensitive: false }

  before_validation :normalize_color

  private

  def normalize_color
    self.color = color.upcase if color.present?
    self.name = name&.strip
  end
end
