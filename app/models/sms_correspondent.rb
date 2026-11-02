# Un numero autorise a echanger des textos avec Alfred (liste blanche) : un SMS venu d'un
# autre numero est ignore, sans reponse ni appel au modele. `owner` marque le numero de
# Sylvain, qui n'obtient pas plus de droits : un numero d'expediteur peut etre usurpe.

# == Schema Information
#
# Table name: sms_correspondents
#
#  id         :bigint           not null, primary key
#  enabled    :boolean          default(TRUE), not null
#  name       :string           not null
#  owner      :boolean          default(FALSE), not null
#  phone      :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  contact_id :bigint
#
# Indexes
#
#  index_sms_correspondents_on_contact_id  (contact_id)
#  index_sms_correspondents_on_phone       (phone) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (contact_id => contacts.id) ON DELETE => nullify
#
class SmsCorrespondent < ApplicationRecord
  PHONE_FORMAT = /\A\+[1-9]\d{7,14}\z/

  belongs_to :contact, optional: true
  has_many :messages, class_name: "SmsMessage", dependent: :destroy, inverse_of: :correspondent
  has_many :conversations, class_name: "AlfredConversation", dependent: :nullify, inverse_of: :sms_correspondent

  normalizes :name, with: ->(value) { value.squish }
  normalizes :phone, with: ->(value) { SmsCorrespondent.normalize_phone(value) }

  validates :name, presence: true
  validates :phone, presence: true, uniqueness: true,
                    format: { with: PHONE_FORMAT, message: "doit etre un numero valide (06 12 34 56 78 ou +33612345678)" }

  scope :ordered, -> { order(owner: :desc, name: :asc) }

  # E.164, France par defaut : « 06 12 34 56 78 », « 0033 6... », « +33 6... ».
  def self.normalize_phone(value)
    digits = value.to_s.gsub(/[\s.\-()]/, "")
    case digits
    when /\A00(\d+)\z/ then "+#{Regexp.last_match(1)}"
    when /\A0(\d{9})\z/ then "+33#{Regexp.last_match(1)}"
    else digits
    end
  end

  def self.for_phone(value)
    find_by(phone: normalize_phone(value))
  end

  # Consigne le texto puis l'envoie. L'echec est note sur le message et releve.
  def send_text!(body)
    message = messages.create!(direction: "outbound", status: "sending", body: body.to_s.strip.truncate(SmsMessage::MAX_LENGTH))
    begin
      sid = TwilioSms.send_message(to: phone, body: message.body)
      message.update!(status: "sent", twilio_sid: sid)
    rescue TwilioSms::Error => e
      message.update!(status: "failed", error: e.message.truncate(500))
      raise
    end
    message
  end
end
