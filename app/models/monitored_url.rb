class MonitoredUrl < ApplicationRecord
  belongs_to :user, counter_cache: true
  belongs_to :person, optional: true
  has_many :schedule_snapshots, dependent: :destroy
  has_many :notification_events, dependent: :destroy

  SPORTS = %w[baseball softball volleyball].freeze
  CHECK_LEASE = 15.minutes
  QUEUE_LEASE = 6.hours
  MANUAL_COOLDOWN = 5.minutes
  PUBLIC_ATTRIBUTES = %i[id url name notification_email active tournament_start_date sport person_id last_checked_at next_check_at schedule_available check_status last_attempt_at last_error].freeze

  validates :url, :name, :tournament_start_date, presence: true
  validates :name, length: { maximum: 100 }
  validates :url, length: { maximum: 2048 }
  validates :notification_email, length: { maximum: 254 }, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :sport, inclusion: { in: SPORTS, allow_blank: true }
  validate :public_http_url
  validate :person_belongs_to_user
  validate :within_account_limit, on: :create

  before_validation :normalize_fields
  before_save :reset_source, if: -> { persisted? && (will_save_change_to_url? || will_save_change_to_tournament_start_date?) }
  before_save :cancel_check, if: -> { persisted? && will_save_change_to_active? }
  before_save :refresh_schedule, if: -> { new_record? || will_save_change_to_tournament_start_date? || will_save_change_to_url? || will_save_change_to_active? || will_save_change_to_schedule_available? }

  scope :active, -> { where(active: true) }
  scope :upcoming_tournaments, -> { where("tournament_start_date >= ?", Date.current) }
  scope :due_for_check, -> {
    active.upcoming_tournaments
      .where("next_check_at <= ?", Time.current)
      .where("check_token IS NULL OR (check_status = 'running' AND check_started_at < ?) OR (check_status = 'queued' AND check_enqueued_at < ?)", CHECK_LEASE.ago, QUEUE_LEASE.ago)
  }

  def eligible_for_check?
    active? && tournament_start_date.present? && tournament_start_date >= Date.current
  end

  def days_until_tournament
    (tournament_start_date - Date.current).to_i if tournament_start_date
  end

  def todays_check_hours(date = Date.current)
    return [] unless tournament_start_date && active?
    days = (tournament_start_date - date).to_i
    return [] if days.negative?
    return [ [ 10, 0 ] ] if released?
    return [ [ 10, 0 ], [ 10, 45 ], [ 11, 30 ], [ 12, 15 ], [ 13, 0 ], [ 17, 0 ] ] if date.tuesday?

    case days
    when 0..1 then [ [ 9, 0 ], [ 12, 0 ], [ 15, 0 ], [ 18, 0 ], [ 22, 0 ] ]
    when 2..4 then [ [ 9, 0 ], [ 12, 0 ], [ 17, 0 ], [ 22, 0 ] ]
    when 5..7 then [ [ 9, 0 ], [ 15, 0 ], [ 22, 0 ] ]
    when 8..13 then [ [ 10, 0 ], [ 22, 0 ] ]
    else [ [ 10, 0 ] ]
    end
  end

  def calculate_next_check_time(now = Time.current)
    return unless eligible_for_check?
    now = now.in_time_zone(Time.zone)
    [ now.to_date, now.to_date + 1 ].each do |date|
      todays_check_hours(date).each do |hour, minute|
        candidate = Time.zone.local(date.year, date.month, date.day, hour, minute)
        return candidate if candidate > now
      end
    end
    nil
  end

  def check_frequency
    return "Not scheduled" unless eligible_for_check?
    return "Once daily after release (10am PT)" if released?
    times = todays_check_hours.map { |hour, minute| Time.zone.local(2000, 1, 1, hour, minute).strftime("%-l:%M%P") }
    "#{times.length}x today (#{times.join(', ')} PT)"
  end

  def public_json
    as_json(only: PUBLIC_ATTRIBUTES, include: { person: { only: %i[id name color] } }).merge(
      "days_until_tournament" => days_until_tournament,
      "check_frequency" => check_frequency
    )
  end

  def released?
    schedule_available? || release_notified_revision == source_revision
  end

  # A committed lease protects against concurrent manual checks and dispatchers.
  # Enqueue outside the transaction so a fast worker can see its token.
  def request_check!(manual: false)
    token = nil
    revision = nil
    result = with_lock do
      if !eligible_for_check?
        :inactive
      elsif check_token.present? && (check_status == "running" ? check_started_at && check_started_at > CHECK_LEASE.ago : check_enqueued_at && check_enqueued_at > QUEUE_LEASE.ago)
        :busy
      elsif manual && last_attempt_at && last_attempt_at > MANUAL_COOLDOWN.ago
        :cooldown
      else
        token = SecureRandom.uuid
        revision = source_revision
        update!(check_token: token, check_enqueued_at: Time.current, check_started_at: nil, check_status: "queued", last_error: nil)
        :queued
      end
    end
    UrlCheckJob.perform_later(id, revision, token) if result == :queued
    result
  rescue StandardError
    if token
      with_lock do
        update!(check_token: nil, check_status: "error", last_error: "Unable to queue the check. Retrying shortly.", next_check_at: 1.minute.from_now) if check_token == token
      end
    end
    raise
  end

  private

  def normalize_fields
    self.url = url&.strip
    self.name = name&.squish
    self.notification_email = notification_email&.strip
    self.active = true if active.nil?
    self.schedule_available = false if schedule_available.nil?
  end

  def public_http_url
    PublicUrl.parse!(url) if url.present?
  rescue PublicUrl::UnsafeUrl
    errors.add(:url, "must be a public HTTP or HTTPS URL on port 80 or 443")
  end

  def person_belongs_to_user
    errors.add(:person, "must belong to your account") if person_id.present? && (person.nil? || person.user_id != user_id)
  end

  def within_account_limit
    if user && user.monitored_urls.count >= ENV.fetch("MAX_URLS_PER_USER", "50").to_i
      errors.add(:base, "Your account has reached its monitored URL limit")
    end
  end

  def reset_source
    self.source_revision += 1
    self.schedule_available = false
    self.schedule_data = nil
    self.release_notified_revision = 0
    self.last_checked_at = nil
    self.failure_count = 0
    self.last_error = nil
    self.check_status = "idle"
    self.check_token = nil
    self.check_enqueued_at = nil
    self.check_started_at = nil
    self.last_attempt_at = nil
  end

  def refresh_schedule
    self.next_check_at = calculate_next_check_time
  end

  def cancel_check
    self.check_token = nil
    self.check_enqueued_at = nil
    self.check_started_at = nil
    self.check_status = "idle"
  end
end
