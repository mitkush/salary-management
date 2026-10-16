module Api
  class TerminationsController < BaseController
    include EmployeeJson

    def create
      employee = Employee.includes(:country).find(params[:employee_id])
      employee.terminate!(parse_date(params[:terminated_on]))

      render json: employee_json(employee, employee.current_revision&.annual_gross)
    end

    private
      def parse_date(value)
        Date.iso8601(value.to_s)
      rescue Date::Error
        nil
      end
  end
end
