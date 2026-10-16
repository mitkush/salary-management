FactoryBot.define do
  factory :user do
    sequence(:email_address) { |n| "hr#{n}@example.com" }
    password { "password" }
  end
end
