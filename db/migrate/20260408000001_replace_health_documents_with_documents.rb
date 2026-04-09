class ReplaceHealthDocumentsWithDocuments < ActiveRecord::Migration[8.0]
  def up
    # Creer la nouvelle table documents generique
    create_table :documents do |t|
      t.string :domain, null: false
      t.string :name, null: false
      t.string :category
      t.date :document_date
      t.text :notes

      t.timestamps
    end

    add_index :documents, :domain
    add_index :documents, [:domain, :category]

    # Migrer les donnees existantes de health_documents vers documents
    execute <<-SQL
      INSERT INTO documents (domain, name, category, document_date, notes, created_at, updated_at)
      SELECT 'health', name, category, document_date, notes, created_at, updated_at
      FROM health_documents
    SQL

    # Supprimer l'ancienne table
    drop_table :health_documents
  end

  def down
    create_table :health_documents do |t|
      t.references :health_profile, null: false, foreign_key: true
      t.string :name, null: false
      t.string :category
      t.date :document_date
      t.text :notes

      t.timestamps
    end

    execute <<-SQL
      INSERT INTO health_documents (health_profile_id, name, category, document_date, notes, created_at, updated_at)
      SELECT (SELECT id FROM health_profiles LIMIT 1), name, category, document_date, notes, created_at, updated_at
      FROM documents
      WHERE domain = 'health'
    SQL

    drop_table :documents
  end
end
