# Pages publiques de telechargement : accessibles sans authentification,
# uniquement via le token aleatoire du lien de partage.
class TransfersController < ApplicationController
  # Renseigne ActiveStorage::Current.url_options : necessaire pour generer l'URL
  # du blob quel que soit le service de stockage (S3 en prod, Disk en test).
  include ActiveStorage::SetCurrent

  # Seul point d'entree public de l'application : le token du lien fait foi.
  skip_before_action :authenticate_user!

  layout "transfer"

  before_action :set_transfer

  # GET /t/:token
  def show
    return render :expired, status: :gone if @transfer.nil? || @transfer.expired?
  end

  # GET /t/:token/download
  def download
    return render :expired, status: :gone if @transfer.nil? || @transfer.expired?

    @transfer.register_download!
    redirect_to @transfer.download_url, allow_other_host: true
  end

  private

  def set_transfer
    @transfer = FileTransfer.with_attached_file.find_by(token: params[:token])
  end
end
