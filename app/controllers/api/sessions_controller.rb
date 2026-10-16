module Api
  class SessionsController < BaseController
    allow_unauthenticated_access only: %i[show create]

    def show
      authenticated?
      render json: { authenticated: Current.user.present?, user: user_json(Current.user), csrf_token: form_authenticity_token }
    end

    def create
      if user = User.authenticate_by(email_address: params[:email_address].to_s, password: params[:password].to_s)
        reset_session
        start_new_session_for user
        render json: { user: user_json(user), csrf_token: form_authenticity_token }
      else
        render_error :invalid_credentials, "Invalid email or password.", status: :unauthorized
      end
    end

    def destroy
      terminate_session
      reset_session
      head :no_content
    end

    private
      def user_json(user)
        user && { id: user.id, email_address: user.email_address }
      end
  end
end
