require "rails_helper"

RSpec.describe SalaryRevision, type: :model do
  around { |example| travel_to(Date.new(2026, 10, 16)) { example.run } }

  let(:employee) { create(:employee, joined_on: Date.new(2025, 3, 1)) }

  it "is valid on the joining date with an allowed reason" do
    expect(build(:salary_revision, employee: employee, effective_on: Date.new(2025, 3, 1))).to be_valid
  end

  it "rejects a date before the joining date" do
    revision = build(:salary_revision, employee: employee, effective_on: Date.new(2025, 2, 28))

    expect(revision).not_to be_valid
    expect(revision.errors[:effective_on]).to include("can't be before the joining date")
  end

  it "rejects a date after the last working day" do
    employee.update!(terminated_on: Date.new(2026, 6, 30))
    revision = build(:salary_revision, employee: employee, effective_on: Date.new(2026, 7, 1), reason: "increment")

    expect(revision).not_to be_valid
    expect(revision.errors[:effective_on]).to include("can't be after the last working day")
  end

  it "allows the last working day itself" do
    employee.update!(terminated_on: Date.new(2026, 6, 30))

    expect(build(:salary_revision, employee: employee, effective_on: Date.new(2026, 6, 30), reason: "increment")).to be_valid
  end

  it "allows a future date" do
    expect(build(:salary_revision, employee: employee, effective_on: Date.new(2027, 1, 1), reason: "increment")).to be_valid
  end

  it "rejects a second revision on the same date for the same employee" do
    create(:salary_revision, employee: employee, effective_on: Date.new(2025, 3, 1))
    revision = build(:salary_revision, employee: employee, effective_on: Date.new(2025, 3, 1), reason: "correction")

    expect(revision).not_to be_valid
    expect(revision.errors[:effective_on]).to include("already has a revision for this employee")
  end

  it "only accepts the allowed reasons" do
    expect(build(:salary_revision, employee: employee, reason: "bonus")).not_to be_valid
    SalaryRevision::REASONS.each do |reason|
      expect(build(:salary_revision, employee: employee, reason: reason)).to be_valid
    end
  end

  it "rejects negative amounts and missing amounts" do
    expect(build(:salary_revision, employee: employee, annual_base: -1)).not_to be_valid
    expect(build(:salary_revision, employee: employee, annual_allowances: -1)).not_to be_valid
    expect(build(:salary_revision, employee: employee, annual_deductions: nil)).not_to be_valid
  end

  it "gets annual gross from the database as base plus allowances" do
    revision = create(:salary_revision, employee: employee, annual_base: "50000.50", annual_allowances: "1000.25")

    expect(revision.reload.annual_gross).to eq(BigDecimal("51000.75"))
  end

  it "can't be changed once saved" do
    revision = create(:salary_revision, employee: employee)

    expect { revision.update!(annual_base: "1.00") }.to raise_error(ActiveRecord::ReadOnlyRecord)
  end

  describe "#never_applies?" do
    it "is true only for a revision dated after the last working day" do
      before_exit = create(:salary_revision, employee: employee, effective_on: Date.new(2026, 12, 1), reason: "increment")
      after_exit = create(:salary_revision, employee: employee, effective_on: Date.new(2027, 1, 1), reason: "increment")
      employee.terminate!(Date.new(2026, 12, 31))

      expect(before_exit.reload.never_applies?).to be(false)
      expect(after_exit.reload.never_applies?).to be(true)
    end
  end

  describe "Employee#current_revision" do
    it "is the latest revision effective on or before today, ignoring future ones" do
      create(:salary_revision, employee: employee, effective_on: Date.new(2025, 3, 1))
      today = create(:salary_revision, employee: employee, effective_on: Date.new(2026, 10, 16), reason: "increment")
      create(:salary_revision, employee: employee, effective_on: Date.new(2026, 10, 17), reason: "promotion")

      expect(employee.current_revision).to eq(today)
    end

    it "is nil for an upcoming employee whose only revision is in the future" do
      upcoming = create(:employee, joined_on: Date.new(2026, 11, 1))
      create(:salary_revision, employee: upcoming)

      expect(upcoming.current_revision).to be_nil
    end
  end
end
