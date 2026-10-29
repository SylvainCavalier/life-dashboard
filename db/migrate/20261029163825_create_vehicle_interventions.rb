class CreateVehicleInterventions < ActiveRecord::Migration[8.0]
  def change
    create_table :vehicle_interventions do |t|
      t.references :vehicle, null: false, foreign_key: true
      t.date :occurred_on, null: false
      t.string :kind, null: false, default: "entretien"
      t.string :title, null: false
      t.integer :mileage
      t.decimal :cost, precision: 10, scale: 2
      t.string :garage
      t.string :outcome
      t.text :description

      t.timestamps
    end
    add_index :vehicle_interventions, [:vehicle_id, :occurred_on]
  end
end
