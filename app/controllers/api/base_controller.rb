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

      def render_error(code, message, status:)
        render json: { error: { code: code, message: message } }, status: status
      end
  end
end
