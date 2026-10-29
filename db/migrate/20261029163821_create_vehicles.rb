class CreateVehicles < ActiveRecord::Migration[8.0]
  def change
    create_table :vehicles do |t|
      t.string :name, null: false
      t.string :vehicle_type, null: false, default: "voiture"
      t.string :status, null: false, default: "active"
      t.string :brand
      t.string :model
      t.string :version
      t.integer :year
      t.string :registration_number
      t.string :vin
      t.date :first_registration_on
      t.string :fuel
      t.integer :fiscal_power
      t.integer :power_hp
      t.integer :engine_displacement
      t.string :color
      t.string :tire_size
      t.string :oil_type
      t.date :purchased_on
      t.decimal :purchase_price, precision: 10, scale: 2
      t.integer :purchase_mileage
      t.integer :mileage
      t.date :mileage_on
      t.date :technical_inspection_due_on
      t.integer :service_interval_km
      t.integer :service_interval_months
      t.date :sold_on
      t.decimal :sale_price, precision: 10, scale: 2
      t.text :notes

      t.timestamps
    end
  end
end
