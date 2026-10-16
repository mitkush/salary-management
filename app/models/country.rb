class Country < ApplicationRecord
  validates :code, presence: true, length: { is: 2 }, uniqueness: true
  validates :name, presence: true, uniqueness: true
  validates :tax_rate, presence: true, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }
end
