class SalaryTrendsQuery
  MONTHS = 12

  def initialize(as_of_month:, country_id: nil, department: nil, job_title: nil)
    @filters = { country_id: country_id, department: department, job_title: job_title }.compact_blank
    @starts = (0...MONTHS).map { |i| as_of_month.beginning_of_month << (MONTHS - 1 - i) }
  end

  def months
    joiners = counts_by_month(:joined_on)
    leavers = counts_by_month(:terminated_on)

    @starts.map do |start|
      label = start.strftime("%Y-%m")
      monthly_cost = SalaryStatsQuery.new(**@filters, as_of: point_in(start)).summary[:monthly_cost]
      { month: label, monthly_cost: monthly_cost, joiners: joiners.fetch(label, 0), leavers: leavers.fetch(label, 0) }
    end
  end

  private
    def point_in(start)
      [ start.end_of_month, Date.current ].min
    end

    def counts_by_month(column)
      Employee.where(@filters).where(column => @starts.first..point_in(@starts.last))
        .group(Arel.sql("to_char(#{column}, 'YYYY-MM')")).count
    end
end
