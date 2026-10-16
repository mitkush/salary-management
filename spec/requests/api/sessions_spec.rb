require "rails_helper"

RSpec.describe "API session", type: :request do
  let!(:user) { create(:user, email_address: "hr@example.com", password: "s3cret-pass") }

  def json
    response.parsed_body
  end

  describe "POST /api/session" do
    it "logs in with the right email and password" do
      post "/api/session", params: { email_address: "hr@example.com", password: "s3cret-pass" }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json["user"]).to eq("id" => user.id, "email_address" => "hr@example.com")
      expect(json["csrf_token"]).to be_present
    end

    it "sets an httponly, same-site session cookie that expires in a day" do
      freeze_time do
        post "/api/session", params: { email_address: "hr@example.com", password: "s3cret-pass" }, as: :json

        session_cookie = Array(response.headers["Set-Cookie"]).flat_map { |c| c.split("\n") }.find { |c| c.start_with?("session_id=") }
        expect(session_cookie).to match(/httponly/i)
        expect(session_cookie).to match(/samesite=lax/i)
        expect(session_cookie).to include("expires=#{1.day.from_now.httpdate}")
      end
    end

    it "never returns the password digest" do
      post "/api/session", params: { email_address: "hr@example.com", password: "s3cret-pass" }, as: :json

      expect(response.body).not_to include("password")
    end

    it "rejects a wrong password with 401" do
      post "/api/session", params: { email_address: "hr@example.com", password: "wrong" }, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(json).to eq("error" => { "code" => "invalid_credentials", "message" => "Invalid email or password." })
    end

    it "gives exactly the same response for an unknown email as for a wrong password" do
      post "/api/session", params: { email_address: "hr@example.com", password: "wrong" }, as: :json
      wrong_password = [ response.status, response.body ]

      post "/api/session", params: { email_address: "nobody@example.com", password: "wrong" }, as: :json
      unknown_email = [ response.status, response.body ]

      expect(unknown_email).to eq(wrong_password)
    end

    it "rejects a login with missing fields with 401" do
      post "/api/session", params: {}, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(json.dig("error", "code")).to eq("invalid_credentials")
    end
  end
end
