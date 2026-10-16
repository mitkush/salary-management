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

  describe "#adjust!" do
    let(:entry) do
      create(:payroll_entry, monthly_gross: "10000.00", monthly_deductions: "1000.00", tax_rate: "0.2000",
        tax: "2000.00", net: "7000.00", payroll_run: create(:payroll_run, month: Date.new(2026, 10, 1)))
    end

    it "saves the adjustments and recalculates only this entry's tax and net" do
      other = create(:payroll_entry, payroll_run: entry.payroll_run, net: "4200.00")

      entry.adjust!(bonus: "500", one_time_deduction: "200", adjustment_note: "Loan recovery")

      expect(entry.reload).to have_attributes(bonus: BigDecimal("500"), one_time_deduction: BigDecimal("200"),
        adjustment_note: "Loan recovery", monthly_gross: BigDecimal("10000"), tax: BigDecimal("2100"), net: BigDecimal("7200"))
      expect(other.reload.net).to eq(BigDecimal("4200"))
    end

    it "allows a negative net" do
      entry.adjust!(one_time_deduction: "9000")

      expect(entry.reload.net).to eq(BigDecimal("-2000"))
    end

    it "refuses changes in a locked month" do
      create(:payroll_run, month: Date.new(2026, 11, 1))

      expect { entry.adjust!(bonus: "500") }.to raise_error(PayrollEntry::Locked, "October 2026 is locked.")
      expect(entry.reload.bonus).to eq(0)
    end

    it "raises a validation error for invalid amounts and keeps the old values" do
      expect { entry.adjust!(bonus: "-1") }.to raise_error(ActiveRecord::RecordInvalid)
      expect(entry.reload.bonus).to eq(0)
    end
  end
end
