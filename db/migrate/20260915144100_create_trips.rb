class CreateTrips < ActiveRecord::Migration[8.0]
  def change
    create_table :trips do |t|
      t.string :destination, null: false
      # ISO 3166-1 alpha-2, lowercase (matches the SVG world map ids)
      t.string :country_code, null: false, limit: 2
      t.date :start_date, null: false
      t.date :end_date, null: false
      t.integer :travelers, null: false, default: 1
      t.string :departure_city, default: "Paris"
      t.string :status, null: false, default: "envisage"
      t.text :notes

      t.timestamps
    end

    add_index :trips, :country_code
    add_index :trips, :start_date
    add_index :trips, :status
  end
end
