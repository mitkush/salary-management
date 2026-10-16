module AuthHelpers
  def sign_in(user, password: "password")
    post "/api/session", params: { email_address: user.email_address, password: password }, as: :json
    response.parsed_body["csrf_token"]
  end
end

RSpec.configure do |config|
  config.include AuthHelpers, type: :request
end
