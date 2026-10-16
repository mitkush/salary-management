module Api
  class SalaryRevisionsController < BaseController
    include EmployeeJson

    def create
      employee = Employee.find(params[:employee_id])
      revision = employee.salary_revisions.create!(revision_params)

      render json: revision_json(revision), status: :created
    end

    private
      def revision_params
        params.expect(salary_revision: %i[effective_on annual_base annual_allowances annual_deductions reason])
      end
  end
end
