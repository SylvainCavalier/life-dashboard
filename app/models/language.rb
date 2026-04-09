class Language < ApplicationRecord
  has_many :language_sessions, dependent: :destroy

  LEVELS = %w[A1 A2 B1 B2 C1 C2].freeze

  # Langues disponibles, avec leur code Langochat associe
  NAMES = {
    "Allemand" => "de",
    "Anglais" => "en",
    "Arabe" => "ar",
    "Espagnol" => "esp",
    "Grec" => "gr",
    "Italien" => "it",
    "Japonais" => "ja",
    "Neerlandais" => "nl",
    "Polonais" => "pol",
    "Portugais" => "pt",
    "Russe" => "ru",
    "Thai" => "th",
    "Turc" => "tr",
    "Ukrainien" => "ukr"
  }.freeze

  validates :name, presence: true, uniqueness: true, inclusion: { in: NAMES.keys }
  validates :level, presence: true, inclusion: { in: LEVELS }

  def langochat_code
    NAMES[name]
  end

  scope :ordered, -> { order(:name) }

  def sessions_this_week
    language_sessions.where(practiced_on: Date.current.beginning_of_week..Date.current.end_of_week).count
  end

  def practiced_today?
    language_sessions.exists?(practiced_on: Date.current)
  end

  def streak
    count = 0
    date = Date.current
    loop do
      break unless language_sessions.exists?(practiced_on: date)
      count += 1
      date -= 1.day
    end
    count
  end
end
