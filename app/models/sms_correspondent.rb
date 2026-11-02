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
  # Ce qu'Alfred sait de la personne, tire de sa fiche : la nature de la relation et rien
  # d'autre. Notes, gouts et prets restent hors de portee (le numero peut etre usurpe).
  RELATIONS = {
    "ami" => "un(e) ami(e) de Sylvain", "copine" => "la copine de Sylvain", "ex" => "un(e) ex de Sylvain",
    "famille" => "un membre de la famille de Sylvain", "collegue" => "un(e) collègue de Sylvain",
    "connaissance" => "une connaissance de Sylvain", "client" => "un(e) client(e) de Sylvain",
    "prospect" => "un(e) client(e) potentiel(le) de Sylvain", "partenaire" => "un(e) partenaire professionnel(le) de Sylvain",
    "prestataire" => "un(e) prestataire de Sylvain", "eleve" => "un(e) élève de Sylvain", "medias" => "un contact de Sylvain dans les médias"
  }.freeze

  belongs_to :contact, optional: true
  has_many :messages, class_name: "SmsMessage", dependent: :destroy, inverse_of: :correspondent
  has_many :conversations, class_name: "AlfredConversation", dependent: :nullify, inverse_of: :sms_correspondent

  normalizes :name, with: ->(value) { value.squish }
  normalizes :phone, with: ->(value) { SmsCorrespondent.normalize_phone(value) }

  validates :name, presence: true
  validates :contact, presence: true, if: :contact_id
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

  def relation
    RELATIONS[contact&.relationship_type]
  end

  # Pour s'adresser a la personne : repris de sa fiche, sans rien deviner du genre.
  def first_name
    contact&.first_name.presence || name.split.first
  end

  def gender
    contact&.gender
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
