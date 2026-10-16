module Api
  class CountriesController < BaseController
    def index
      render json: Country.order(:name).map { |country| country_json(country) }
    end

    def update
      country = Country.find(params[:id])
      country.update!(params.expect(country: [ :tax_rate_percent ]))

      render json: country_json(country)
    end

    private
      def country_json(country)
        { id: country.id, code: country.code, name: country.name, tax_rate_percent: country.tax_rate_percent }
      end
  end
end
