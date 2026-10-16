require "rails_helper"

RSpec.describe Payroll::Generator do
  around { |example| travel_to(Time.zone.local(2026, 10, 16, 12)) { example.run } }

  let(:india) { create(:country, code: "IN", name: "India", tax_rate: "0.2000") }
  let(:october) { Date.new(2026, 10, 1) }

  def employee(joined_on: Date.new(2025, 1, 1), terminated_on: nil, base: "120000.00")
    create(:employee, country: india, joined_on: joined_on, terminated_on: terminated_on).tap do |e|
      create(:salary_revision, employee: e, effective_on: joined_on, annual_base: base, annual_allowances: "0.00",
        annual_deductions: "12000.00")
    end
  end

  def generate(month)
    described_class.call(month)
  end

  def entry_for(run, person)
    run.entries.find_by!(employee: person)
  end

  describe "month rules" do
    it "allows the first run for any month up to the current one" do
      person = employee

      run = generate(Date.new(2026, 3, 1))

      expect(run).to have_attributes(month: Date.new(2026, 3, 1), generated_at: Time.current)
      expect(run.entries.map(&:employee)).to eq([ person ])
    end

    it "rejects a future month" do
      expect { generate(Date.new(2026, 11, 1)) }.to raise_error(described_class::NotAllowed, "Payroll can't be generated for a future month.")
    end

    it "allows the month right after the latest run" do
      generate(Date.new(2026, 9, 1))

      expect { generate(october) }.to change(PayrollRun, :count).by(1)
    end

    it "rejects skipping a month" do
      generate(Date.new(2026, 8, 1))

      expect { generate(october) }.to raise_error(described_class::NotAllowed, "The next payroll must be for September 2026.")
    end

    it "rejects a locked month" do
      generate(Date.new(2026, 8, 1))
      generate(Date.new(2026, 9, 1))

      expect { generate(Date.new(2026, 8, 1)) }.to raise_error(described_class::NotAllowed, "August 2026 is locked.")
    end

    it "creates an empty run for a month with no eligible employees" do
      expect(generate(Date.new(2000, 1, 1)).entries).to be_empty
    end
  end

  describe "who is paid and how much" do
    it "includes everyone who worked at least one day of the month" do
      full = employee
      joins_on_last_day = employee(joined_on: Date.new(2026, 10, 31))
      leaves_on_first = employee(terminated_on: Date.new(2026, 10, 1))
      employee(joined_on: Date.new(2026, 11, 1))
      employee(terminated_on: Date.new(2026, 9, 30))

      run = generate(october)

      expect(run.entries.map(&:employee)).to contain_exactly(full, joins_on_last_day, leaves_on_first)
      expect(entry_for(run, joins_on_last_day).days_worked).to eq(1)
      expect(entry_for(run, leaves_on_first).days_worked).to eq(1)
    end

    it "stores the prorated amounts, tax rate, tax and net" do
      person = employee(joined_on: Date.new(2026, 10, 15))

      entry = entry_for(generate(october), person)

      expect(entry).to have_attributes(
        salary_revision: person.salary_revisions.first, days_worked: 17, monthly_gross: BigDecimal("5483.87"),
        monthly_deductions: BigDecimal("548.39"), tax_rate: BigDecimal("0.2"), tax: BigDecimal("1096.77"),
        net: BigDecimal("3838.71"), bonus: 0, one_time_deduction: 0
      )
    end

    it "uses the revision in effect on the month end, or on the last day worked for a leaver" do
      stayer = employee
      raise_on_20th = create(:salary_revision, employee: stayer, effective_on: Date.new(2026, 10, 20), annual_base: "240000.00",
        annual_allowances: "0.00", reason: "increment")
      leaver = employee
      create(:salary_revision, employee: leaver, effective_on: Date.new(2026, 10, 20), annual_base: "240000.00",
        annual_allowances: "0.00", reason: "increment")
      leaver.terminate!(Date.new(2026, 10, 10))

      run = generate(october)

      expect(entry_for(run, stayer).salary_revision).to eq(raise_on_20th)
      expect(entry_for(run, leaver).salary_revision).to eq(leaver.salary_revisions.find_by(reason: "initial"))
    end

    it "keeps a locked month's tax rate when the country's rate changes later" do
      person = employee
      september = generate(Date.new(2026, 9, 1))
      india.update!(tax_rate_percent: "30")

      october_run = generate(october)

      expect(entry_for(september, person).tax_rate).to eq(BigDecimal("0.2"))
      expect(entry_for(october_run, person).tax_rate).to eq(BigDecimal("0.3"))
    end
  end

  describe "recalculating the open month" do
    it "refreshes the calculated amounts but keeps HR's bonus, deduction and note" do
      person = employee
      run = generate(october)
      entry_for(run, person).update!(bonus: "1000.00", one_time_deduction: "300.00", adjustment_note: "Loan recovery")
      create(:salary_revision, employee: person, effective_on: Date.new(2026, 10, 5), annual_base: "240000.00",
        annual_allowances: "0.00", annual_deductions: "12000.00", reason: "promotion")

      generate(october)

      expect(entry_for(run, person).reload).to have_attributes(
        monthly_gross: BigDecimal("20000"), bonus: BigDecimal("1000"), one_time_deduction: BigDecimal("300"),
        adjustment_note: "Loan recovery", tax: BigDecimal("4200"), net: BigDecimal("15500")
      )
    end

    it "adds newly eligible employees and updates generated_at" do
      employee
      run = generate(october)

      travel 1.hour
      newcomer = employee(joined_on: Date.new(2026, 10, 12))
      generate(october)

      expect(run.reload.entries.map(&:employee)).to include(newcomer)
      expect(run.generated_at).to eq(Time.current)
      expect(PayrollRun.count).to eq(1)
    end
  end
end
