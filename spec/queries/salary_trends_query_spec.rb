require "rails_helper"

RSpec.describe SalaryTrendsQuery do
  around { |example| travel_to(Date.new(2026, 10, 16)) { example.run } }

  let(:india) { create(:country, code: "IN", name: "India") }
  let(:us) { create(:country, code: "US", name: "United States") }

  def employee(base:, joined_on: Date.new(2025, 1, 1), terminated_on: nil, country: india)
    create(:employee, country: country, joined_on: joined_on, terminated_on: terminated_on).tap do |e|
      create(:salary_revision, employee: e, effective_on: joined_on, annual_base: base, annual_allowances: "0.00")
    end
  end

  def months(**options)
    described_class.new(as_of_month: Date.new(2026, 10, 1), **options).months
  end

  def month(series, label)
    series.find { |m| m[:month] == label }
  end

  it "returns the 12 months ending with the chosen month, oldest first" do
    expect(months.map { |m| m[:month] }).to eq(%w[2025-11 2025-12 2026-01 2026-02 2026-03 2026-04 2026-05 2026-06
                                                   2026-07 2026-08 2026-09 2026-10])
  end

  it "gives the monthly salary cost of employees active at each month end, at the salary in effect then" do
    stayer = employee(base: "120000.00")
    create(:salary_revision, employee: stayer, effective_on: Date.new(2026, 6, 1), annual_base: "240000.00",
      annual_allowances: "0.00", reason: "increment")
    employee(base: "60000.00", terminated_on: Date.new(2026, 3, 15))

    series = months

    expect(month(series, "2026-02")[:monthly_cost]).to eq(BigDecimal("15000"))
    expect(month(series, "2026-03")[:monthly_cost]).to eq(BigDecimal("10000"))
    expect(month(series, "2026-06")[:monthly_cost]).to eq(BigDecimal("20000"))
  end

  it "counts joiners and leavers in the month they joined or left, up to today for the current month" do
    employee(base: "60000.00", joined_on: Date.new(2026, 8, 10))
    employee(base: "60000.00", terminated_on: Date.new(2026, 3, 15))
    employee(base: "60000.00", joined_on: Date.new(2026, 10, 20))

    series = months

    expect(month(series, "2026-08")).to include(joiners: 1, leavers: 0)
    expect(month(series, "2026-03")).to include(joiners: 0, leavers: 1)
    expect(month(series, "2026-10")).to include(joiners: 0, monthly_cost: BigDecimal("5000"))
  end

  it "returns zeros for months with no employees" do
    expect(months.first).to eq(month: "2025-11", monthly_cost: BigDecimal("0"), joiners: 0, leavers: 0)
  end

  it "applies the filters" do
    employee(base: "120000.00", country: india)
    employee(base: "240000.00", country: us, joined_on: Date.new(2026, 9, 1))

    series = months(country_id: us.id)

    expect(month(series, "2026-09")).to include(monthly_cost: BigDecimal("20000"), joiners: 1)
    expect(month(series, "2026-08")[:monthly_cost]).to eq(BigDecimal("0"))
  end
end
