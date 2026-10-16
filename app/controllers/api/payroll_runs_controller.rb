module Api
  class PayrollRunsController < BaseController
    include PayrollMonth

    def index
      latest = PayrollRun.latest_month
      counts = PayrollEntry.group(:payroll_run_id).count
      runs = PayrollRun.order(month: :desc)

      render json: runs.map { |run| run_json(run, latest_month: latest, entries_count: counts.fetch(run.id, 0)) }
    end

    def update
      run = Payroll::Generator.call(payroll_month(params[:month]))

      render json: run_json(run, latest_month: PayrollRun.latest_month, entries_count: run.entries.count)
    end

    def export
      run = find_run(params[:month])

      send_data Payroll::Exporter.new(run).to_xlsx,
        filename: "payroll-#{run.month.strftime('%Y-%m')}.xlsx",
        type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    end
  end
end
