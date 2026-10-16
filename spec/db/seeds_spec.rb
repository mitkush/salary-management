require "rails_helper"

RSpec.describe "db/seeds.rb" do
  def load_seeds
    load Rails.root.join("db/seeds.rb")
  end

  it "creates the HR user from HR_EMAIL and HR_PASSWORD" do
    stub_const("ENV", ENV.to_h.merge("HR_EMAIL" => "boss@acme.test", "HR_PASSWORD" => "from-env-pass"))

    load_seeds

    expect(User.authenticate_by(email_address: "boss@acme.test", password: "from-env-pass")).to be_present
  end

  it "falls back to the local demo login when the variables are not set" do
    stub_const("ENV", ENV.to_h.except("HR_EMAIL", "HR_PASSWORD"))

    load_seeds

    expect(User.authenticate_by(email_address: "hr@example.com", password: "password")).to be_present
  end

  it "does not create a second HR user when run again" do
    stub_const("ENV", ENV.to_h.except("HR_EMAIL", "HR_PASSWORD"))

    2.times { load_seeds }

    expect(User.count).to eq(1)
  end
end
