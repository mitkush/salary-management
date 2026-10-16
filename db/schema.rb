# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_16_174714) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "countries", force: :cascade do |t|
    t.string "code", limit: 2, null: false
    t.string "name", null: false
    t.decimal "tax_rate", precision: 5, scale: 4, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_countries_on_code", unique: true
    t.index ["name"], name: "index_countries_on_name", unique: true
    t.check_constraint "tax_rate >= 0::numeric AND tax_rate <= 1::numeric", name: "countries_tax_rate_range"
  end

  create_table "employees", force: :cascade do |t|
    t.string "employee_code", null: false
    t.string "full_name", null: false
    t.bigint "country_id", null: false
    t.string "department", null: false
    t.string "job_title", null: false
    t.string "bank_account_number", null: false
    t.date "joined_on", null: false
    t.date "terminated_on"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["country_id"], name: "index_employees_on_country_id"
    t.index ["department"], name: "index_employees_on_department"
    t.index ["employee_code"], name: "index_employees_on_employee_code", unique: true
    t.index ["job_title"], name: "index_employees_on_job_title"
    t.index ["joined_on"], name: "index_employees_on_joined_on"
    t.index ["terminated_on"], name: "index_employees_on_terminated_on"
    t.check_constraint "terminated_on >= joined_on", name: "employees_terminated_after_joined"
  end

  create_table "payroll_entries", force: :cascade do |t|
    t.bigint "payroll_run_id", null: false
    t.bigint "employee_id", null: false
    t.bigint "salary_revision_id", null: false
    t.integer "days_worked", null: false
    t.decimal "monthly_gross", precision: 12, scale: 2, null: false
    t.decimal "monthly_deductions", precision: 12, scale: 2, null: false
    t.decimal "bonus", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "one_time_deduction", precision: 12, scale: 2, default: "0.0", null: false
    t.string "adjustment_note"
    t.decimal "tax_rate", precision: 5, scale: 4, null: false
    t.decimal "tax", precision: 12, scale: 2, null: false
    t.decimal "net", precision: 12, scale: 2, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["employee_id"], name: "index_payroll_entries_on_employee_id"
    t.index ["payroll_run_id", "employee_id"], name: "index_payroll_entries_on_payroll_run_id_and_employee_id", unique: true
    t.index ["salary_revision_id"], name: "index_payroll_entries_on_salary_revision_id"
    t.check_constraint "bonus >= 0::numeric AND one_time_deduction >= 0::numeric", name: "payroll_entries_adjustments_not_negative"
    t.check_constraint "days_worked >= 1 AND days_worked <= 31", name: "payroll_entries_days_worked_range"
  end

  create_table "payroll_runs", force: :cascade do |t|
    t.date "month", null: false
    t.datetime "generated_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["month"], name: "index_payroll_runs_on_month", unique: true
    t.check_constraint "EXTRACT(day FROM month) = 1::numeric", name: "payroll_runs_month_first_day"
  end

  create_table "salary_revisions", force: :cascade do |t|
    t.bigint "employee_id", null: false
    t.date "effective_on", null: false
    t.decimal "annual_base", precision: 12, scale: 2, null: false
    t.decimal "annual_allowances", precision: 12, scale: 2, null: false
    t.decimal "annual_deductions", precision: 12, scale: 2, null: false
    t.virtual "annual_gross", type: :decimal, precision: 12, scale: 2, as: "(annual_base + annual_allowances)", stored: true
    t.string "reason", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["employee_id", "effective_on"], name: "index_salary_revisions_on_employee_id_and_effective_on", unique: true
    t.check_constraint "annual_base >= 0::numeric AND annual_allowances >= 0::numeric AND annual_deductions >= 0::numeric", name: "salary_revisions_amounts_not_negative"
    t.check_constraint "reason::text = ANY (ARRAY['initial'::character varying::text, 'increment'::character varying::text, 'promotion'::character varying::text, 'correction'::character varying::text, 'other'::character varying::text])", name: "salary_revisions_reason_allowed"
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "employees", "countries"
  add_foreign_key "payroll_entries", "employees"
  add_foreign_key "payroll_entries", "payroll_runs"
  add_foreign_key "payroll_entries", "salary_revisions"
  add_foreign_key "salary_revisions", "employees"
  add_foreign_key "sessions", "users"
end
