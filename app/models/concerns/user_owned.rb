# Enregistrement des outils ouverts aux amis (Downloader, Transfert, outil Videos) :
# il appartient a un compte, et les controleurs ne lisent que ceux de current_user.
# Cree hors session (rake task, Alfred, skill locale), il revient au proprietaire.
module UserOwned
  extend ActiveSupport::Concern

  included do
    belongs_to :user

    before_validation :assign_owner, on: :create
  end

  private

  def assign_owner
    self.user ||= User.owner
  end
end
