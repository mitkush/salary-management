module XlsxHelpers
  IMPORT_HEADERS = %w[employee_code full_name country department job_title bank_account_number joined_on
                      annual_base annual_allowances annual_deductions].freeze

  def xlsx_file(rows, headers: IMPORT_HEADERS)
    package = Axlsx::Package.new
    package.workbook.add_worksheet(name: "Employees") do |sheet|
      sheet.add_row(headers)
      rows.each { |row| sheet.add_row(row, types: Array.new(row.size, :string)) }
    end
    file = Tempfile.new([ "import", ".xlsx" ])
    file.binmode
    file.write(package.to_stream.read)
    file.rewind
    file
  end

  def import_row(**overrides)
    {
      employee_code: "EMP90001", full_name: "Priya Shah", country: "IN", department: "Finance", job_title: "Accountant",
      bank_account_number: "998877665544", joined_on: "2025-03-01", annual_base: "60000", annual_allowances: "6000",
      annual_deductions: "2400"
    }.merge(overrides).values_at(*IMPORT_HEADERS.map(&:to_sym))
  end
end

RSpec.configure do |config|
  config.include XlsxHelpers
end
