class ApplicationController < ActionController::Base
  # Include Pundit for authorization
  include Pundit::Authorization

  # Include Pagy for pagination (v43+)
  include Pagy::Method

  # Protect from forgery with exception
  protect_from_forgery with: :exception

  # Single-user app: EVERYTHING is private by default. Controllers that must
  # stay reachable without a session (public share links) opt out explicitly
  # with `skip_before_action :authenticate_user!`.
  before_action :authenticate_user!
  before_action :enforce_password_change!

  # Rescue from Pundit authorization errors
  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  # Le compte est cree avec un mot de passe de bootstrap connu. Tant qu'il n'a
  # pas ete remplace, l'application entiere est bloquee sur le formulaire de
  # changement : ce mot de passe ne peut donc servir qu'une seule fois, et ne
  # peut pas rester en place sur un hote public.
  def enforce_password_change!
    return unless current_user&.must_change_password?

    if request.format.json?
      render json: {
        error: "Changement de mot de passe requis avant toute autre action.",
        redirect: account_password_path
      }, status: :forbidden
    else
      redirect_to account_password_path,
        alert: "Choisis un nouveau mot de passe avant d'aller plus loin."
    end
  end

  def user_not_authorized
    flash[:alert] = "You are not authorized to perform this action."
    redirect_back(fallback_location: root_path)
  end
end
