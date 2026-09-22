# Un message d'une conversation avec Alfred. `event` est une note systeme visible
# (ecriture confirmee ou annulee) que le modele relit au tour suivant.
# La table fait foi pour l'etat d'une reponse en cours : l'interface la sonde.
class AlfredMessage < ApplicationRecord
  ROLES = %w[user assistant event].freeze
  STATUSES = %w[pending processing done failed].freeze
  # Au-dela, la reponse est consideree comme perdue (process redemarre pendant le job).
  STUCK_AFTER = 5.minutes

  belongs_to :conversation, class_name: "AlfredConversation", foreign_key: :alfred_conversation_id,
                            inverse_of: :messages
  has_many :actions, class_name: "AlfredAction", dependent: :nullify

  # Une reponse peut citer un IBAN ou un numero de passeport : pas de clair en base.
  encrypts :content

  validates :role, inclusion: { in: ROLES }
  validates :status, inclusion: { in: STATUSES }

  def in_progress?
    %w[pending processing].include?(status)
  end

  def stuck?
    in_progress? && updated_at < STUCK_AFTER.ago
  end
end
