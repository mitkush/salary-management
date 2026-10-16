module Api
  class FilterOptionsController < BaseController
    def show
      render json: {
        countries: Country.order(:name).map { |country| { id: country.id, code: country.code, name: country.name } },
        departments: Employee.distinct.order(:department).pluck(:department),
        job_titles: Employee.distinct.order(:job_title).pluck(:job_title)
      }
    end
  end
end
