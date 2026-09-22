# Cache texte -> embedding. (provider, model) fait partie de la cle : un changement
# de modele (donc de dimension) manque proprement le cache au lieu de servir un
# vecteur de la mauvaise taille.
class CreateEmbeddingCaches < ActiveRecord::Migration[8.0]
  EMBEDDING_DIMENSIONS = 1024

  def change
    create_table :embedding_caches do |t|
      t.string :provider, null: false
      t.string :model, null: false
      t.string :content_hash, null: false
      t.column :embedding, :vector, limit: EMBEDDING_DIMENSIONS, null: false
      t.timestamps
    end
    add_index :embedding_caches, [:provider, :model, :content_hash], unique: true,
              name: "index_embedding_caches_on_provider_model_hash"
  end
end
