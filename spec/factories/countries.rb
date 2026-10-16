FactoryBot.define do
  factory :country do
    sequence(:code) { |n| (("AA".."ZZ").to_a)[n] }
    sequence(:name) { |n| "Country #{n}" }
    tax_rate { "0.2000" }
  end
end
