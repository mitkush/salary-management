module Api
  module PayrollMonth
    extend ActiveSupport::Concern

    class InvalidMonth < StandardError; end

    included do
      rescue_from InvalidMonth do
        render_error :bad_request, "Month must look like 2026-10.", status: :bad_request
      end

      rescue_from Payroll::Generator::NotAllowed, PayrollEntry::Locked do |exception|
        render_error :conflict, exception.message, status: :conflict
      end
    end

    private
      def payroll_month(value)
        raise InvalidMonth unless value.to_s.match?(/\A\d{4}-(0[1-9]|1[0-2])\z/)

        Date.strptime(value, "%Y-%m")
      end

      def find_run(value)
        PayrollRun.find_by!(month: payroll_month(value))
      end

      def run_json(run, latest_month:, entries_count:)
        {
          month: run.month.strftime("%Y-%m"),
          generated_at: run.generated_at,
          entries_count: entries_count,
          locked: run.month < latest_month,
          outdated: run.month == latest_month && run.outdated?
        }
      end
  end
end
