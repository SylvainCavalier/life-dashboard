# == Schema Information
#
# Table name: cv_settings
#
#  id               :bigint           not null, primary key
#  default_color    :string           default("indigo"), not null
#  default_template :string           default("classic"), not null
#  pitch            :text
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
class CvSetting < ApplicationRecord
  TEMPLATES = %w[classic modern].freeze
  COLORS = %w[indigo slate emerald bordeaux].freeze
  PHOTO_MAX_BYTES = 5.megabytes
  PHOTO_CONTENT_TYPES = %w[image/jpeg image/png image/webp].freeze

  has_one_attached :photo

  validates :default_template, inclusion: { in: TEMPLATES }
  validates :default_color, inclusion: { in: COLORS }
  validate :acceptable_photo

  def self.singleton
    first_or_create!
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
