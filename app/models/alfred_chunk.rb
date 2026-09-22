# Un passage du corpus d'Alfred : son texte et son embedding (1024 dimensions).
# `normalize: true` stocke des vecteurs normalises, la distance cosine a donc un sens.
class AlfredChunk < ApplicationRecord
  include PgSearch::Model

  KINDS = %w[record file].freeze

  has_neighbors :embedding, normalize: true

  belongs_to :source, polymorphic: true

  validates :kind, inclusion: { in: KINDS }
  validates :content, :label, presence: true

  # Le miroir sans accents alimente la colonne generee `content_tsv` ; la requete
  # est pliee de la meme facon avant `search_lexical`.
  before_save { self.content_fold = Alfred::AccentFolding.fold(content) }

  pg_search_scope :search_lexical,
                  against: :content,
                  using: { tsearch: { dictionary: "french", tsvector_column: "content_tsv", prefix: true, any_word: true } }

  scope :for_source, ->(record) { where(source_type: record.class.name, source_id: record.id) }

  # Requete pure : le plancher de pertinence s'applique dans Alfred::Corpus::Search.
  def self.nearest_to(embedding, limit:)
    nearest_neighbors(:embedding, embedding, distance: "cosine").limit(limit)
  end
end
