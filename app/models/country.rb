class Country < ApplicationRecord
  validates :code, presence: true, length: { is: 2 }, uniqueness: true
  validates :name, presence: true, uniqueness: true
  validates :tax_rate, presence: true, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }
  validate :tax_rate_percent_valid

  def tax_rate_percent
    tax_rate && tax_rate * 100
  end

  def tax_rate_percent=(value)
    @tax_rate_percent_error = percent_error(value)
    self.tax_rate = BigDecimal(value.to_s) / 100 unless @tax_rate_percent_error
  end

  private
    def percent_error(value)
      return "can't be blank" if value.blank?

      percent = BigDecimal(value.to_s.strip)
      return "must be between 0 and 100" unless percent.between?(0, 100)

      "can have at most 2 decimals" unless (percent * 100).frac.zero?
    rescue ArgumentError
      "must be a number"
    end

    def tax_rate_percent_valid
      errors.add(:tax_rate_percent, @tax_rate_percent_error) if @tax_rate_percent_error
    end
end
