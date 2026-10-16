module Api
  class PayrollEntriesController < BaseController
    include PayrollMonth

    def index
      run = find_run(params[:payroll_run_month])
      entries, meta = paginate(run.entries.joins(:employee).includes(:employee).order("employees.employee_code"))

      render json: { data: entries.map { |entry| entry_json(entry) }, meta: meta }
    end

    def update
      entry = find_run(params[:payroll_run_month]).entries.includes(:employee).find(params[:id])
      entry.adjust!(**params.expect(entry: %i[bonus one_time_deduction adjustment_note]).to_h.symbolize_keys)

      render json: entry_json(entry)
    end

    private
      def entry_json(entry)
        {
          id: entry.id,
          employee_id: entry.employee_id,
          employee_code: entry.employee.employee_code,
          full_name: entry.employee.full_name,
          bank_account: entry.employee.masked_bank_account,
          days_worked: entry.days_worked,
          monthly_gross: entry.monthly_gross,
          monthly_deductions: entry.monthly_deductions,
          bonus: entry.bonus,
          one_time_deduction: entry.one_time_deduction,
          adjustment_note: entry.adjustment_note,
          tax_rate_percent: entry.tax_rate * 100,
          tax: entry.tax,
          net: entry.net
        }
      end
  end
end
