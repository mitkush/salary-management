module Api
  class BaseController < ApplicationController
    include Authentication

    rescue_from ActionController::InvalidAuthenticityToken do
      render_error :invalid_csrf_token, "Your session has expired. Please refresh the page.", status: :unprocessable_content
    end

    private
      def request_authentication
        render_error :unauthorized, "Please log in.", status: :unauthorized
      end

      def paginate(scope, default_per_page: 25, max_per_page: 100)
        per_page = params.fetch(:per_page, default_per_page).to_i.clamp(1, max_per_page)
        page = [ params[:page].to_i, 1 ].max
        records = scope.limit(per_page).offset((page - 1) * per_page).to_a
        [ records, { page: page, per_page: per_page, total: scope.count } ]
      end

      def render_error(code, message, status:)
        render json: { error: { code: code, message: message } }, status: status
      end
  end
end
