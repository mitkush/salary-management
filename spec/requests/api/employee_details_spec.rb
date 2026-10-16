require "rails_helper"

RSpec.describe "API employee details, revisions and termination", type: :request do
  around { |example| travel_to(Date.new(2026, 10, 16)) { example.run } }

  let(:employee) { create(:employee, joined_on: Date.new(2025, 3, 1), bank_account_number: "123456789876") }
  let!(:initial) { create(:salary_revision, employee: employee, effective_on: Date.new(2025, 3, 1)) }

  def json
    response.parsed_body
  end

  it "requires login for all three endpoints" do
    get "/api/employees/#{employee.id}", as: :json
    expect(response).to have_http_status(:unauthorized)

    post "/api/employees/#{employee.id}/salary_revisions", params: {}, as: :json
    expect(response).to have_http_status(:unauthorized)

    post "/api/employees/#{employee.id}/termination", params: {}, as: :json
    expect(response).to have_http_status(:unauthorized)
  end

  context "when logged in" do
    before { sign_in(create(:user)) }

    describe "GET /api/employees/:id" do
      it "returns the employee with the bank account masked and revisions newest first" do
        later = create(:salary_revision, employee: employee, effective_on: Date.new(2026, 4, 1), reason: "increment",
          annual_base: "66000.00", annual_allowances: "6600.00", annual_deductions: "2640.00")

        get "/api/employees/#{employee.id}", as: :json

        expect(response).to have_http_status(:ok)
        expect(json["employee"]).to include("id" => employee.id, "bank_account" => "•••• 9876", "status" => "active",
          "current_annual_gross" => "72600.0")
        expect(json["revisions"].map { |r| r["id"] }).to eq([ later.id, initial.id ])
        expect(json["revisions"].first).to eq(
          "id" => later.id, "effective_on" => "2026-04-01", "annual_base" => "66000.0", "annual_allowances" => "6600.0",
          "annual_deductions" => "2640.0", "annual_gross" => "72600.0", "reason" => "increment", "never_applies" => false
        )
        expect(response.body).not_to include("123456789876")
      end

      it "marks a revision dated after the last working day as never applying" do
        future = create(:salary_revision, employee: employee, effective_on: Date.new(2027, 1, 1), reason: "increment")
        employee.terminate!(Date.new(2026, 12, 31))

        get "/api/employees/#{employee.id}", as: :json

        expect(json["revisions"].find { |r| r["id"] == future.id }["never_applies"]).to be(true)
      end

      it "returns 404 in the API error format for an unknown employee" do
        get "/api/employees/0", as: :json

        expect(response).to have_http_status(:not_found)
        expect(json).to eq("error" => { "code" => "not_found", "message" => "Not found." })
      end
    end

    describe "POST /api/employees/:id/salary_revisions" do
      let(:valid) do
        { effective_on: "2026-11-01", annual_base: "70000", annual_allowances: "7000", annual_deductions: "2800", reason: "increment" }
      end

      it "adds a revision and returns it with 201" do
        post "/api/employees/#{employee.id}/salary_revisions", params: { salary_revision: valid }, as: :json

        expect(response).to have_http_status(:created)
        expect(json).to include("effective_on" => "2026-11-01", "annual_gross" => "77000.0", "reason" => "increment")
        expect(employee.salary_revisions.count).to eq(2)
      end

      it "returns 422 with field errors for a date before joining" do
        post "/api/employees/#{employee.id}/salary_revisions",
          params: { salary_revision: valid.merge(effective_on: "2025-02-28") }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(json["error"]).to include("code" => "validation_failed")
        expect(json.dig("error", "details", "effective_on")).to eq([ "can't be before the joining date" ])
      end

      it "returns 422 for a duplicate date, a bad reason and a negative amount" do
        post "/api/employees/#{employee.id}/salary_revisions",
          params: { salary_revision: valid.merge(effective_on: "2025-03-01", reason: "bonus", annual_base: "-1") }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(json.dig("error", "details").keys).to contain_exactly("effective_on", "reason", "annual_base")
      end

      it "ignores attributes that can't be set, like annual_gross or employee_id" do
        other = create(:employee)

        post "/api/employees/#{employee.id}/salary_revisions",
          params: { salary_revision: valid.merge(annual_gross: "1", employee_id: other.id) }, as: :json

        expect(response).to have_http_status(:created)
        expect(json["annual_gross"]).to eq("77000.0")
        expect(other.salary_revisions.count).to eq(0)
      end

      it "returns 400 in the API error format when the revision fields are missing" do
        post "/api/employees/#{employee.id}/salary_revisions", params: {}, as: :json

        expect(response).to have_http_status(:bad_request)
        expect(json).to eq("error" => { "code" => "bad_request", "message" => "Missing or invalid parameters." })
      end

      it "returns 404 for an unknown employee" do
        post "/api/employees/0/salary_revisions", params: { salary_revision: valid }, as: :json

        expect(response).to have_http_status(:not_found)
      end
    end

    describe "POST /api/employees/:id/termination" do
      it "sets the last working day and returns the employee" do
        post "/api/employees/#{employee.id}/termination", params: { terminated_on: "2026-10-15" }, as: :json

        expect(response).to have_http_status(:ok)
        expect(json).to include("terminated_on" => "2026-10-15", "status" => "terminated")
      end

      it "is not blocked by a future revision" do
        create(:salary_revision, employee: employee, effective_on: Date.new(2027, 1, 1), reason: "increment")

        post "/api/employees/#{employee.id}/termination", params: { terminated_on: "2026-11-30" }, as: :json

        expect(response).to have_http_status(:ok)
      end

      it "returns 422 for a date before joining" do
        post "/api/employees/#{employee.id}/termination", params: { terminated_on: "2025-02-28" }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(json.dig("error", "details", "terminated_on")).to eq([ "can't be before the joining date" ])
      end

      it "returns 422 for a missing or invalid date" do
        post "/api/employees/#{employee.id}/termination", params: { terminated_on: "not-a-date" }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(json.dig("error", "details", "terminated_on")).to eq([ "can't be blank" ])
      end

      it "returns 422 when the employee is already terminated" do
        employee.terminate!(Date.new(2026, 10, 31))

        post "/api/employees/#{employee.id}/termination", params: { terminated_on: "2026-11-30" }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(employee.reload.terminated_on).to eq(Date.new(2026, 10, 31))
      end
    end
  end
end
