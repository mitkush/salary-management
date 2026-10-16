module Api
  class SessionsController < BaseController
    allow_unauthenticated_access only: %i[create]

    def create
      if user = User.authenticate_by(email_address: params[:email_address].to_s, password: params[:password].to_s)
        start_new_session_for user
        render json: { user: user_json(user), csrf_token: form_authenticity_token }
      else
        render_error :invalid_credentials, "Invalid email or password.", status: :unauthorized
      end
    end

    private
      def user_json(user)
        user && { id: user.id, email_address: user.email_address }
      end
  end
end
