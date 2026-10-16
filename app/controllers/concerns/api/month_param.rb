module Api
  module MonthParam
    extend ActiveSupport::Concern

    class InvalidMonth < StandardError; end

    included do
      rescue_from InvalidMonth do
        render_error :bad_request, "Month must look like 2026-10.", status: :bad_request
      end
    end

    private
      def month_param(value)
        raise InvalidMonth unless value.to_s.match?(/\A\d{4}-(0[1-9]|1[0-2])\z/)

        Date.strptime(value, "%Y-%m")
      end
  end
end
