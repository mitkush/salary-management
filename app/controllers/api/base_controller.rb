module Api
  class BaseController < ApplicationController
    include Authentication

    rescue_from ActiveRecord::RecordNotFound do
      render_error :not_found, "Not found.", status: :not_found
    end

    rescue_from ActiveRecord::RecordInvalid do |exception|
      errors = exception.record.errors
      render_error :validation_failed, errors.full_messages.to_sentence, status: :unprocessable_content, details: errors.to_hash
    end

    rescue_from ActionController::ParameterMissing do
      render_error :bad_request, "Missing or invalid parameters.", status: :bad_request
    end

    rescue_from ActionController::InvalidAuthenticityToken do
      render_error :invalid_csrf_token, "Your session has expired. Please refresh the page.", status: :unprocessable_content
    end

    private
      def request_authentication
        render_error :unauthorized, "Please log in.", status: :unauthorized
      end

      MAX_PAGE = 1_000_000

      def paginate(scope, default_per_page: 25, max_per_page: 100)
        per_page = integer_param(:per_page, default_per_page).clamp(1, max_per_page)
        page = integer_param(:page, 1).clamp(1, MAX_PAGE)
        records = scope.limit(per_page).offset((page - 1) * per_page).to_a
        [ records, { page: page, per_page: per_page, total: scope.count } ]
      end

      def integer_param(name, default)
        value = params[name]
        value.is_a?(String) && value.match?(/\A\d+\z/) ? value.to_i : default
      end

      def render_error(code, message, status:, details: nil)
        render json: { error: { code: code, message: message, details: details }.compact }, status: status
      end
  end
end
