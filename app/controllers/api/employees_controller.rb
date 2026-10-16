module Api
  class EmployeesController < BaseController
    include EmployeeJson

    def index
      scope = Employee.includes(:country).search(params[:q]).with_status(params[:status])
      scope = scope.where(country_id: params[:country_id]) if params[:country_id].present?
      scope = scope.where(department: params[:department]) if params[:department].present?
      scope = scope.where(job_title: params[:job_title]) if params[:job_title].present?

      employees, meta = paginate(scope.order(:employee_code))
      current_gross = SalaryRevision.current_for(employees.map(&:id)).to_h { |r| [ r.employee_id, r.annual_gross ] }

      render json: { data: employees.map { |employee| employee_json(employee, current_gross[employee.id]) }, meta: meta }
    end

    def show
      employee = Employee.includes(:country).find(params[:id])
      revisions = employee.salary_revisions.order(effective_on: :desc)

      render json: {
        employee: employee_json(employee, employee.current_revision&.annual_gross),
        revisions: revisions.map { |revision| revision_json(revision) }
      }
    end
  end
end
