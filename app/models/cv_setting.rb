# == Schema Information
#
# Table name: cv_settings
#
#  id               :bigint           not null, primary key
#  default_color    :string           default("indigo"), not null
#  default_template :string           default("classic"), not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  active_pitch_id  :bigint
#
# Indexes
#
#  index_cv_settings_on_active_pitch_id  (active_pitch_id)
#
# Foreign Keys
#
#  fk_rails_...  (active_pitch_id => cv_pitches.id) ON DELETE => nullify
#
class CvSetting < ApplicationRecord
  TEMPLATES = %w[classic modern].freeze
  COLORS = %w[indigo slate emerald bordeaux].freeze
  PHOTO_MAX_BYTES = 5.megabytes
  PHOTO_CONTENT_TYPES = %w[image/jpeg image/png image/webp].freeze

  has_one_attached :photo
  belongs_to :active_pitch, class_name: "CvPitch", optional: true, inverse_of: :cv_setting

  validates :default_template, inclusion: { in: TEMPLATES }
  validates :default_color, inclusion: { in: COLORS }
  validates :active_pitch, presence: true, if: -> { active_pitch_id.present? }
  validate :acceptable_photo

  def self.singleton
    first_or_create!
  end

  # Texte de l'accroche affichee sur le CV (nil si aucune n'est selectionnee).
  def pitch
    active_pitch&.content
  end

  def photo_data_url
    return nil unless photo.attached?
    "data:#{photo.content_type};base64,#{Base64.strict_encode64(photo.download)}"
  rescue ActiveStorage::FileNotFoundError
    nil
  end

  private

  def acceptable_photo
    return unless photo.attached?
    errors.add(:photo, "doit être un JPEG, PNG ou WebP") unless PHOTO_CONTENT_TYPES.include?(photo.content_type)
    errors.add(:photo, "est trop volumineuse (max 5 Mo)")  if photo.byte_size > PHOTO_MAX_BYTES
  end
end
