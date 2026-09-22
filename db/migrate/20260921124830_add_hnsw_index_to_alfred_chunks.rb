# Index ANN. L'opclass DOIT correspondre a la distance des requetes (cosine ->
# vector_cosine_ops), sinon l'index est ignore en silence (scan sequentiel).
class AddHnswIndexToAlfredChunks < ActiveRecord::Migration[8.0]
  def change
    add_index :alfred_chunks, :embedding, using: :hnsw, opclass: :vector_cosine_ops,
              name: "index_alfred_chunks_on_embedding_hnsw"
  end
end
