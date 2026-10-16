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
end
