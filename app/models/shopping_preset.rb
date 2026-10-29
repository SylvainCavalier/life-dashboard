# == Schema Information
#
# Table name: shopping_presets
#
#  id         :bigint           not null, primary key
#  icon       :string
#  name       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_shopping_presets_on_lower_name  (lower((name)::text)) UNIQUE
#
# Article habituel de la page Courses : une carte qui ajoute l'article a la liste
# en un clic, pour ne pas l'oublier. `icon` = emoji facultatif affiche sur la carte.
class ShoppingPreset < ApplicationRecord
  before_validation :normalize

  validates :name, presence: true, length: { maximum: ShoppingItem::MAX_LENGTH },
                   uniqueness: { case_sensitive: false, message: "a deja sa carte" }
  validates :icon, length: { maximum: 16 }

  scope :ordered, -> { order(Arel.sql("lower(name)")) }

  private

  def normalize
    self.name = name.to_s.squish.upcase_first if name
    self.icon = icon.to_s.strip.presence
  end
end
