class CreatePayrollEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :payroll_entries do |t|
      t.references :payroll_run, null: false, foreign_key: true, index: false
      t.references :employee, null: false, foreign_key: true
      t.references :salary_revision, null: false, foreign_key: true
      t.integer :days_worked, null: false
      t.decimal :monthly_gross, null: false, precision: 12, scale: 2
      t.decimal :monthly_deductions, null: false, precision: 12, scale: 2
      t.decimal :bonus, null: false, precision: 12, scale: 2, default: 0
      t.decimal :one_time_deduction, null: false, precision: 12, scale: 2, default: 0
      t.string :adjustment_note
      t.decimal :tax_rate, null: false, precision: 5, scale: 4
      t.decimal :tax, null: false, precision: 12, scale: 2
      t.decimal :net, null: false, precision: 12, scale: 2

      t.timestamps
    end
    add_index :payroll_entries, [ :payroll_run_id, :employee_id ], unique: true
    add_check_constraint :payroll_entries, "days_worked BETWEEN 1 AND 31", name: "payroll_entries_days_worked_range"
    add_check_constraint :payroll_entries, "bonus >= 0 AND one_time_deduction >= 0", name: "payroll_entries_adjustments_not_negative"
  end
end
