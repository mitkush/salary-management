class CreateEmployees < ActiveRecord::Migration[8.1]
  def change
    create_table :employees do |t|
      t.string :employee_code, null: false
      t.string :full_name, null: false
      t.references :country, null: false, foreign_key: true
      t.string :department, null: false
      t.string :job_title, null: false
      t.string :bank_account_number, null: false
      t.date :joined_on, null: false
      t.date :terminated_on

      t.timestamps
    end
    add_index :employees, :employee_code, unique: true
    add_index :employees, :department
    add_index :employees, :job_title
    add_index :employees, :joined_on
    add_index :employees, :terminated_on
    add_check_constraint :employees, "terminated_on >= joined_on", name: "employees_terminated_after_joined"
  end
end
