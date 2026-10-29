class CreateWarranties < ActiveRecord::Migration[8.0]
  def change
    create_table :warranties do |t|
      t.string :name, null: false
      t.string :brand
      t.string :model_reference
      t.string :category, null: false, default: "autre"
      t.string :serial_number
      t.string :store
      t.string :order_number
      t.date :purchased_on, null: false
      t.decimal :price, precision: 10, scale: 2
      t.integer :duration_months
      t.date :ends_on, null: false
      t.string :support_contact
      t.text :notes

      t.timestamps
    end
    add_index :warranties, :ends_on
  end
end
