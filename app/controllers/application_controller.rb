class ApplicationController < ActionController::Base
  # Include Pundit for authorization
  include Pundit::Authorization

  # Include Pagy for pagination (v43+)
  include Pagy::Method
  
  # Protect from forgery with exception
  protect_from_forgery with: :exception
  
  # Rescue from Pundit authorization errors
  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
  
  # Uncomment when you have devise installed and configured
  # before_action :authenticate_user!
  # before_action :configure_permitted_parameters, if: :devise_controller?
  
  # Helper method to check if Devise is available
  def devise_available?
    defined?(Devise) && respond_to?(:devise_controller?)
  end
  
  private
  
  def user_not_authorized
    flash[:alert] = "You are not authorized to perform this action."
    redirect_back(fallback_location: root_path)
  end
  
  # Uncomment and customize when using Devise
  # def configure_permitted_parameters
  #   devise_parameter_sanitizer.permit(:sign_up, keys: [:email, :password, :password_confirmation])
  #   devise_parameter_sanitizer.permit(:sign_in, keys: [:email, :password, :remember_me])
  #   devise_parameter_sanitizer.permit(:account_update, keys: [:email, :password, :password_confirmation, :current_password])
  # end
end
