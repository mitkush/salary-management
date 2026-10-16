FactoryBot.define do
  factory :employee do
    sequence(:employee_code) { |n| format("EMP%05d", n) }
    sequence(:full_name) { |n| "Employee #{n}" }
    country
    department { "Engineering" }
    job_title { "Software Engineer" }
    bank_account_number { "123456781234" }
    joined_on { Date.new(2024, 1, 15) }
  end
end
