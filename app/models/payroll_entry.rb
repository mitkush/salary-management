class PayrollEntry < ApplicationRecord
  MAX_AMOUNT = SalaryRevision::MAX_AMOUNT

  belongs_to :payroll_run
  belongs_to :employee
  belongs_to :salary_revision

  validates :bonus, :one_time_deduction, presence: true,
    numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: MAX_AMOUNT }
end
