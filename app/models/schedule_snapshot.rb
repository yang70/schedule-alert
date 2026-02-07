class ScheduleSnapshot < ApplicationRecord
  belongs_to :monitored_url

  validates :content_hash, presence: true
  validates :checked_at, presence: true

  scope :ordered, -> { order(checked_at: :desc) }
  scope :with_changes, -> { where(changes_detected: true) }
end
