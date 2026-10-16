require "rails_helper"

RSpec.describe "Frontend", type: :request do
  around do |example|
    original = Rails.configuration.x.frontend_index_path
    Rails.configuration.x.frontend_index_path = file_fixture("frontend_index.html")
    example.run
  ensure
    Rails.configuration.x.frontend_index_path = original
  end

  it "serves the React app at the root" do
    get "/"

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/html")
    expect(response.body).to include('<div id="root">')
  end

  it "serves the React app for deep links so client-side routing works" do
    get "/employees/42"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('<div id="root">')
  end

  it "serves the React app for paths that only start with the letters api" do
    get "/apiary"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('<div id="root">')
  end

  it "does not serve the React app for the bare /api path" do
    get "/api"

    expect(response).to have_http_status(:not_found)
  end

  it "does not serve the React app for API paths" do
    get "/api/unknown"

    expect(response).to have_http_status(:not_found)
    expect(response.body).not_to include('<div id="root">')
  end
end
