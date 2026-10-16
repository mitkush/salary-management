require "rails_helper"

RSpec.describe "API insights", type: :request do
  around { |example| travel_to(Date.new(2026, 10, 16)) { example.run } }

  let(:india) { create(:country, code: "IN", name: "India") }
  let(:us) { create(:country, code: "US", name: "United States") }

  def employee(gross:, country:, department: "Engineering")
    create(:employee, country: country, department: department).tap do |e|
      create(:salary_revision, employee: e, annual_base: gross, annual_allowances: "0.00")
    end
  end

  def json
    response.parsed_body
  end

  it "requires login" do
    get "/api/insights", as: :json
    expect(response).to have_http_status(:unauthorized)

    get "/api/insights/trends", as: :json
    expect(response).to have_http_status(:unauthorized)
  end

  context "when logged in" do
    before do
      sign_in(create(:user))
      employee(gross: "60000.00", country: india, department: "Finance")
      employee(gross: "80000.00", country: india)
      employee(gross: "200000.00", country: us)
    end

    it "returns the summary without groups by default" do
      get "/api/insights", as: :json

      expect(json).to eq(
        "as_of" => "2026-09-30",
        "summary" => { "headcount" => 3, "total" => "340000.0", "min" => "60000.0", "max" => "200000.0",
                       "average" => "113333.33", "median" => "80000.0" },
        "groups" => []
      )
    end

    it "applies the filters to the summary and the groups" do
      get "/api/insights", params: { country_id: india.id, group_by: "department" }

      expect(json["summary"]).to include("headcount" => 2, "total" => "140000.0")
      expect(json["groups"].map { |g| [ g["name"], g["total"] ] }).to eq([ [ "Engineering", "80000.0" ], [ "Finance", "60000.0" ] ])
    end

    it "groups by country" do
      get "/api/insights", params: { group_by: "country" }

      expect(json["groups"].map { |g| g["name"] }).to eq([ "United States", "India" ])
    end

    it "reports as of last month's end by default, and as of today for the current month" do
      get "/api/insights", as: :json
      expect(json["as_of"]).to eq("2026-09-30")

      get "/api/insights", params: { as_of: "2026-10" }
      expect(json["as_of"]).to eq("2026-10-16")
      expect(json["summary"]["headcount"]).to eq(3)
    end

    it "excludes employees who joined after the chosen month" do
      get "/api/insights", params: { as_of: "2023-12" }

      expect(json).to include("as_of" => "2023-12-31")
      expect(json["summary"]["headcount"]).to eq(0)
    end

    it "returns 400 for a future or malformed month" do
      get "/api/insights", params: { as_of: "2026-11" }
      expect(response).to have_http_status(:bad_request)
      expect(json.dig("error", "message")).to eq("as_of can't be in the future.")

      get "/api/insights", params: { as_of: "2026-1" }
      expect(response).to have_http_status(:bad_request)
    end

    it "returns the 12-month trends ending with the chosen month, with filters" do
      get "/api/insights/trends", params: { as_of: "2026-10", country_id: india.id }

      expect(response).to have_http_status(:ok)
      expect(json["months"].size).to eq(12)
      expect(json["months"].last).to eq("month" => "2026-10", "monthly_cost" => "11666.67", "joiners" => 0, "leavers" => 0)
    end

    it "returns 400 for an unknown group_by" do
      get "/api/insights", params: { group_by: "job_title" }

      expect(response).to have_http_status(:bad_request)
      expect(json).to eq("error" => { "code" => "bad_request", "message" => "group_by must be country or department." })
    end
  end
end
