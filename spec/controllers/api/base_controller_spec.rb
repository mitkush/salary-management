require "rails_helper"

RSpec.describe Api::BaseController, type: :controller do
  controller(described_class) do
    def index
      render json: { ok: true }
    end
  end

  it "returns 401 in the API error format when nobody is logged in" do
    get :index

    expect(response).to have_http_status(:unauthorized)
    expect(response.parsed_body).to eq("error" => { "code" => "unauthorized", "message" => "Please log in." })
  end

  it "lets a logged in user through" do
    session = create(:user).sessions.create!
    cookies.signed[:session_id] = session.id

    get :index

    expect(response).to have_http_status(:ok)
  end
end
