module Api
  module EmployeeJson
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

      def revision_json(revision)
        {
          id: revision.id,
          effective_on: revision.effective_on,
          annual_base: revision.annual_base,
          annual_allowances: revision.annual_allowances,
          annual_deductions: revision.annual_deductions,
          annual_gross: revision.annual_gross,
          reason: revision.reason,
          never_applies: revision.never_applies?
        }
      end
  end
end
