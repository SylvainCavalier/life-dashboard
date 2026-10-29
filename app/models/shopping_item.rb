# == Schema Information
#
# Table name: shopping_items
#
#  id         :bigint           not null, primary key
#  checked_at :datetime
#  name       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_shopping_items_on_lower_name  (lower((name)::text)) UNIQUE
#
# Un article de la liste de courses (page Courses). Il n'y a qu'une liste : elle se
# vide d'un coup apres les courses (`clear!`), rien n'est archive. `checked_at` =
# article mis dans le caddie, coche en magasin. Un meme article (casse ignoree) n'est
# qu'une fois dans la liste : `add_names` ecarte les doublons au lieu d'echouer.
class ShoppingItem < ApplicationRecord
  MAX_LENGTH = 100

  before_validation :normalize_name

  validates :name, presence: true, length: { maximum: MAX_LENGTH },
                   uniqueness: { case_sensitive: false, message: "est deja dans la liste" }

  # A acheter d'abord (ordre d'ajout), puis ce qui est deja dans le caddie.
  scope :ordered, -> { order(Arel.sql("checked_at IS NOT NULL"), :created_at, :id) }

  def checked? = checked_at.present?

  # Ajoute plusieurs articles d'un coup (presets, Alfred, rake). Renvoie [ajoutes, deja presents].
  def self.add_names(names)
    added = []
    skipped = []
    transaction do
      names.map { |name| name.to_s.squish }.compact_blank.uniq(&:downcase).each do |name|
        if exists?(["lower(name) = ?", name.downcase])
          skipped << name
        else
          added << create!(name: name)
        end
      end
    end
    [added, skipped]
  end

  # Remise a zero apres les courses. Renvoie le nombre d'articles retires.
  def self.clear!
    delete_all
  end

  def api_attributes
    attributes.symbolize_keys.merge(checked: checked?)
  end

  private

  def normalize_name
    self.name = name.to_s.squish.upcase_first if name
  end
end
