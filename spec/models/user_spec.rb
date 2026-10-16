require "rails_helper"

RSpec.describe User, type: :model do
  it "stores the email address trimmed and lowercased" do
    user = create(:user, email_address: "  HR@Example.COM ")

    expect(user.email_address).to eq("hr@example.com")
  end

  it "requires an email address" do
    user = build(:user, email_address: "")

    expect(user).not_to be_valid
    expect(user.errors[:email_address]).to include("can't be blank")
  end

  it "rejects an email address that differs from an existing one only by case" do
    create(:user, email_address: "hr@example.com")
    user = build(:user, email_address: "HR@example.com")

    expect(user).not_to be_valid
    expect(user.errors[:email_address]).to include("has already been taken")
  end

  it "requires a password" do
    user = build(:user, password: nil)

    expect(user).not_to be_valid
    expect(user.errors[:password]).to include("can't be blank")
  end

  describe ".authenticate_by" do
    let!(:user) { create(:user, email_address: "hr@example.com", password: "s3cret-pass") }

    it "returns the user for the right email and password" do
      expect(User.authenticate_by(email_address: "HR@example.com", password: "s3cret-pass")).to eq(user)
    end

    it "returns nil for a wrong password" do
      expect(User.authenticate_by(email_address: "hr@example.com", password: "wrong")).to be_nil
    end

    it "returns nil for an unknown email address" do
      expect(User.authenticate_by(email_address: "nobody@example.com", password: "s3cret-pass")).to be_nil
    end
  end
end
