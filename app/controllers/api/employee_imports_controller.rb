module Api
  class EmployeeImportsController < BaseController
    rescue_from Employees::Importer::InvalidFile do |exception|
      render_error :invalid_file, exception.message, status: :unprocessable_content
    end

    def create
      file = params[:file]
      Employees::Importer.check_upload!(file)

      render json: Employees::Importer.new(file.path).call
    end

    def template
      send_data Employees::Importer.template,
        filename: "employee_import_template.xlsx",
        type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    end
  end
end
