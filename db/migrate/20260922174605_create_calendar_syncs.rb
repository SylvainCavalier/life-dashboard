class CreateCalendarSyncs < ActiveRecord::Migration[8.0]
  # Une seule ligne : l'etat de la synchronisation Google Calendar (l'interface
  # la sonde tant qu'une synchronisation tourne, comme pour le Downloader).
  def change
    create_table :calendar_syncs do |t|
      t.string :status, null: false, default: "idle"
      t.datetime :last_synced_at
      t.datetime :started_at
      t.text :last_error
      t.integer :pulled_count, null: false, default: 0
      t.integer :pushed_count, null: false, default: 0
      t.integer :deleted_count, null: false, default: 0

      t.timestamps
    end
  end
end
