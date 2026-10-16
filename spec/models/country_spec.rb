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

  describe "#tax_rate_percent" do
    let(:country) { create(:country, tax_rate: "0.2500") }

    it "reads the stored fraction as a percent" do
      expect(country.tax_rate_percent).to eq(BigDecimal("25"))
    end

    it "stores a percent with up to 2 decimals as a fraction" do
      country.update!(tax_rate_percent: "12.35")

      expect(country.reload.tax_rate).to eq(BigDecimal("0.1235"))
    end

    it "accepts 0 and 100" do
      expect(country.update(tax_rate_percent: "0")).to be(true)
      expect(country.update(tax_rate_percent: 100)).to be(true)
      expect(country.reload.tax_rate).to eq(BigDecimal("1"))
    end

    {
      "-1" => "must be between 0 and 100",
      "100.01" => "must be between 0 and 100",
      "12.345" => "can have at most 2 decimals",
      "abc" => "must be a number",
      "" => "can't be blank"
    }.each do |value, message|
      it "rejects #{value.inspect} with \"#{message}\" and keeps the old rate" do
        expect(country.update(tax_rate_percent: value)).to be(false)
        expect(country.errors[:tax_rate_percent]).to eq([ message ])
        expect(country.reload.tax_rate).to eq(BigDecimal("0.25"))
      end
    end
  end
end
