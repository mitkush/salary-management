class CreatePayrollRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :payroll_runs do |t|
      t.date :month, null: false
      t.datetime :generated_at, null: false

      t.timestamps
    end
    add_index :payroll_runs, :month, unique: true
    add_check_constraint :payroll_runs, "EXTRACT(DAY FROM month) = 1", name: "payroll_runs_month_first_day"
  end
end
