# Etat d'indexation d'un enregistrement. Les empreintes evitent de repayer ce qui
# n'a pas change : `record_digest` pour la fiche, `file_digest` (checksum du blob)
# pour le fichier joint, dont l'OCR est la partie couteuse.
class CreateAlfredIndexEntries < ActiveRecord::Migration[8.0]
  def change
    create_table :alfred_index_entries do |t|
      t.references :source, polymorphic: true, null: false, index: { unique: true }
      t.string   :status, null: false, default: "pending" # pending | indexed | failed
      t.string   :record_digest
      t.string   :file_digest
      t.string   :file_extractor # pdf_reader | mistral_ocr | text | unsupported
      t.integer  :chunks_count, null: false, default: 0
      t.text     :error
      t.datetime :indexed_at
      t.timestamps
    end
    add_index :alfred_index_entries, :status
  end
end
