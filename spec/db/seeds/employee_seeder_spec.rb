require "rails_helper"
require Rails.root.join("db/seeds/employee_seeder")

RSpec.describe EmployeeSeeder do
  around { |example| travel_to(Date.new(2026, 10, 16)) { example.run } }

  def seed(count: 200, random_seed: 42)
    described_class.call(count: count, random: Random.new(random_seed))
  end

  def snapshot
    Employee.order(:employee_code).includes(:country, :salary_revisions).map do |employee|
      [
        employee.employee_code, employee.full_name, employee.country.code, employee.department, employee.job_title,
        employee.bank_account_number, employee.joined_on, employee.terminated_on,
        employee.salary_revisions.sort_by(&:effective_on).map { |r| [ r.effective_on, r.annual_base, r.annual_allowances, r.annual_deductions, r.reason ] }
      ]
    end
  end

  it "creates the requested number of employees and the seeded countries with tax rates" do
    seed

    expect(Employee.count).to eq(200)
    expect(Country.pluck(:code)).to match_array(%w[US IN GB DE SG BR])
    expect(Country.pluck(:tax_rate)).to all(be_between(0, 1))
  end

  it "creates exactly the same data for the same random seed" do
    seed
    first_run = snapshot
    SalaryRevision.delete_all
    Employee.delete_all

    seed

    expect(snapshot).to eq(first_run)
  end

  it "gives every employee an initial revision on their joining date" do
    seed

    Employee.includes(:salary_revisions).find_each do |employee|
      first = employee.salary_revisions.min_by(&:effective_on)
      expect([ first.effective_on, first.reason ]).to eq([ employee.joined_on, "initial" ])
    end
  end

  it "includes active, terminated and upcoming employees, and some with several revisions" do
    seed

    expect(Employee.with_status("active").count).to be > 150
    expect(Employee.with_status("terminated").count).to be_positive
    expect(Employee.with_status("upcoming").count).to be_positive
    expect(SalaryRevision.group(:employee_id).count.values.max).to be_between(2, 3)
    expect(SalaryRevision.group(:employee_id).having("COUNT(*) > 1").count.size).to be > 40
  end

  it "only creates revisions that pass the model's rules" do
    seed

    invalid = SalaryRevision.includes(:employee).reject(&:valid?)
    expect(invalid.map { |r| [ r.employee.employee_code, r.errors.full_messages ] }).to eq([])
  end

  it "keeps each starting salary within the range for that country and job title" do
    seed

    Employee.includes(:country, :salary_revisions).find_each do |employee|
      range = described_class.base_range(employee.country.code, employee.job_title)
      initial = employee.salary_revisions.find { |r| r.reason == "initial" }
      expect(initial.annual_base).to be_between(range.min, range.max)
    end
  end

  it "does nothing when employees already exist" do
    seed

    expect { seed(random_seed: 7) }.not_to change { [ Employee.count, SalaryRevision.count, Country.count ] }
  end
end
