module Users
  # La page de connexion est volontairement une page ERB autonome : elle ne
  # charge pas le bundle Vue. Un visiteur non authentifie (ou un crawler) ne
  # recoit donc jamais le moindre octet de l'application elle-meme.
  class SessionsController < Devise::SessionsController
    # Sans cette exception, le blocage sur le changement de mot de passe
    # intercepterait aussi la deconnexion : impossible de quitter l'ecran.
    skip_before_action :enforce_password_change!

    layout "auth"
  end
end
