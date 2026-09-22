# Un passage du corpus d'Alfred : son texte et son embedding (1024 dimensions).
# `normalize: true` stocke des vecteurs normalises, la distance cosine a donc un sens.
# == Schema Information
#
# Table name: alfred_chunks
#
#  id           :bigint           not null, primary key
#  content      :text             not null
#  content_fold :text
#  content_tsv  :tsvector
#  embedding    :vector(1024)
#  kind         :string           default("record"), not null
#  label        :string           not null
#  position     :integer          default(0), not null
#  source_date  :date
#  source_type  :string           not null
#  token_count  :integer
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  source_id    :bigint           not null
#
# Indexes
#
#  index_alfred_chunks_on_content_tsv           (content_tsv) USING gin
#  index_alfred_chunks_on_embedding_hnsw        (embedding) USING hnsw
#  index_alfred_chunks_on_source                (source_type,source_id)
#  index_alfred_chunks_on_source_kind_position  (source_type,source_id,kind,position) UNIQUE
#
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
