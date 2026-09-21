class CreateTripItems < ActiveRecord::Migration[8.0]
  def change
    create_table :trip_items do |t|
      t.references :trip, null: false, foreign_key: true
      t.date :day, null: false
      t.string :kind, null: false, default: "autre"
      t.string :title, null: false
      t.string :url
      t.time :start_time
      t.decimal :cost, precision: 10, scale: 2
      t.text :notes
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :trip_items, [:trip_id, :day]
  end
end
