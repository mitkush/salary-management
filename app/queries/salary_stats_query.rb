class SalaryStatsQuery
  GROUP_COLUMNS = { "country" => "countries.name", "department" => "employees.department" }.freeze

  AGGREGATES = {
    headcount: "COUNT(*)",
    total: "COALESCE(SUM(current.annual_gross), 0)",
    monthly_cost: "ROUND(COALESCE(SUM(current.annual_gross), 0) / 12, 2)",
    min: "MIN(current.annual_gross)",
    max: "MAX(current.annual_gross)",
    average: "ROUND(AVG(current.annual_gross), 2)",
    median: "ROUND((percentile_cont(0.5) WITHIN GROUP (ORDER BY current.annual_gross))::numeric, 2)"
  }.transform_values { |sql| Arel.sql(sql) }.freeze

  SHARE = Arel.sql("ROUND(100.0 * SUM(current.annual_gross) / NULLIF(SUM(SUM(current.annual_gross)) OVER (), 0), 2)")

  def initialize(country_id: nil, department: nil, job_title: nil, group_by: nil, as_of: Date.current)
    @as_of = as_of
    @filters = { country_id: country_id, department: department, job_title: job_title }.compact_blank
    @group_by = group_by
  end

  def summary
    AGGREGATES.keys.zip(current_gross.pick(*AGGREGATES.values)).to_h
  end

  def groups
    column = Arel.sql(GROUP_COLUMNS.fetch(@group_by) { raise ArgumentError, "unknown group_by: #{@group_by.inspect}" })

    current_gross
      .joins("JOIN employees ON employees.id = current.employee_id JOIN countries ON countries.id = employees.country_id")
      .group(column)
      .order(AGGREGATES[:total].desc, column)
      .pluck(column, SHARE, *AGGREGATES.values)
      .map { |name, share, *values| { name: name, share: share, **AGGREGATES.keys.zip(values).to_h } }
  end

  private
    def current_gross
      SalaryRevision.from(current_revisions, :current)
    end

    def current_revisions
      SalaryRevision.current_for(Employee.with_status("active", on: @as_of).where(@filters).select(:id), on: @as_of)
    end
end
