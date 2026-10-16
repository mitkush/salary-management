require "rails_helper"

RSpec.describe PayrollRun, type: :model do
  it "requires the month to be the 1st, in the model and the database" do
    run = build(:payroll_run, month: Date.new(2026, 9, 15))

    expect(run).not_to be_valid
    expect(run.errors[:month]).to include("must be the first day of the month")
    expect { create(:payroll_run).update_column(:month, Date.new(2026, 9, 15)) }.to raise_error(ActiveRecord::StatementInvalid)
  end

  it "allows only one run per month" do
    create(:payroll_run, month: Date.new(2026, 9, 1))

    expect(build(:payroll_run, month: Date.new(2026, 9, 1))).not_to be_valid
  end

  describe ".locked?" do
    it "is false for every month when there are no runs" do
      expect(described_class.locked?(Date.new(2026, 9, 1))).to be(false)
    end

    it "is true only for months before the latest run" do
      create(:payroll_run, month: Date.new(2026, 8, 1))
      create(:payroll_run, month: Date.new(2026, 9, 1))

      expect(described_class.locked?(Date.new(2026, 8, 1))).to be(true)
      expect(described_class.locked?(Date.new(2026, 8, 31))).to be(true)
      expect(described_class.locked?(Date.new(2026, 9, 1))).to be(false)
      expect(described_class.locked?(Date.new(2026, 10, 1))).to be(false)
    end
  end

  describe "#outdated?" do
    around { |example| travel_to(Time.zone.local(2026, 10, 16, 12)) { example.run } }

    let(:india) { create(:country, tax_rate: "0.2000") }
    let!(:person) { create(:employee, country: india, joined_on: Date.new(2025, 1, 1)) }
    let!(:initial) { create(:salary_revision, employee: person) }
    let(:run) { Payroll::Generator.call(Date.new(2026, 10, 1)) }

    before do
      run
      travel 1.minute
    end

    it "is false right after generating" do
      expect(run.outdated?).to be(false)
    end

    it "is true after a revision effective in or before the month is added" do
      create(:salary_revision, employee: person, effective_on: Date.new(2026, 10, 31), reason: "increment")

      expect(run.outdated?).to be(true)
    end

    it "stays false for a revision that starts after the month" do
      create(:salary_revision, employee: person, effective_on: Date.new(2026, 11, 1), reason: "increment")

      expect(run.outdated?).to be(false)
    end

    it "is true after a termination, a new employee or a tax rate change" do
      person.terminate!(Date.new(2026, 10, 20))
      expect(run.outdated?).to be(true)
    end

    it "is true after a new employee is added" do
      create(:employee, country: india)
      expect(run.outdated?).to be(true)
    end

    it "is true after a tax rate change" do
      india.update!(tax_rate_percent: "25")
      expect(run.outdated?).to be(true)
    end
  end
end
