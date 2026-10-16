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

  describe "GET /api/session" do
    it "reports a logged out visitor and still gives a CSRF token" do
      get "/api/session", as: :json

      expect(response).to have_http_status(:ok)
      expect(json).to include("authenticated" => false, "user" => nil)
      expect(json["csrf_token"]).to be_present
    end

    it "reports the logged in user after a page refresh" do
      sign_in(user, password: "s3cret-pass")

      get "/api/session", as: :json

      expect(json).to include("authenticated" => true, "user" => { "id" => user.id, "email_address" => "hr@example.com" })
    end

    it "treats a session older than a day as logged out" do
      sign_in(user, password: "s3cret-pass")

      travel 1.day + 1.second do
        get "/api/session", as: :json

        expect(json["authenticated"]).to be(false)
      end
    end
  end

  describe "DELETE /api/session" do
    it "logs out so the session no longer works" do
      sign_in(user, password: "s3cret-pass")

      delete "/api/session", as: :json
      expect(response).to have_http_status(:no_content)

      get "/api/session", as: :json
      expect(json["authenticated"]).to be(false)
      expect(user.sessions.count).to eq(0)
    end

    it "returns 401 when nobody is logged in" do
      delete "/api/session", as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(json).to eq("error" => { "code" => "unauthorized", "message" => "Please log in." })
    end
  end

  describe "CSRF protection" do
    around do |example|
      original = ActionController::Base.allow_forgery_protection
      ActionController::Base.allow_forgery_protection = true
      example.run
    ensure
      ActionController::Base.allow_forgery_protection = original
    end

    def login_with_token(token)
      post "/api/session", params: { email_address: "hr@example.com", password: "s3cret-pass" },
        headers: { "X-CSRF-Token" => token }, as: :json
    end

    it "rejects a login without a CSRF token with 422" do
      post "/api/session", params: { email_address: "hr@example.com", password: "s3cret-pass" }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json.dig("error", "code")).to eq("invalid_csrf_token")
    end

    it "accepts a login with the token from GET /api/session" do
      get "/api/session", as: :json

      login_with_token(json["csrf_token"])

      expect(response).to have_http_status(:ok)
    end

    it "rotates the token on login so the old one stops working" do
      get "/api/session", as: :json
      old_token = json["csrf_token"]
      login_with_token(old_token)
      new_token = json["csrf_token"]

      delete "/api/session", headers: { "X-CSRF-Token" => old_token }, as: :json
      expect(response).to have_http_status(:unprocessable_content)

      delete "/api/session", headers: { "X-CSRF-Token" => new_token }, as: :json
      expect(response).to have_http_status(:no_content)
    end
  end
end
