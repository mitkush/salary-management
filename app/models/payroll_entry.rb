class PayrollEntry < ApplicationRecord
  class Locked < StandardError; end

  MAX_AMOUNT = SalaryRevision::MAX_AMOUNT

  belongs_to :payroll_run
  belongs_to :employee
  belongs_to :salary_revision

  validates :bonus, :one_time_deduction, presence: true,
    numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: MAX_AMOUNT }

  def adjust!(bonus: self.bonus, one_time_deduction: self.one_time_deduction, adjustment_note: self.adjustment_note)
    raise Locked, "#{payroll_run.month.strftime('%B %Y')} is locked." if payroll_run.locked?

    assign_attributes(bonus: bonus, one_time_deduction: one_time_deduction, adjustment_note: adjustment_note.presence)
    validate!
    assign_attributes(Payroll::EntryCalculator.settle(monthly_gross: monthly_gross, monthly_deductions: monthly_deductions,
      tax_rate: tax_rate, bonus: self.bonus, one_time_deduction: self.one_time_deduction))
    save!
  end
end
