class MonitoredUrl < ApplicationRecord
  belongs_to :user
  has_many :schedule_snapshots, dependent: :destroy

  SPORTS = %w[baseball volleyball].freeze

  validates :url, presence: true, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) }
  validates :name, presence: true
  validates :tournament_start_date, presence: true
  validates :sport, inclusion: { in: SPORTS, allow_blank: true }

  before_create :set_defaults
  after_save :schedule_next_check, if: :tournament_start_date_changed?

  scope :active, -> { where(active: true) }
  scope :upcoming_tournaments, -> { where('tournament_start_date >= ?', Date.current) }
  scope :due_for_check, -> { active.upcoming_tournaments.where('next_check_at IS NULL OR next_check_at <= ?', Time.current) }

  # Calculate days until tournament
  def days_until_tournament
    return nil unless tournament_start_date
    (tournament_start_date - Date.current).to_i
  end

  # Get the check times for today based on proximity to tournament (Pacific Time)
  # Returns array of hours (0-23) when checks should occur
  def todays_check_hours
    days = days_until_tournament
    return [] if days.nil? || days < 0 # Past tournaments don't get checked

    case days
    when 0..1 # Day of or day before: 5 checks (9am, 12pm, 3pm, 6pm, 10pm PT)
      [9, 12, 15, 18, 22]
    when 2..4 # 2-4 days away: 4 checks (9am, 12pm, 5pm, 10pm PT)
      [9, 12, 17, 22]
    when 5..7 # 5-7 days away: 3 checks (9am, 3pm, 10pm PT)
      [9, 15, 22]
    when 8..13 # 1-2 weeks away: 2 checks (10am, 10pm PT)
      [10, 22]
    else # 2+ weeks away: 1 check (10am PT)
      [10]
    end
  end

  # Calculate next check time based on tournament proximity
  def calculate_next_check_time
    return nil unless tournament_start_date
    return nil if days_until_tournament && days_until_tournament < 0 # Don't check past tournaments

    now = Time.current.in_time_zone('Pacific Time (US & Canada)')
    check_hours = todays_check_hours

    # Find next check hour today
    next_hour_today = check_hours.find { |hour| hour > now.hour }

    if next_hour_today
      # Next check is later today
      now.change(hour: next_hour_today, min: 0, sec: 0)
    else
      # Next check is tomorrow at first check hour
      tomorrow = now + 1.day
      tomorrow_check_hours = todays_check_hours # Recalculate for tomorrow
      return nil if tomorrow_check_hours.empty?
      tomorrow.beginning_of_day.change(hour: tomorrow_check_hours.first)
    end
  end

  # Schedule the next check
  def schedule_next_check
    update_column(:next_check_at, calculate_next_check_time)
  end

  private

  def set_defaults
    self.active = true if active.nil?
    self.schedule_available = false if schedule_available.nil?
    self.next_check_at = calculate_next_check_time if next_check_at.nil?
  end
end
