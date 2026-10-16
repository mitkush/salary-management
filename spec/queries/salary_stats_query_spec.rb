require "rails_helper"

RSpec.describe SalaryStatsQuery do
  around { |example| travel_to(Date.new(2026, 10, 16)) { example.run } }

  let(:india) { create(:country, code: "IN", name: "India") }
  let(:us) { create(:country, code: "US", name: "United States") }

  def employee(gross:, country: india, department: "Engineering", job_title: "Software Engineer", **attributes)
    create(:employee, country: country, department: department, job_title: job_title, **attributes).tap do |e|
      create(:salary_revision, employee: e, annual_base: gross, annual_allowances: "0.00")
    end
  end

  def summary(**filters)
    described_class.new(**filters).summary
  end

  it "summarises active employees' current annual gross" do
    employee(gross: "60000.00")
    employee(gross: "80000.00")
    employee(gross: "100000.00")

    expect(summary).to eq(
      headcount: 3, total: BigDecimal("240000"), min: BigDecimal("60000"), max: BigDecimal("100000"),
      average: BigDecimal("80000"), median: BigDecimal("80000")
    )
  end

  it "takes the middle two for the median of an even count, rounded to cents" do
    employee(gross: "60000.00")
    employee(gross: "80000.01")

    expect(summary).to include(median: BigDecimal("70000.01"), average: BigDecimal("70000.01"))
  end

  it "counts only active employees" do
    employee(gross: "50000.00")
    employee(gross: "70000.00", terminated_on: Date.new(2026, 10, 16))
    employee(gross: "90000.00", terminated_on: Date.new(2026, 10, 15))
    employee(gross: "110000.00", joined_on: Date.new(2026, 10, 17))

    expect(summary).to include(headcount: 2, total: BigDecimal("120000"))
  end

  it "uses each employee's current revision, not an older or a future one" do
    person = employee(gross: "50000.00", joined_on: Date.new(2025, 1, 1))
    create(:salary_revision, employee: person, effective_on: Date.new(2026, 1, 1), annual_base: "60000.00",
      annual_allowances: "0.00", reason: "increment")
    create(:salary_revision, employee: person, effective_on: Date.new(2026, 12, 1), annual_base: "90000.00",
      annual_allowances: "0.00", reason: "increment")

    expect(summary).to include(headcount: 1, total: BigDecimal("60000"))
  end

  it "applies the country, department and job title filters" do
    employee(gross: "50000.00", country: india, department: "Finance", job_title: "Accountant")
    employee(gross: "70000.00", country: us, department: "Engineering", job_title: "QA Engineer")
    employee(gross: "90000.00", country: us, department: "Finance", job_title: "Accountant")

    expect(summary(country_id: us.id)).to include(headcount: 2, total: BigDecimal("160000"))
    expect(summary(department: "Finance")).to include(headcount: 2, total: BigDecimal("140000"))
    expect(summary(job_title: "QA Engineer", country_id: us.id)).to include(headcount: 1, total: BigDecimal("70000"))
  end

  it "returns zero headcount and total, and no other values, when nobody matches" do
    expect(summary).to eq(headcount: 0, total: BigDecimal("0"), min: nil, max: nil, average: nil, median: nil)
  end

  describe "as of a past date" do
    let(:as_of) { Date.new(2026, 9, 30) }

    it "counts who was active on that date, at the salary in effect then" do
      raised_later = employee(gross: "60000.00", joined_on: Date.new(2025, 1, 1))
      create(:salary_revision, employee: raised_later, effective_on: Date.new(2026, 10, 1), annual_base: "99000.00",
        annual_allowances: "0.00", reason: "increment")
      employee(gross: "40000.00", joined_on: Date.new(2025, 1, 1), terminated_on: Date.new(2026, 10, 5))
      employee(gross: "70000.00", joined_on: Date.new(2026, 10, 1))
      employee(gross: "80000.00", joined_on: Date.new(2025, 1, 1), terminated_on: Date.new(2026, 9, 29))

      expect(described_class.new(as_of: as_of).summary).to include(headcount: 2, total: BigDecimal("100000"))
    end
  end

  describe "#groups" do
    before do
      employee(gross: "50000.00", country: india, department: "Finance")
      employee(gross: "60000.00", country: india, department: "Engineering")
      employee(gross: "200000.00", country: us, department: "Engineering")
    end

    it "breaks the same numbers down by country, highest total first" do
      groups = described_class.new(group_by: "country").groups

      expect(groups.map { |g| [ g[:name], g[:headcount], g[:total] ] }).to eq(
        [ [ "United States", 1, BigDecimal("200000") ], [ "India", 2, BigDecimal("110000") ] ]
      )
      expect(groups.last).to include(median: BigDecimal("55000"))
    end

    it "breaks down by department and respects the filters" do
      groups = described_class.new(group_by: "department", country_id: india.id).groups

      expect(groups.map { |g| [ g[:name], g[:total] ] }).to eq([ [ "Engineering", BigDecimal("60000") ], [ "Finance", BigDecimal("50000") ] ])
    end

    it "gives each group's share of the total cost as a percentage, rounded to 2 decimals" do
      groups = described_class.new(group_by: "country").groups

      expect(groups.map { |g| g[:share] }).to eq([ BigDecimal("64.52"), BigDecimal("35.48") ])
    end

    it "rejects an unknown grouping" do
      expect { described_class.new(group_by: "job_title; DROP TABLE employees").groups }.to raise_error(ArgumentError)
    end
  end
end
