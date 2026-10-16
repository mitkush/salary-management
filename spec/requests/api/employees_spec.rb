require "rails_helper"

RSpec.describe "API employees", type: :request do
  around { |example| travel_to(Date.new(2026, 10, 16)) { example.run } }

  let(:user) { create(:user) }
  let(:india) { create(:country, code: "IN", name: "India") }
  let(:us) { create(:country, code: "US", name: "United States") }

  def json
    response.parsed_body
  end

  def employee_with_salary(gross_base: "60000.00", **attributes)
    create(:employee, **attributes).tap do |employee|
      create(:salary_revision, employee: employee, annual_base: gross_base, annual_allowances: "0.00")
    end
  end

  describe "GET /api/employees" do
    it "requires login" do
      get "/api/employees", as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    context "when logged in" do
      before { sign_in(user) }

      it "returns a page of 25 employees sorted by code, with pagination meta" do
        30.times { |i| employee_with_salary(employee_code: format("EMP%05d", 30 - i)) }

        get "/api/employees", as: :json

        expect(json["data"].size).to eq(25)
        expect(json["data"].first["employee_code"]).to eq("EMP00001")
        expect(json["meta"]).to eq("page" => 1, "per_page" => 25, "total" => 30)
      end

      it "returns the requested page and an empty page past the end" do
        30.times { |i| employee_with_salary(employee_code: format("EMP%05d", i + 1)) }

        get "/api/employees", params: { page: 2 }
        expect(json["data"].map { |e| e["employee_code"] }).to eq((26..30).map { |n| format("EMP%05d", n) })

        get "/api/employees", params: { page: 3 }
        expect(json["data"]).to eq([])
        expect(json["meta"]["total"]).to eq(30)
      end

      it "caps per_page at 100 and treats a bad page as page 1" do
        get "/api/employees", params: { per_page: 500, page: -3 }

        expect(json["meta"]).to include("page" => 1, "per_page" => 100)
      end

      it "returns the employee fields with the bank account masked" do
        employee = employee_with_salary(employee_code: "EMP00001", full_name: "Priya Shah", country: india,
          department: "Finance", job_title: "Accountant", bank_account_number: "998877665544", gross_base: "70000.00")

        get "/api/employees", as: :json

        expect(json["data"].first).to eq(
          "id" => employee.id, "employee_code" => "EMP00001", "full_name" => "Priya Shah",
          "country" => { "id" => india.id, "code" => "IN", "name" => "India" },
          "department" => "Finance", "job_title" => "Accountant", "status" => "active",
          "bank_account" => "•••• 5544", "joined_on" => "2024-01-15", "terminated_on" => nil,
          "current_annual_gross" => "70000.0"
        )
        expect(response.body).not_to include("998877665544")
      end

      it "shows the salary effective today, not a future one, and none for an upcoming joiner" do
        employee = employee_with_salary(employee_code: "EMP00001", gross_base: "50000.00")
        create(:salary_revision, employee: employee, effective_on: Date.new(2026, 11, 1), annual_base: "90000.00",
          annual_allowances: "0.00", reason: "increment")
        employee_with_salary(employee_code: "EMP00002", joined_on: Date.new(2026, 11, 1))

        get "/api/employees", as: :json

        expect(json["data"].map { |e| e["current_annual_gross"] }).to eq([ "50000.0", nil ])
      end

      it "filters by country, department, job title and status" do
        in_finance = employee_with_salary(country: india, department: "Finance", job_title: "Accountant")
        us_engineer = employee_with_salary(country: us, department: "Engineering", job_title: "QA Engineer")
        leaver = employee_with_salary(country: us, terminated_on: Date.new(2026, 9, 30))

        ids = ->(params) { get("/api/employees", params: params) && json["data"].map { |e| e["id"] } }

        expect(ids.call(country_id: india.id)).to eq([ in_finance.id ])
        expect(ids.call(department: "Engineering")).to match_array([ us_engineer.id, leaver.id ])
        expect(ids.call(job_title: "QA Engineer")).to eq([ us_engineer.id ])
        expect(ids.call(status: "terminated")).to eq([ leaver.id ])
        expect(ids.call(country_id: us.id, status: "active")).to eq([ us_engineer.id ])
      end

      it "searches by part of the name or code, ignoring case" do
        priya = employee_with_salary(employee_code: "EMP00042", full_name: "Priya Shah")
        employee_with_salary(employee_code: "EMP00007", full_name: "Liam Smith")

        get "/api/employees", params: { q: "pRiY" }
        expect(json["data"].map { |e| e["id"] }).to eq([ priya.id ])

        get "/api/employees", params: { q: "emp00042" }
        expect(json["data"].map { |e| e["id"] }).to eq([ priya.id ])
      end

      it "ignores a search that isn't plain text instead of crashing" do
        employee_with_salary

        get "/api/employees", params: { q: [ "x" ] }

        expect(response).to have_http_status(:ok)
        expect(json["meta"]["total"]).to eq(1)
      end

      it "handles malformed and huge page numbers without crashing" do
        get "/api/employees", params: { page: [ "2" ], per_page: [ "5" ] }
        expect(response).to have_http_status(:ok)
        expect(json["meta"]).to include("page" => 1, "per_page" => 25)

        get "/api/employees", params: { page: "99999999999999999999" }
        expect(response).to have_http_status(:ok)
        expect(json["meta"]["page"]).to eq(1_000_000)
        expect(json["data"]).to eq([])
      end

      it "uses the same number of queries for 5 employees as for 25" do
        5.times { employee_with_salary }
        query_count = -> { count_queries { get "/api/employees", as: :json } }
        few = query_count.call
        20.times { employee_with_salary }

        expect(query_count.call).to eq(few)
      end
    end
  end

  def count_queries(&block)
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:name].in?(%w[SCHEMA TRANSACTION]) || payload[:cached] }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &block)
    count
  end
end
