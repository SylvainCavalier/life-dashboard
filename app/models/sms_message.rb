# Un texto echange avec Alfred. Entrant : received -> processing -> answered | merged
# (repris par la reponse au texto suivant) | limited (plafond du jour) | failed.
# Sortant : sending -> sent | failed.

# == Schema Information
#
# Table name: sms_messages
#
#  id                   :bigint           not null, primary key
#  body                 :text             not null
#  direction            :string           not null
#  error                :text
#  status               :string           not null
#  twilio_sid           :string
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  sms_correspondent_id :bigint           not null
#
# Indexes
#
#  index_sms_messages_on_sms_correspondent_id                 (sms_correspondent_id)
#  index_sms_messages_on_sms_correspondent_id_and_created_at  (sms_correspondent_id,created_at)
#  index_sms_messages_on_twilio_sid                           (twilio_sid) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (sms_correspondent_id => sms_correspondents.id) ON DELETE => cascade
#
class SmsMessage < ApplicationRecord
  DIRECTIONS = %w[inbound outbound].freeze
  # Un SMS accentue tient sur 70 caracteres : 640 caracteres font jusqu'a 10 segments factures.
  MAX_LENGTH = 640
  MAX_INBOUND_LENGTH = 1600

  belongs_to :correspondent, class_name: "SmsCorrespondent", foreign_key: :sms_correspondent_id, inverse_of: :messages

  encrypts :body

  validates :direction, inclusion: { in: DIRECTIONS }
  validates :body, presence: true
  validates :status, presence: true

  scope :inbound, -> { where(direction: "inbound") }
  scope :chronological, -> { order(:id) }

  def inbound? = direction == "inbound"
end
