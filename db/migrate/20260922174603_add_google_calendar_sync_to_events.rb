class AddGoogleCalendarSyncToEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :google_event_id, :string
    add_index :events, :google_event_id, unique: true
    add_column :events, :google_updated_at, :datetime
  end
end
