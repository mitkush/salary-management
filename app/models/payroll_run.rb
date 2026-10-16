class PayrollRun < ApplicationRecord
  has_many :entries, class_name: "PayrollEntry", dependent: :restrict_with_exception

  validates :month, presence: true, uniqueness: true
  validates :generated_at, presence: true
  validate :month_is_first_day

  def self.latest_month
    maximum(:month)
  end

  def self.locked?(date)
    latest = latest_month
    latest.present? && date.beginning_of_month < latest
  end

  def outdated?
    SalaryRevision.where("created_at > ?", generated_at).where(effective_on: ..month.end_of_month).exists? ||
      Employee.where("updated_at > ?", generated_at).exists? ||
      Country.where("updated_at > ?", generated_at).exists?
  end

  def locked?
    self.class.locked?(month)
  end

  private
    def month_is_first_day
      errors.add(:month, "must be the first day of the month") if month && month.day != 1
    end
end
