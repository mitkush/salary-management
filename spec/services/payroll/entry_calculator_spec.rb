require "rails_helper"

RSpec.describe Payroll::EntryCalculator do
  def prorate(month:, joined_on: Date.new(2020, 1, 1), terminated_on: nil, annual_gross: "120000", annual_deductions: "12000")
    described_class.prorate(month: month, joined_on: joined_on, terminated_on: terminated_on,
      annual_gross: BigDecimal(annual_gross), annual_deductions: BigDecimal(annual_deductions))
  end

  def settle(monthly_gross: "10000", monthly_deductions: "1000", tax_rate: "0.2", bonus: "0", one_time_deduction: "0")
    described_class.settle(monthly_gross: BigDecimal(monthly_gross), monthly_deductions: BigDecimal(monthly_deductions),
      tax_rate: BigDecimal(tax_rate), bonus: BigDecimal(bonus), one_time_deduction: BigDecimal(one_time_deduction))
  end

  describe ".prorate" do
    let(:october) { Date.new(2026, 10, 1) }

    it "pays a full month to someone employed all month" do
      expect(prorate(month: october)).to eq(days_worked: 31, monthly_gross: BigDecimal("10000"), monthly_deductions: BigDecimal("1000"))
    end

    it "pays a full month when they join on the 1st or leave on the last day" do
      expect(prorate(month: october, joined_on: Date.new(2026, 10, 1))[:days_worked]).to eq(31)
      expect(prorate(month: october, terminated_on: Date.new(2026, 10, 31))[:days_worked]).to eq(31)
    end

    it "counts the joining day for someone joining mid-month" do
      expect(prorate(month: october, joined_on: Date.new(2026, 10, 15))).to eq(
        days_worked: 17, monthly_gross: BigDecimal("5483.87"), monthly_deductions: BigDecimal("548.39")
      )
    end

    it "pays 1 day to someone joining on the last day or leaving on the 1st" do
      expect(prorate(month: october, joined_on: Date.new(2026, 10, 31))).to include(days_worked: 1, monthly_gross: BigDecimal("322.58"))
      expect(prorate(month: october, terminated_on: Date.new(2026, 10, 1))).to include(days_worked: 1, monthly_gross: BigDecimal("322.58"))
    end

    it "counts both days for someone joining and leaving in the same month" do
      expect(prorate(month: october, joined_on: Date.new(2026, 10, 10), terminated_on: Date.new(2026, 10, 20))[:days_worked]).to eq(11)
    end

    it "uses 29 days for February in a leap year and 28 otherwise" do
      leap = prorate(month: Date.new(2028, 2, 1), joined_on: Date.new(2028, 2, 15))
      regular = prorate(month: Date.new(2027, 2, 1), joined_on: Date.new(2027, 2, 15))

      expect(leap).to include(days_worked: 15, monthly_gross: BigDecimal("5172.41"))
      expect(regular).to include(days_worked: 14, monthly_gross: BigDecimal("5000"))
    end

    it "rounds to cents half up" do
      expect(prorate(month: october, annual_gross: "1.26", annual_deductions: "0.06")).to include(
        monthly_gross: BigDecimal("0.11"), monthly_deductions: BigDecimal("0.01")
      )
    end
  end

  describe ".settle" do
    it "taxes gross plus bonus and takes deductions after tax" do
      expect(settle(bonus: "500", one_time_deduction: "200")).to eq(tax: BigDecimal("2100"), net: BigDecimal("7200"))
    end

    it "rounds tax to cents half up" do
      expect(settle(monthly_gross: "100.05", monthly_deductions: "0", tax_rate: "0.1")).to eq(tax: BigDecimal("10.01"), net: BigDecimal("90.04"))
    end

    it "allows a negative net, e.g. when recovering a loan" do
      expect(settle(one_time_deduction: "9000")[:net]).to eq(BigDecimal("-2000"))
    end

    it "charges no tax at a 0% rate" do
      expect(settle(tax_rate: "0")).to eq(tax: BigDecimal("0"), net: BigDecimal("9000"))
    end
  end
end
