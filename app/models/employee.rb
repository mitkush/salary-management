class Employee < ApplicationRecord
  STATUSES = %w[active upcoming terminated].freeze

  belongs_to :country
  has_many :salary_revisions, dependent: :restrict_with_exception

  validates :employee_code, presence: true, uniqueness: true
  validates :full_name, :department, :job_title, :bank_account_number, :joined_on, presence: true

  scope :with_status, ->(status) {
    today = Date.current
    case status
    when "active" then where(joined_on: ..today).where("terminated_on IS NULL OR terminated_on >= ?", today)
    when "upcoming" then where(joined_on: today.next_day..)
    when "terminated" then where(terminated_on: ...today)
    else all
    end
  }

  scope :search, ->(query) {
    next all if query.blank?

    pattern = "%#{sanitize_sql_like(query.strip)}%"
    where("full_name ILIKE :pattern OR employee_code ILIKE :pattern", pattern: pattern)
  }

  def status
    today = Date.current
    if joined_on > today then "upcoming"
    elsif terminated_on && terminated_on < today then "terminated"
    else "active"
    end
  end

  def current_revision
    salary_revisions.where(effective_on: ..[ Date.current, terminated_on ].compact.min).order(effective_on: :desc).first
  end

  def masked_bank_account
    "•••• #{bank_account_number.last(4)}"
  end

  def terminate!(date)
    if terminated_on
      errors.add(:terminated_on, "is already set, the employee is already terminated")
    elsif date.blank?
      errors.add(:terminated_on, "can't be blank")
    elsif date < joined_on
      errors.add(:terminated_on, "can't be before the joining date")
    end
    raise ActiveRecord::RecordInvalid, self if errors.any?

    update!(terminated_on: date)
  end
end
