FactoryBot.define do
  factory :salary_revision do
    employee
    effective_on { employee.joined_on }
    annual_base { "60000.00" }
    annual_allowances { "6000.00" }
    annual_deductions { "2400.00" }
    reason { "initial" }
  end
end
