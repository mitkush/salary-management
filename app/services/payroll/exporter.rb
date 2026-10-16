module Payroll
  class Exporter
    HEADERS = [ "Employee code", "Name", "Bank account number", "Days worked", "Monthly gross", "Monthly deductions",
                "One-time bonus", "One-time deduction", "Adjustment note", "Tax", "Net" ].freeze
    TYPES = [ :string, :string, :string, :integer, :float, :float, :float, :float, :string, :float, :float ].freeze

    def initialize(run)
      @run = run
    end

    def to_xlsx
      package = Axlsx::Package.new
      money = package.workbook.styles.add_style(num_fmt: 4)
      styles = [ nil, nil, nil, nil, money, money, money, money, nil, money, money ]

      package.workbook.add_worksheet(name: @run.month.strftime("%Y-%m")) do |sheet|
        sheet.add_row(HEADERS)
        rows.each { |values| sheet.add_row(values, types: TYPES, style: styles) }
      end
      package.to_stream.read
    end

    private
      def rows
        @run.entries.joins(:employee).order("employees.employee_code").pluck(
          "employees.employee_code", "employees.full_name", "employees.bank_account_number", :days_worked, :monthly_gross,
          :monthly_deductions, :bonus, :one_time_deduction, :adjustment_note, :tax, :net
        )
      end
  end
end
