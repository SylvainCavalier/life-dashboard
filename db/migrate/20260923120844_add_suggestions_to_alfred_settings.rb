class AddSuggestionsToAlfredSettings < ActiveRecord::Migration[8.0]
  def change
    add_column :alfred_settings, :suggestions, :jsonb, null: false, default: []
  end
end
