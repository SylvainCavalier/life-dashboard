class CreateSentinelSources < ActiveRecord::Migration[8.0]
  def change
    create_table :sentinel_sources do |t|
      # Key of the monitoring domain (Sentinel::Domains registry), e.g. "droit_travail".
      t.string :domain, null: false
      t.string :name, null: false
      t.string :slug, null: false
      t.string :url
      # A source can be collected through any combination of: a dedicated
      # adapter (official API or scraper), an RSS/Atom feed, the Tavily web search.
      t.string :adapter
      t.string :feed_url
      t.boolean :web_search, null: false, default: false
      # Specialised source: every document it publishes is in scope, no keyword filtering.
      t.boolean :on_topic, null: false, default: false
      t.string :language, null: false, default: "fr"
      t.boolean :active, null: false, default: true
      # Outcome of the last collection, shown in the UI so a dead feed or a
      # broken scraper does not fail silently.
      t.datetime :last_collected_at
      t.integer :last_documents_count
      t.text :last_error

      t.timestamps
    end

    add_index :sentinel_sources, [:domain, :slug], unique: true
  end
end
