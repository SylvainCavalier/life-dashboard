class LanguageSession < ApplicationRecord
  belongs_to :language

  SOURCES = %w[manual langochat].freeze

  validates :practiced_on, presence: true
  validates :source, inclusion: { in: SOURCES }, allow_blank: true
  validates :practiced_on, uniqueness: { scope: [:language_id, :source], message: "deja enregistree pour cette date et source" }

  scope :ordered, -> { order(practiced_on: :desc) }
end
