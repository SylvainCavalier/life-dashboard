# == Schema Information
#
# Table name: useful_sites
#
#  id          :bigint           not null, primary key
#  category    :string           not null
#  description :string
#  name        :string           not null
#  url         :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_useful_sites_on_category  (category)
#
class UsefulSite < ApplicationRecord
  CATEGORIES = %w[dev medias desinformation video jeux administratif sante langues juridique].freeze

  validates :name, presence: true
  validates :url, presence: true, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) }
  validates :category, presence: true, inclusion: { in: CATEGORIES }

  scope :ordered, -> { order(:category, :name) }
end
