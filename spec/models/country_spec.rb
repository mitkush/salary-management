require "rails_helper"

RSpec.describe Country, type: :model do
  it "is valid with a code, a name and a tax rate" do
    expect(build(:country)).to be_valid
  end

  it "requires a two-letter code, a name and a tax rate" do
    country = Country.new(code: "", name: "", tax_rate: nil)

    expect(country).not_to be_valid
    expect(country.errors.attribute_names).to include(:code, :name, :tax_rate)
  end

  it "rejects a code that isn't two letters" do
    expect(build(:country, code: "USA")).not_to be_valid
  end

  it "rejects a duplicate code or name" do
    create(:country, code: "IN", name: "India")

    expect(build(:country, code: "IN", name: "Other")).not_to be_valid
    expect(build(:country, code: "XX", name: "India")).not_to be_valid
  end

  it "accepts tax rates from 0 to 1 and rejects anything outside" do
    expect(build(:country, tax_rate: 0)).to be_valid
    expect(build(:country, tax_rate: 1)).to be_valid
    expect(build(:country, tax_rate: -0.01)).not_to be_valid
    expect(build(:country, tax_rate: 1.01)).not_to be_valid
  end

  it "enforces the tax rate range in the database too" do
    country = create(:country)

    expect { country.update_column(:tax_rate, 1.5) }.to raise_error(ActiveRecord::StatementInvalid)
  end
end
