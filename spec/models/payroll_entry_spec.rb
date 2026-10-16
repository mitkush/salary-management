require "rails_helper"

RSpec.describe PayrollEntry, type: :model do
  it "is valid with zero adjustments and no note" do
    expect(build(:payroll_entry, bonus: 0, one_time_deduction: 0, adjustment_note: nil)).to be_valid
  end

  it "rejects negative, too large or non-numeric adjustments" do
    expect(build(:payroll_entry, bonus: -1)).not_to be_valid
    expect(build(:payroll_entry, one_time_deduction: "1000000000.01")).not_to be_valid
    expect(build(:payroll_entry, bonus: "abc")).not_to be_valid
  end

  it "allows one entry per employee in a run" do
    entry = create(:payroll_entry)

    duplicate = build(:payroll_entry, payroll_run: entry.payroll_run, employee: entry.employee, salary_revision: entry.salary_revision)
    expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
