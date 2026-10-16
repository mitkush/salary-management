module Api
  class PayrollRunsController < BaseController
    include PayrollMonth

    def index
      latest = PayrollRun.latest_month
      runs = PayrollRun.order(month: :desc).to_a
      summaries = run_summaries(runs)

      render json: runs.map { |run| run_json(run, latest_month: latest, summary: summaries[run.id]) }
    end

    def update
      run = Payroll::Generator.call(month_param(params[:month]))

      render json: run_json(run, latest_month: PayrollRun.latest_month, summary: run_summaries([ run ])[run.id])
    end

    def export
      run = find_run(params[:month])

      send_data Payroll::Exporter.new(run).to_xlsx,
        filename: "payroll-#{run.month.strftime('%Y-%m')}.xlsx",
        type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    end
  end
end
