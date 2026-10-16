class SalaryRevision < ApplicationRecord
  REASONS = %w[initial increment promotion correction other].freeze
  MAX_AMOUNT = 1_000_000_000

  belongs_to :employee

  validates :effective_on, presence: true
  validates :effective_on, uniqueness: { scope: :employee_id, message: "already has a revision for this employee" }
  validates :reason, inclusion: { in: REASONS }
  validates :annual_base, :annual_allowances, :annual_deductions, presence: true,
    numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: MAX_AMOUNT }
  validate :effective_on_within_employment

  scope :current_for, ->(employee_ids, on: Date.current) {
    joins(:employee)
      .where(employee_id: employee_ids)
      .where("salary_revisions.effective_on <= LEAST(:on, COALESCE(employees.terminated_on, :on))", on: on)
      .select("DISTINCT ON (salary_revisions.employee_id) salary_revisions.*")
      .order("salary_revisions.employee_id", effective_on: :desc)
  }

  def readonly?
    persisted?
  end

  def never_applies?
    employee.terminated_on.present? && effective_on > employee.terminated_on
  end

  private
    def effective_on_within_employment
      return if effective_on.blank? || employee.blank?

      if effective_on < employee.joined_on
        errors.add(:effective_on, "can't be before the joining date")
      elsif employee.terminated_on && effective_on > employee.terminated_on
        errors.add(:effective_on, "can't be after the last working day")
      end
    end
end
