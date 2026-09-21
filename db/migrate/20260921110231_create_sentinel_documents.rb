class CreateSentinelDocuments < ActiveRecord::Migration[8.0]
  def change
    create_table :sentinel_documents do |t|
      t.references :sentinel_source, null: false, foreign_key: true
      # Denormalised from the source: every read is scoped by domain + week.
      t.string :domain, null: false
      t.date :monday, null: false
      # Identifier in the source system (API id), or the normalised URL for feeds and web search.
      t.string :external_id, null: false
      t.string :kind, null: false
      t.string :title, null: false
      t.string :url
      t.string :author
      t.datetime :published_at
      t.text :raw_content
      t.jsonb :raw_metadata, null: false, default: {}

      # Deterministic classification, done before any LLM call. nil = not classified yet.
      t.boolean :relevant
      t.string :relevance_reason

      # AI summary, mirrors Sentinel::DocumentSummarySchema.
      t.string :display_title
      t.text :tldr
      t.jsonb :key_points, null: false, default: []
      t.string :importance
      t.jsonb :categories, null: false, default: []
      t.string :summary_model
      t.datetime :summarized_at

      t.timestamps
    end

    add_index :sentinel_documents, [:sentinel_source_id, :external_id], unique: true
    add_index :sentinel_documents, [:domain, :monday]
  end
end
