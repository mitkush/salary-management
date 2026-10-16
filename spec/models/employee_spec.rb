require "rails_helper"

RSpec.describe Employee, type: :model do
  around { |example| travel_to(Date.new(2026, 10, 16)) { example.run } }

  it "is valid with the required fields" do
    expect(build(:employee)).to be_valid
  end

  it "requires every field except terminated_on" do
    employee = Employee.new

    expect(employee).not_to be_valid
    expect(employee.errors.attribute_names).to include(
      :employee_code, :full_name, :country, :department, :job_title, :bank_account_number, :joined_on
    )
  end

  it "rejects a duplicate employee code" do
    create(:employee, employee_code: "EMP00001")

    expect(build(:employee, employee_code: "EMP00001")).not_to be_valid
  end

  it "rejects terminated_on before joined_on in the database too" do
    employee = create(:employee, joined_on: Date.new(2026, 1, 10))

    expect { employee.update_column(:terminated_on, Date.new(2026, 1, 9)) }.to raise_error(ActiveRecord::StatementInvalid)
  end

  describe "#status" do
    it "is active from the day they join" do
      expect(build(:employee, joined_on: Date.new(2026, 10, 16)).status).to eq("active")
    end

    it "is upcoming when they join tomorrow" do
      expect(build(:employee, joined_on: Date.new(2026, 10, 17)).status).to eq("upcoming")
    end

    it "is still active on their last working day" do
      expect(build(:employee, terminated_on: Date.new(2026, 10, 16)).status).to eq("active")
    end

    it "is terminated from the day after their last working day" do
      expect(build(:employee, terminated_on: Date.new(2026, 10, 15)).status).to eq("terminated")
    end
  end

  describe ".with_status" do
    let!(:active) { create(:employee, joined_on: Date.new(2026, 10, 16), terminated_on: Date.new(2026, 10, 16)) }
    let!(:upcoming) { create(:employee, joined_on: Date.new(2026, 10, 17)) }
    let!(:terminated) { create(:employee, terminated_on: Date.new(2026, 10, 15)) }

    it "filters by the same rules as #status" do
      expect(Employee.with_status("active")).to contain_exactly(active)
      expect(Employee.with_status("upcoming")).to contain_exactly(upcoming)
      expect(Employee.with_status("terminated")).to contain_exactly(terminated)
    end
  end

  describe ".with_status on a given date" do
    let(:month_end) { Date.new(2026, 9, 30) }
    let!(:joins_on_month_end) { create(:employee, joined_on: month_end) }
    let!(:leaves_on_month_end) { create(:employee, joined_on: Date.new(2025, 1, 1), terminated_on: month_end) }
    let!(:left_day_before) { create(:employee, joined_on: Date.new(2025, 1, 1), terminated_on: month_end - 1) }
    let!(:joins_after) { create(:employee, joined_on: month_end + 1) }

    it "uses that date instead of today" do
      expect(Employee.with_status("active", on: month_end)).to contain_exactly(joins_on_month_end, leaves_on_month_end)
      expect(Employee.with_status("terminated", on: month_end)).to contain_exactly(left_day_before)
      expect(Employee.with_status("upcoming", on: month_end)).to contain_exactly(joins_after)
    end
  end

  describe "#masked_bank_account" do
    it "shows only the last 4 digits" do
      expect(build(:employee, bank_account_number: "123456789876").masked_bank_account).to eq("•••• 9876")
    end
  end

  describe "#terminate!" do
    let(:employee) { create(:employee, joined_on: Date.new(2026, 3, 1)) }

    it "sets the last working day" do
      employee.terminate!(Date.new(2026, 10, 31))

      expect(employee.reload.terminated_on).to eq(Date.new(2026, 10, 31))
    end

    it "allows the day they joined" do
      employee.terminate!(Date.new(2026, 3, 1))

      expect(employee.reload.terminated_on).to eq(Date.new(2026, 3, 1))
    end

    it "rejects a date before they joined" do
      expect { employee.terminate!(Date.new(2026, 2, 28)) }.to raise_error(ActiveRecord::RecordInvalid, /before the joining date/)
    end

    it "rejects a missing date" do
      expect { employee.terminate!(nil) }.to raise_error(ActiveRecord::RecordInvalid, /can't be blank/)
    end

    it "succeeds on a valid date after a failed attempt on the same record" do
      expect { employee.terminate!(nil) }.to raise_error(ActiveRecord::RecordInvalid)

      employee.terminate!(Date.new(2026, 10, 31))

      expect(employee.reload.terminated_on).to eq(Date.new(2026, 10, 31))
    end

    it "rejects a last working day in a locked payroll month, but allows the open month" do
      create(:payroll_run, month: Date.new(2026, 9, 1))
      create(:payroll_run, month: Date.new(2026, 10, 1))

      expect { employee.terminate!(Date.new(2026, 9, 30)) }.to raise_error(ActiveRecord::RecordInvalid, /falls in a locked payroll month/)
      employee.terminate!(Date.new(2026, 10, 1))
      expect(employee.reload.terminated_on).to eq(Date.new(2026, 10, 1))
    end

    it "rejects terminating someone who is already terminated" do
      employee.terminate!(Date.new(2026, 10, 31))

      expect { employee.terminate!(Date.new(2026, 11, 30)) }.to raise_error(ActiveRecord::RecordInvalid, /already terminated/)
      expect(employee.reload.terminated_on).to eq(Date.new(2026, 10, 31))
    end
  end
end
