module Users
  # Changement du mot de passe par le proprietaire lui-meme, une fois connecte.
  # Le compte est cree avec un mot de passe de bootstrap connu (voir
  # User.bootstrap!) : tant qu'il n'a pas ete remplace ici, toute l'application
  # redirige vers cette page.
  #
  # C'est volontairement une page ERB et non un ecran du SPA : un mot de passe
  # n'a pas a transiter par axios ni a exister dans l'etat du client.
  class PasswordChangesController < ApplicationController
    # Sans cette exception, le garde-fou de ApplicationController renverrait
    # cette page vers elle-meme indefiniment.
    skip_before_action :enforce_password_change!

    layout "auth"

    def edit
      @user = current_user
      @forced = @user.must_change_password?
    end

    def update
      @user = current_user
      @forced = @user.must_change_password?

      # update_with_password exige le mot de passe actuel : une session laissee
      # ouverte sur une machine ne suffit pas a s'approprier le compte.
      if @user.update_with_password(password_params)
        @user.update_column(:must_change_password, false) if @forced
        # Le changement de mot de passe invalide la session : on la rouvre pour
        # ne pas ejecter l'utilisateur juste apres une operation reussie.
        bypass_sign_in(@user)
        redirect_to root_path, notice: "Mot de passe mis a jour."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def password_params
      params.require(:user).permit(:current_password, :password, :password_confirmation)
    end
  end
end
