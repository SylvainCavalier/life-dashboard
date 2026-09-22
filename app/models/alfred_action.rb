# Une ecriture proposee par Alfred. Le modele ne peut que la proposer : elle n'est
# executee (Alfred::ActionExecutor) qu'apres confirmation explicite dans le chat.
# == Schema Information
#
# Table name: alfred_actions
#
#  id                     :bigint           not null, primary key
#  error                  :text
#  operation              :string           not null
#  payload                :text             not null
#  resolved_at            :datetime
#  status                 :string           default("proposed"), not null
#  summary                :string
#  target_model           :string           not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  alfred_conversation_id :bigint           not null
#  alfred_message_id      :bigint
#  record_id              :bigint
#
# Indexes
#
#  index_alfred_actions_on_alfred_conversation_id  (alfred_conversation_id)
#  index_alfred_actions_on_alfred_message_id       (alfred_message_id)
#  index_alfred_actions_on_status                  (status)
#
# Foreign Keys
#
#  fk_rails_...  (alfred_conversation_id => alfred_conversations.id)
#  fk_rails_...  (alfred_message_id => alfred_messages.id)
#
class AlfredAction < ApplicationRecord
  # create / update : ecriture en base (DataAccess). send_email / draft_email /
  # triage_email : action Gmail (Alfred::MailActions), target_model "Gmail",
  # sans record_id.
  WRITE_OPERATIONS = %w[create update].freeze
  MAIL_OPERATIONS = %w[send_email draft_email triage_email].freeze
  OPERATIONS = (WRITE_OPERATIONS + MAIL_OPERATIONS).freeze
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
  def mail? = MAIL_OPERATIONS.include?(operation)
end
