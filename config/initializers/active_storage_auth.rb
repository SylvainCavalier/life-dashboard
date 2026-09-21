# Les controleurs Active Storage heritent d'ActiveStorage::BaseController, pas
# d'ApplicationController : le `before_action :authenticate_user!` global ne
# s'y applique pas.
#
# La LECTURE doit rester ouverte : les liens de partage publics /t/:token
# redirigent vers une URL de blob signee, et le token du lien fait office de
# secret.
#
# L'ECRITURE, elle, ne doit jamais etre accessible sans session : sans ce
# garde-fou, n'importe qui peut appeler /rails/active_storage/direct_uploads et
# faire grossir le bucket OVH a nos frais.
Rails.application.config.to_prepare do
  ActiveStorage::DirectUploadsController.class_eval do
    before_action :require_dashboard_session!

    private

    def require_dashboard_session!
      head :unauthorized unless warden&.authenticate(scope: :user)
    end

    def warden
      request.env["warden"]
    end
  end
end
