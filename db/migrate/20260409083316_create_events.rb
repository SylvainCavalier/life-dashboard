class CreateEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :events do |t|
      t.string :title, null: false
      t.text :description
      t.string :event_type, null: false, default: "autre"
      t.datetime :start_time, null: false
      t.datetime :end_time
      t.string :location
      t.string :color, default: "#6366f1"
      t.boolean :all_day, default: false
      t.integer :reminder_minutes, default: 60

      t.timestamps
    end

    add_index :events, :start_time
    add_index :events, :event_type
  end
end
