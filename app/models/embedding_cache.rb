# Cache persistant texte -> embedding, indexe par le fournisseur, le modele et un
# SHA256 du texte. Reindexer un contenu inchange ne coute aucun appel a l'API.
# Seule l'empreinte est stockee, jamais le texte.
class EmbeddingCache < ApplicationRecord
  has_neighbors :embedding

  validates :provider, :model, :content_hash, presence: true

  def self.digest(text)
    Digest::SHA256.hexdigest(text.to_s)
  end
end
