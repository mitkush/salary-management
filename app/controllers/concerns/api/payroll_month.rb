module Api
  module PayrollMonth
    extend ActiveSupport::Concern
    include MonthParam

    included do
      rescue_from Payroll::Generator::NotAllowed, PayrollEntry::Locked do |exception|
        render_error :conflict, exception.message, status: :conflict
      end
    end

    private
      def find_run(value)
        PayrollRun.find_by!(month: month_param(value))
      end

      def run_summaries(runs)
        PayrollEntry.where(payroll_run: runs).group(:payroll_run_id)
          .pluck(:payroll_run_id, Arel.sql("COUNT(*)"), Arel.sql("SUM(monthly_gross)"), Arel.sql("SUM(tax)"), Arel.sql("SUM(net)"))
          .to_h { |id, count, gross, tax, net| [ id, { entries_count: count, totals: { gross: gross, tax: tax, net: net } } ] }
      end

      def run_json(run, latest_month:, summary:)
        summary ||= { entries_count: 0, totals: { gross: 0, tax: 0, net: 0 } }
        {
          month: run.month.strftime("%Y-%m"),
          generated_at: run.generated_at,
          **summary,
          locked: run.month < latest_month,
          outdated: run.month == latest_month && run.outdated?
        }
      end
  end
end
