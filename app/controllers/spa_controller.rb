class SpaController < ApplicationController
  # Le bundle est le meme pour tous. Un ami est renvoye vers les outils des qu'il
  # demande une autre page (le routeur Vue fait de meme pour la navigation interne),
  # et l'API refuse de toute facon tout le reste.
  open_to_friends
  before_action :keep_friend_on_open_pages

  # Pages ouvertes aux amis : a tenir aligne avec FRIEND_ROUTES (utils/currentUser.js).
  FRIEND_PATHS = %r{\A/(tools|downloader|transfer)(/|\z)}

  def index
  end

  private

  def keep_friend_on_open_pages
    redirect_to FRIEND_HOME_PATH if current_user&.friend? && !request.path.match?(FRIEND_PATHS)
  end
end
