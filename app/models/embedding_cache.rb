# Cache persistant texte -> embedding, indexe par le fournisseur, le modele et un
# SHA256 du texte. Reindexer un contenu inchange ne coute aucun appel a l'API.
# Seule l'empreinte est stockee, jamais le texte.
# == Schema Information
#
# Table name: embedding_caches
#
#  id           :bigint           not null, primary key
#  content_hash :string           not null
#  embedding    :vector(1024)     not null
#  model        :string           not null
#  provider     :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
# Indexes
#
#  index_embedding_caches_on_provider_model_hash  (provider,model,content_hash) UNIQUE
#
class EmbeddingCache < ApplicationRecord
  has_neighbors :embedding

  validates :provider, :model, :content_hash, presence: true

  def self.digest(text)
    Digest::SHA256.hexdigest(text.to_s)
  end
end
