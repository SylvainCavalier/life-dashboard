# Accroche de CV. Plusieurs accroches coexistent (une par type de poste vise) ;
# celle qui s'affiche sur le CV est CvSetting#active_pitch.
# == Schema Information
#
# Table name: cv_pitches
#
#  id         :bigint           not null, primary key
#  content    :text             not null
#  position   :integer          default(0), not null
#  title      :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_cv_pitches_on_position  (position)
#
class CvPitch < ApplicationRecord
  has_one :cv_setting, foreign_key: :active_pitch_id, inverse_of: :active_pitch, dependent: :nullify

  validates :title, presence: true, length: { maximum: 100 }
  validates :content, presence: true

  scope :ordered, -> { order(position: :asc, created_at: :asc) }
end
