module Api
  class BaseController < ApplicationController
    include Authentication

    private
      def request_authentication
        render_error :unauthorized, "Please log in.", status: :unauthorized
      end

      def render_error(code, message, status:)
        render json: { error: { code: code, message: message } }, status: status
      end
  end
end
