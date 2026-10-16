class CreateSalaryRevisions < ActiveRecord::Migration[8.1]
  def change
    create_table :salary_revisions do |t|
      t.references :employee, null: false, foreign_key: true, index: false
      t.date :effective_on, null: false
      t.decimal :annual_base, null: false, precision: 12, scale: 2
      t.decimal :annual_allowances, null: false, precision: 12, scale: 2
      t.decimal :annual_deductions, null: false, precision: 12, scale: 2
      t.virtual :annual_gross, type: :decimal, precision: 12, scale: 2, as: "annual_base + annual_allowances", stored: true
      t.string :reason, null: false

      t.timestamps
    end
    add_index :salary_revisions, [ :employee_id, :effective_on ], unique: true
    add_check_constraint :salary_revisions, "annual_base >= 0 AND annual_allowances >= 0 AND annual_deductions >= 0",
      name: "salary_revisions_amounts_not_negative"
    add_check_constraint :salary_revisions, "reason IN ('initial', 'increment', 'promotion', 'correction', 'other')",
      name: "salary_revisions_reason_allowed"
  end
end
