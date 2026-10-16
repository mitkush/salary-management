require "rails_helper"

RSpec.describe "API filter options", type: :request do
  it "requires login" do
    get "/api/filter_options", as: :json

    expect(response).to have_http_status(:unauthorized)
  end

  it "lists countries, departments and job titles, sorted and without duplicates" do
    sign_in(create(:user))
    us = create(:country, code: "US", name: "United States")
    india = create(:country, code: "IN", name: "India")
    create(:employee, country: us, department: "Sales", job_title: "Account Executive")
    create(:employee, country: india, department: "Engineering", job_title: "QA Engineer")
    create(:employee, country: india, department: "Engineering", job_title: "QA Engineer")

    get "/api/filter_options", as: :json

    expect(response.parsed_body).to eq(
      "countries" => [ { "id" => india.id, "code" => "IN", "name" => "India" }, { "id" => us.id, "code" => "US", "name" => "United States" } ],
      "departments" => [ "Engineering", "Sales" ],
      "job_titles" => [ "Account Executive", "QA Engineer" ]
    )
  end
end
