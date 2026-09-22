# Une ecriture proposee par Alfred. Le modele ne peut que la proposer : elle n'est
# executee (Alfred::ActionExecutor) qu'apres confirmation explicite dans le chat.
class AlfredAction < ApplicationRecord
  OPERATIONS = %w[create update].freeze
  STATUSES = %w[proposed executed cancelled failed].freeze

  belongs_to :conversation, class_name: "AlfredConversation", foreign_key: :alfred_conversation_id,
                            inverse_of: :actions
  belongs_to :message, class_name: "AlfredMessage", foreign_key: :alfred_message_id, optional: true,
                       inverse_of: :actions

  # { "attributes" => {...}, "before" => {...} } : peut contenir des champs sensibles.
  encrypts :payload

  validates :operation, inclusion: { in: OPERATIONS }
  validates :status, inclusion: { in: STATUSES }
  validates :target_model, presence: true

  def data
    @data ||= JSON.parse(payload)
  end

  def new_attributes = data.fetch("attributes", {})
  def before_attributes = data.fetch("before", {})

  def proposed? = status == "proposed"
end
