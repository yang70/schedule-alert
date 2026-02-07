class MonitoredUrl < ApplicationRecord
  belongs_to :user
  has_many :schedule_snapshots, dependent: :destroy

  validates :url, presence: true, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) }
  validates :name, presence: true

  before_create :set_defaults

  scope :active, -> { where(active: true) }

  private

  def set_defaults
    self.active = true if active.nil?
    self.schedule_available = false if schedule_available.nil?
  end
end
