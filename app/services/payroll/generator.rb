module Payroll
  class Generator
    class NotAllowed < StandardError; end

    BATCH_SIZE = 1_000
    CALCULATED_COLUMNS = %i[salary_revision_id days_worked monthly_gross monthly_deductions tax_rate tax net].freeze

    def self.call(month)
      new(month).call
    end

    def initialize(month)
      @month = month.beginning_of_month
      @month_end = @month.end_of_month
    end

    def call
      check_month!

      PayrollRun.transaction do
        run = PayrollRun.find_or_initialize_by(month: @month)
        run.update!(generated_at: Time.current)
        eligible_employees.in_batches(of: BATCH_SIZE) { |batch| upsert_entries(run, batch.includes(:country).to_a) }
        run
      end
    end

    private
      def check_month!
        raise NotAllowed, "Payroll can't be generated for a future month." if @month > Date.current.beginning_of_month

        latest = PayrollRun.latest_month
        return if latest.nil? || @month == latest

        raise NotAllowed, "#{label(@month)} is locked." if @month < latest
        raise NotAllowed, "The next payroll must be for #{label(latest.next_month)}." unless @month == latest.next_month
      end

      def eligible_employees
        Employee.where(joined_on: ..@month_end).where("terminated_on IS NULL OR terminated_on >= ?", @month)
      end

      def upsert_entries(run, employees)
        revisions = SalaryRevision.current_for(employees.map(&:id), on: @month_end).index_by(&:employee_id)
        adjustments = run.entries.where(employee_id: employees.map(&:id))
          .pluck(:employee_id, :bonus, :one_time_deduction).to_h { |id, bonus, deduction| [ id, [ bonus, deduction ] ] }

        rows = employees.map do |employee|
          revision = revisions.fetch(employee.id)
          bonus, deduction = adjustments.fetch(employee.id, [ 0, 0 ])
          amounts = EntryCalculator.prorate(month: @month, joined_on: employee.joined_on, terminated_on: employee.terminated_on,
            annual_gross: revision.annual_gross, annual_deductions: revision.annual_deductions)
          tax_rate = employee.country.tax_rate
          settled = EntryCalculator.settle(monthly_gross: amounts[:monthly_gross], monthly_deductions: amounts[:monthly_deductions],
            tax_rate: tax_rate, bonus: BigDecimal(bonus.to_s), one_time_deduction: BigDecimal(deduction.to_s))

          { payroll_run_id: run.id, employee_id: employee.id, salary_revision_id: revision.id, tax_rate: tax_rate, **amounts, **settled }
        end

        PayrollEntry.upsert_all(rows, unique_by: %i[payroll_run_id employee_id], update_only: CALCULATED_COLUMNS) if rows.any?
      end

      def label(month)
        month.strftime("%B %Y")
      end
  end
end
