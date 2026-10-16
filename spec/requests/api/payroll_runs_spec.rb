require "rails_helper"

RSpec.describe "API payroll runs", type: :request do
  around { |example| travel_to(Time.zone.local(2026, 10, 16, 12)) { example.run } }

  let(:india) { create(:country, code: "IN", name: "India", tax_rate: "0.2000") }
  let!(:person) do
    create(:employee, employee_code: "EMP00001", full_name: "Priya Shah", country: india, joined_on: Date.new(2025, 1, 1),
      bank_account_number: "998877665544").tap do |e|
      create(:salary_revision, employee: e, annual_base: "120000.00", annual_allowances: "0.00", annual_deductions: "12000.00")
    end
  end

  def json
    response.parsed_body
  end

  it "requires login on every endpoint" do
    run = Payroll::Generator.call(Date.new(2026, 10, 1))
    entry = run.entries.first

    [
      -> { get "/api/payroll_runs", as: :json },
      -> { put "/api/payroll_runs/2026-10", as: :json },
      -> { get "/api/payroll_runs/2026-10/entries", as: :json },
      -> { patch "/api/payroll_runs/2026-10/entries/#{entry.id}", params: { entry: { bonus: "1" } }, as: :json },
      -> { get "/api/payroll_runs/2026-10/export" }
    ].each do |request|
      request.call
      expect(response).to have_http_status(:unauthorized)
    end
  end

  context "when logged in" do
    before { sign_in(create(:user)) }

    it "generates a month and lists runs with locked and outdated flags" do
      put "/api/payroll_runs/2026-09", as: :json
      expect(response).to have_http_status(:ok)
      expect(json).to include("month" => "2026-09", "entries_count" => 1, "locked" => false, "outdated" => false)

      put "/api/payroll_runs/2026-10", as: :json
      travel 1.minute
      india.update!(tax_rate_percent: "25")

      get "/api/payroll_runs", as: :json
      expect(json.map { |r| r.slice("month", "locked", "outdated") }).to eq([
        { "month" => "2026-10", "locked" => false, "outdated" => true },
        { "month" => "2026-09", "locked" => true, "outdated" => false }
      ])
    end

    it "returns each run's totals of gross, tax and net, summed by the server" do
      create(:employee, employee_code: "EMP00002", country: india, joined_on: Date.new(2025, 1, 1)).tap do |e|
        create(:salary_revision, employee: e, annual_base: "60000.00", annual_allowances: "0.00", annual_deductions: "0.00")
      end

      put "/api/payroll_runs/2026-10", as: :json
      expect(json["totals"]).to eq("gross" => "15000.0", "tax" => "3000.0", "net" => "11000.0")

      get "/api/payroll_runs", as: :json
      expect(json.first["totals"]).to eq("gross" => "15000.0", "tax" => "3000.0", "net" => "11000.0")
    end

    it "returns 409 for a future, skipped or locked month" do
      put "/api/payroll_runs/2026-11", as: :json
      expect(response).to have_http_status(:conflict)
      expect(json).to eq("error" => { "code" => "conflict", "message" => "Payroll can't be generated for a future month." })

      create(:payroll_run, month: Date.new(2026, 8, 1))
      put "/api/payroll_runs/2026-10", as: :json
      expect(response).to have_http_status(:conflict)
      expect(json.dig("error", "message")).to eq("The next payroll must be for September 2026.")
    end

    it "returns 400 for a badly formatted month and 404 for a month without a run" do
      put "/api/payroll_runs/2026-13", as: :json
      expect(response).to have_http_status(:bad_request)

      get "/api/payroll_runs/2026-05/entries", as: :json
      expect(response).to have_http_status(:not_found)
    end

    it "lists entries with the employee and the bank account masked" do
      put "/api/payroll_runs/2026-10", as: :json

      get "/api/payroll_runs/2026-10/entries", as: :json

      expect(json["meta"]).to eq("page" => 1, "per_page" => 25, "total" => 1)
      expect(json["data"].first).to include(
        "employee_code" => "EMP00001", "full_name" => "Priya Shah", "bank_account" => "•••• 5544", "days_worked" => 31,
        "monthly_gross" => "10000.0", "monthly_deductions" => "1000.0", "bonus" => "0.0", "one_time_deduction" => "0.0",
        "adjustment_note" => nil, "tax_rate_percent" => "20.0", "tax" => "2000.0", "net" => "7000.0"
      )
      expect(response.body).not_to include("998877665544")
    end

    it "adjusts an entry in the open month and rejects invalid values or a locked month" do
      put "/api/payroll_runs/2026-09", as: :json
      september_entry = PayrollRun.find_by!(month: Date.new(2026, 9, 1)).entries.first
      put "/api/payroll_runs/2026-10", as: :json
      entry = PayrollRun.find_by!(month: Date.new(2026, 10, 1)).entries.first

      patch "/api/payroll_runs/2026-10/entries/#{entry.id}",
        params: { entry: { bonus: "500", one_time_deduction: "9000", adjustment_note: "Loan" } }, as: :json
      expect(response).to have_http_status(:ok)
      expect(json).to include("bonus" => "500.0", "tax" => "2100.0", "net" => "-1600.0", "adjustment_note" => "Loan")

      patch "/api/payroll_runs/2026-10/entries/#{entry.id}", params: { entry: { bonus: "-1" } }, as: :json
      expect(response).to have_http_status(:unprocessable_content)
      expect(json.dig("error", "details", "bonus")).to eq([ "must be greater than or equal to 0" ])

      patch "/api/payroll_runs/2026-09/entries/#{september_entry.id}", params: { entry: { bonus: "1" } }, as: :json
      expect(response).to have_http_status(:conflict)
      expect(json.dig("error", "message")).to eq("September 2026 is locked.")
    end

    it "exports the month as .xlsx with the full bank account number" do
      put "/api/payroll_runs/2026-10", as: :json

      get "/api/payroll_runs/2026-10/export"

      expect(response).to have_http_status(:ok)
      expect(response.headers["Content-Disposition"]).to include('filename="payroll-2026-10.xlsx"')
      file = Tempfile.new([ "payroll", ".xlsx" ]).tap { |f| f.binmode; f.write(response.body); f.rewind }
      sheet = Roo::Excelx.new(file.path).sheet(0)
      expect(sheet.row(1)).to eq([ "Employee code", "Name", "Bank account number", "Days worked", "Monthly gross",
        "Monthly deductions", "One-time bonus", "One-time deduction", "Adjustment note", "Tax", "Net" ])
      expect(sheet.row(2)).to eq([ "EMP00001", "Priya Shah", "998877665544", 31, 10000, 1000, 0, 0, nil, 2000, 7000 ])
    end

    it "sorts the export by employee code" do
      %w[EMP00003 EMP00002].each do |code|
        create(:employee, employee_code: code, country: india, joined_on: Date.new(2025, 1, 1)).tap { |e| create(:salary_revision, employee: e) }
      end
      put "/api/payroll_runs/2026-10", as: :json

      get "/api/payroll_runs/2026-10/export"

      file = Tempfile.new([ "payroll", ".xlsx" ]).tap { |f| f.binmode; f.write(response.body); f.rewind }
      expect(Roo::Excelx.new(file.path).sheet(0).column(1).drop(1)).to eq(%w[EMP00001 EMP00002 EMP00003])
    end

    it "returns 404 when exporting a month without a run" do
      get "/api/payroll_runs/2026-05/export"

      expect(response).to have_http_status(:not_found)
    end
  end
end
