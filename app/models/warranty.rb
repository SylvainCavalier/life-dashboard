# == Schema Information
#
# Table name: warranties
#
#  id              :bigint           not null, primary key
#  brand           :string
#  category        :string           default("autre"), not null
#  duration_months :integer
#  ends_on         :date             not null
#  model_reference :string
#  name            :string           not null
#  notes           :text
#  order_number    :string
#  price           :decimal(10, 2)
#  purchased_on    :date             not null
#  serial_number   :string
#  store           :string
#  support_contact :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_warranties_on_ends_on  (ends_on)
#
# Garantie d'un objet achete (page Garanties). `ends_on` fait foi : c'est la date de
# fin de garantie, extension comprise. Avec `duration_months`, elle se calcule toute
# seule depuis la date d'achat, sauf si elle est saisie a la main (extension, garantie
# constructeur qui court depuis la livraison...). La facture (`receipt`) est la preuve
# d'achat a produire au SAV ; elle est lue par Alfred (corpus, OCR pour une photo).
class Warranty < ApplicationRecord
  CATEGORIES = %w[
    electromenager informatique telephonie audio_video photo jeux_video mobilier
    bricolage_jardin vehicule sport mode autre
  ].freeze

  CATEGORY_LABELS = {
    "electromenager" => "Électroménager", "informatique" => "Informatique", "telephonie" => "Téléphonie",
    "audio_video" => "Audio / vidéo", "photo" => "Photo", "jeux_video" => "Jeux vidéo", "mobilier" => "Mobilier",
    "bricolage_jardin" => "Bricolage / jardin", "vehicule" => "Véhicule / mobilité", "sport" => "Sport",
    "mode" => "Mode / accessoires", "autre" => "Autre"
  }.freeze

  # Garantie qui finit dans ce delai : signalee en orange sur la page et dans le rapport du matin.
  EXPIRING_DAYS = 60
  RECEIPT_TYPES = %w[application/pdf image/jpeg image/png image/webp image/heic image/heif].freeze
  RECEIPT_MAX_SIZE = 10.megabytes

  has_one_attached :receipt

  before_validation :compute_ends_on

  validates :name, presence: true
  validates :purchased_on, presence: true
  validates :ends_on, presence: { message: "requise (ou une duree de garantie)" }
  validates :category, inclusion: { in: CATEGORIES }
  validates :price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :duration_months, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 600 },
                              allow_nil: true
  validate :ends_after_purchase
  validate :receipt_format

  scope :ordered, -> { order(:ends_on, :name) }
  scope :active, -> { where(ends_on: Date.current..) }

  def days_left(today = Date.current)
    (ends_on - today).to_i if ends_on
  end

  # active | expiring (fin sous EXPIRING_DAYS jours) | expired
  def status(today = Date.current)
    days = days_left(today)
    return "expired" if days.nil? || days.negative?

    days <= EXPIRING_DAYS ? "expiring" : "active"
  end

  def api_attributes
    attributes.symbolize_keys.merge(
      category_label: CATEGORY_LABELS[category],
      status: status,
      days_left: days_left,
      receipt: receipt.attached? ? receipt_json : nil
    )
  end

  private

  # Duree connue et fin non saisie a la main : fin = achat + duree. Une fin modifiee
  # explicitement (extension) l'emporte sur la duree.
  def compute_ends_on
    return unless purchased_on && duration_months.to_i.positive?
    return if ends_on.present? && (new_record? || will_save_change_to_ends_on?)
    return unless ends_on.blank? || will_save_change_to_purchased_on? || will_save_change_to_duration_months?

    self.ends_on = purchased_on >> duration_months.to_i
  end

  def ends_after_purchase
    return unless purchased_on && ends_on && ends_on < purchased_on

    errors.add(:ends_on, "doit etre posterieure a la date d'achat")
  end

  def receipt_format
    return unless receipt.attached? && attachment_changes["receipt"]

    errors.add(:receipt, "doit etre un PDF ou une image") unless RECEIPT_TYPES.include?(receipt.blob.content_type)
    errors.add(:receipt, "depasse 10 Mo") if receipt.blob.byte_size > RECEIPT_MAX_SIZE
  end

  def receipt_json
    {
      filename: receipt.filename.to_s,
      content_type: receipt.blob.content_type,
      byte_size: receipt.blob.byte_size,
      url: Rails.application.routes.url_helpers.rails_blob_path(receipt, only_path: true)
    }
  end
end
