FactoryBot.define do
  factory :payroll_run do
    month { Date.new(2026, 9, 1) }
    generated_at { Time.current }
  end

  factory :payroll_entry do
    payroll_run
    employee
    salary_revision { association :salary_revision, employee: employee }
    days_worked { 30 }
    monthly_gross { "5500.00" }
    monthly_deductions { "200.00" }
    tax_rate { "0.2000" }
    tax { "1100.00" }
    net { "4200.00" }
  end
end
