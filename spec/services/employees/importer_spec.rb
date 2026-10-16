require "rails_helper"

RSpec.describe Employees::Importer do
  around { |example| travel_to(Date.new(2026, 10, 16)) { example.run } }

  let!(:india) { create(:country, code: "IN", name: "India") }

  def import(rows, **options)
    described_class.new(xlsx_file(rows, **options).path).call
  end

  def row_result(result, row)
    result[:rows].find { |r| r[:row] == row }
  end

  it "creates an employee with an initial revision on the joining date" do
    result = import([ import_row ])

    expect(result).to include(created: 1, skipped: 0, failed: 0, rows: [])
    employee = Employee.find_by!(employee_code: "EMP90001")
    expect(employee).to have_attributes(full_name: "Priya Shah", country: india, department: "Finance",
      job_title: "Accountant", bank_account_number: "998877665544", joined_on: Date.new(2025, 3, 1))
    expect(employee.salary_revisions.map { |r| [ r.effective_on, r.reason, r.annual_gross ] })
      .to eq([ [ Date.new(2025, 3, 1), "initial", BigDecimal("66000") ] ])
  end

  it "trims text and matches the country by code or name, ignoring case" do
    result = import([
      import_row(employee_code: " EMP90001 ", country: "in", department: "  Finance "),
      import_row(employee_code: "EMP90002", country: "india")
    ])

    expect(result[:created]).to eq(2)
    expect(Employee.find_by!(employee_code: "EMP90001")).to have_attributes(country: india, department: "Finance")
  end

  it "skips an existing code with identical details, so re-uploading is safe" do
    import([ import_row ])

    result = import([ import_row ])

    expect(result).to include(created: 0, skipped: 1, failed: 0)
    expect(row_result(result, 2)).to eq(row: 2, employee_code: "EMP90001", status: "skipped", reasons: [ "already exists" ])
    expect(Employee.count).to eq(1)
  end

  it "fails an existing code whose details differ" do
    import([ import_row ])

    result = import([ import_row(full_name: "Someone Else") ])

    expect(row_result(result, 2)).to include(status: "failed", reasons: [ "employee code already exists with different details" ])
  end

  it "fails a code repeated in the same file, keeping the first" do
    result = import([ import_row, import_row(full_name: "Copy") ])

    expect(result).to include(created: 1, failed: 1)
    expect(row_result(result, 3)).to include(status: "failed", reasons: [ "duplicate employee code in this file" ])
    expect(Employee.find_by!(employee_code: "EMP90001").full_name).to eq("Priya Shah")
  end

  it "fails a row whose country isn't in the system" do
    result = import([ import_row(country: "Atlantis") ])

    expect(row_result(result, 2)).to include(status: "failed", reasons: [ "country 'Atlantis' not found" ])
  end

  it "reports every problem in a bad row with its row number" do
    result = import([ import_row(full_name: "", joined_on: "15/03/2025", annual_base: "abc", annual_deductions: "-5") ])

    expect(row_result(result, 2)[:reasons]).to contain_exactly(
      "full_name can't be blank", "joined_on must be a date (YYYY-MM-DD)", "annual_base must be a number",
      "annual_deductions must be greater than or equal to 0"
    )
  end

  it "applies the salary revision rules, like the amount cap" do
    result = import([ import_row(annual_base: "1000000000.01") ])

    expect(row_result(result, 2)[:reasons]).to eq([ "annual_base must be less than or equal to 1000000000" ])
  end

  it "accepts real Excel date cells as well as YYYY-MM-DD text" do
    package = Axlsx::Package.new
    package.workbook.add_worksheet do |sheet|
      sheet.add_row(XlsxHelpers::IMPORT_HEADERS)
      sheet.add_row(import_row.tap { |row| row[6] = Date.new(2025, 3, 1) })
    end
    file = Tempfile.new([ "dates", ".xlsx" ]).tap { |f| f.binmode; f.write(package.to_stream.read); f.rewind }

    described_class.new(file.path).call

    expect(Employee.find_by!(employee_code: "EMP90001").joined_on).to eq(Date.new(2025, 3, 1))
  end

  it "creates the valid rows and reports the invalid ones in a mixed file" do
    result = import([
      import_row(employee_code: "EMP90001"),
      import_row(employee_code: "EMP90002", country: "Atlantis"),
      import_row(employee_code: "EMP90003", joined_on: "2026-11-01"),
      import_row(employee_code: "", full_name: "No Code")
    ])

    expect(result).to include(created: 2, skipped: 0, failed: 2)
    expect(result[:rows].map { |r| r[:row] }).to eq([ 3, 5 ])
    expect(Employee.pluck(:employee_code)).to contain_exactly("EMP90001", "EMP90003")
    expect(Employee.find_by!(employee_code: "EMP90003").status).to eq("upcoming")
  end

  it "leaves no employee behind when saving their revisions fails" do
    allow(SalaryRevision).to receive(:insert_all!).and_raise(ActiveRecord::StatementInvalid, "boom")

    expect { import([ import_row ]) }.to raise_error(ActiveRecord::StatementInvalid)
    expect(Employee.where(employee_code: "EMP90001")).not_to exist
  end

  describe ".template" do
    it "formats the employee_code and bank_account_number columns as text, so Excel keeps long numbers exact" do
      files = {}
      Zip::InputStream.open(StringIO.new(described_class.template)) do |zip|
        while (entry = zip.get_next_entry)
          files[entry.name] = zip.read
        end
      end
      sheet = Nokogiri::XML(files.fetch("xl/worksheets/sheet1.xml")).remove_namespaces!
      text_styles = Nokogiri::XML(files.fetch("xl/styles.xml")).remove_namespaces!
        .xpath("//cellXfs/xf").each_with_index.filter_map { |xf, index| index.to_s if xf["numFmtId"] == "49" }

      text_columns = sheet.xpath("//cols/col").select { |col| text_styles.include?(col["style"]) }.flat_map { |col| (col["min"].to_i..col["max"].to_i).to_a }
      expect(text_columns).to include(1, 6)
    end
  end

  describe "problems with the whole file" do
    it "rejects a file with missing columns" do
      expect { import([ [ "EMP1" ] ], headers: %w[employee_code]) }
        .to raise_error(described_class::InvalidFile, /missing columns: full_name, country/)
    end

    it "rejects a file with no data rows" do
      expect { import([]) }.to raise_error(described_class::InvalidFile, "The file has no employee rows.")
    end

    it "rejects a file that isn't a readable spreadsheet" do
      file = Tempfile.new([ "broken", ".xlsx" ]).tap { |f| f.write("PK\x03\x04 not really a zip"); f.rewind }

      expect { described_class.new(file.path).call }.to raise_error(described_class::InvalidFile, "The file couldn't be read as .xlsx.")
    end
  end
end
