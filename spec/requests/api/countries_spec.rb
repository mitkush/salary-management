require "rails_helper"

RSpec.describe "API countries", type: :request do
  let!(:us) { create(:country, code: "US", name: "United States", tax_rate: "0.2500") }
  let!(:india) { create(:country, code: "IN", name: "India", tax_rate: "0.2000") }

  def json
    response.parsed_body
  end

  it "requires login for listing and updating" do
    get "/api/countries", as: :json
    expect(response).to have_http_status(:unauthorized)

    patch "/api/countries/#{india.id}", params: { country: { tax_rate_percent: "10" } }, as: :json
    expect(response).to have_http_status(:unauthorized)
  end

  context "when logged in" do
    before { sign_in(create(:user)) }

    it "lists countries by name with the tax rate as a percent" do
      get "/api/countries", as: :json

      expect(json).to eq([
        { "id" => india.id, "code" => "IN", "name" => "India", "tax_rate_percent" => "20.0" },
        { "id" => us.id, "code" => "US", "name" => "United States", "tax_rate_percent" => "25.0" }
      ])
    end

    it "updates the tax rate from a percent" do
      patch "/api/countries/#{india.id}", params: { country: { tax_rate_percent: "18.5" } }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json).to eq("id" => india.id, "code" => "IN", "name" => "India", "tax_rate_percent" => "18.5")
      expect(india.reload.tax_rate).to eq(BigDecimal("0.185"))
    end

    it "only changes the tax rate, not the code or name" do
      patch "/api/countries/#{india.id}", params: { country: { tax_rate_percent: "18", code: "XX", name: "Other" } }, as: :json

      expect(india.reload).to have_attributes(code: "IN", name: "India")
    end

    {
      "-5" => "must be between 0 and 100",
      "100.5" => "must be between 0 and 100",
      "abc" => "must be a number",
      "1.234" => "can have at most 2 decimals"
    }.each do |value, message|
      it "returns 422 with the reason under tax_rate_percent for #{value.inspect}" do
        patch "/api/countries/#{india.id}", params: { country: { tax_rate_percent: value } }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(json.dig("error", "details")).to eq("tax_rate_percent" => [ message ])
        expect(india.reload.tax_rate).to eq(BigDecimal("0.2"))
      end
    end

    it "returns 404 for an unknown country" do
      patch "/api/countries/0", params: { country: { tax_rate_percent: "10" } }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end
