class UsefulSite < ApplicationRecord
  CATEGORIES = %w[dev medias desinformation video jeux administratif sante langues].freeze

  validates :name, presence: true
  validates :url, presence: true, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) }
  validates :category, presence: true, inclusion: { in: CATEGORIES }

  scope :ordered, -> { order(:category, :name) }
end
