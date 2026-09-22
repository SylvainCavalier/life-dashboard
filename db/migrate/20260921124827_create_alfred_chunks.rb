# Corpus d'Alfred : un passage retrouvable par ligne. La source est polymorphe
# (n'importe quel enregistrement du dashboard) et `kind` distingue la fiche
# ("record" : les champs de l'enregistrement) du contenu du fichier joint ("file").
class CreateAlfredChunks < ActiveRecord::Migration[8.0]
  EMBEDDING_DIMENSIONS = 1024 # mistral-embed : DOIT rester egal a Embeddings::DIMENSIONS

  def change
    create_table :alfred_chunks do |t|
      t.references :source, polymorphic: true, null: false
      t.string  :kind, null: false, default: "record"
      t.integer :position, null: false, default: 0
      t.string  :label, null: false
      t.date    :source_date
      t.text    :content, null: false
      # Miroir sans accents de `content` (Alfred::AccentFolding), source du tsvector :
      # la recherche lexicale ignore les accents sans config Postgres specifique,
      # donc schema.rb reste rechargeable tel quel.
      t.text    :content_fold
      t.virtual :content_tsv, type: :tsvector, stored: true,
                              as: "to_tsvector('french'::regconfig, COALESCE(content_fold, ''::text))"
      t.integer :token_count
      t.column  :embedding, :vector, limit: EMBEDDING_DIMENSIONS
      t.timestamps
    end

    add_index :alfred_chunks, [:source_type, :source_id, :kind, :position], unique: true,
              name: "index_alfred_chunks_on_source_kind_position"
    add_index :alfred_chunks, :content_tsv, using: :gin
    # L'index vectoriel (HNSW) est pose par la migration suivante.
  end
end
