# == Schema Information
#
# Table name: language_sessions
#
#  id           :bigint           not null, primary key
#  notes        :text
#  practiced_on :date             not null
#  source       :string           default("manual")
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  language_id  :bigint           not null
#
# Indexes
#
#  index_language_sessions_on_language_id  (language_id)
#
# Foreign Keys
#
#  fk_rails_...  (language_id => languages.id)
#
class LanguageSession < ApplicationRecord
  belongs_to :language

  SOURCES = %w[manual langochat].freeze

  validates :practiced_on, presence: true
  validates :source, inclusion: { in: SOURCES }, allow_blank: true
  validates :practiced_on, uniqueness: { scope: [:language_id, :source], message: "deja enregistree pour cette date et source" }

  scope :ordered, -> { order(practiced_on: :desc) }
end
