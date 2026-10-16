module Payroll
  module EntryCalculator
    module_function

    def prorate(month:, joined_on:, terminated_on:, annual_gross:, annual_deductions:)
      month_end = month.end_of_month
      first_day = [ joined_on, month ].max
      last_day = [ terminated_on, month_end ].compact.min
      days_worked = (last_day - first_day).to_i + 1
      days_in_month = month_end.day

      {
        days_worked: days_worked,
        monthly_gross: cents(annual_gross * days_worked / (12 * days_in_month)),
        monthly_deductions: cents(annual_deductions * days_worked / (12 * days_in_month))
      }
    end

    def settle(monthly_gross:, monthly_deductions:, tax_rate:, bonus:, one_time_deduction:)
      taxable = monthly_gross + bonus
      tax = cents(taxable * tax_rate)

      { tax: tax, net: taxable - tax - monthly_deductions - one_time_deduction }
    end

    def cents(amount)
      amount.round(2, :half_up)
    end
  end
end
