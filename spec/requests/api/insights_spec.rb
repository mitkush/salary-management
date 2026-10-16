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

    it "returns 400 for an unknown group_by" do
      get "/api/insights", params: { group_by: "job_title" }

      expect(response).to have_http_status(:bad_request)
      expect(json).to eq("error" => { "code" => "bad_request", "message" => "group_by must be country or department." })
    end
  end
end
