module Api
  class EmployeesController < BaseController
    def index
      scope = Employee.includes(:country).search(params[:q]).with_status(params[:status])
      scope = scope.where(country_id: params[:country_id]) if params[:country_id].present?
      scope = scope.where(department: params[:department]) if params[:department].present?
      scope = scope.where(job_title: params[:job_title]) if params[:job_title].present?

      employees, meta = paginate(scope.order(:employee_code))
      current_gross = SalaryRevision.current_for(employees.map(&:id)).to_h { |r| [ r.employee_id, r.annual_gross ] }

      render json: { data: employees.map { |employee| employee_json(employee, current_gross[employee.id]) }, meta: meta }
    end

    private
      def employee_json(employee, current_annual_gross)
        {
          id: employee.id,
          employee_code: employee.employee_code,
          full_name: employee.full_name,
          country: { id: employee.country.id, code: employee.country.code, name: employee.country.name },
          department: employee.department,
          job_title: employee.job_title,
          status: employee.status,
          bank_account: employee.masked_bank_account,
          joined_on: employee.joined_on,
          terminated_on: employee.terminated_on,
          current_annual_gross: current_annual_gross
        }
      end
  end
end
