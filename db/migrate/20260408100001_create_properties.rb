class CreateProperties < ActiveRecord::Migration[8.0]
  def change
    create_table :properties do |t|
      t.string :name, null: false
      t.string :property_type, null: false
      t.string :address_line1
      t.string :address_line2
      t.string :postal_code
      t.string :city
      t.string :country, default: "France"
      t.decimal :surface, precision: 10, scale: 2
      t.integer :rooms
      t.integer :bedrooms
      t.integer :bathrooms
      t.integer :floors
      t.integer :construction_year
      t.date :purchase_date
      t.decimal :purchase_price, precision: 12, scale: 2
      t.decimal :current_value, precision: 12, scale: 2
      t.decimal :loan_remaining, precision: 12, scale: 2
      t.decimal :monthly_payment, precision: 10, scale: 2
      t.integer :months_remaining
      t.decimal :monthly_charges, precision: 10, scale: 2
      t.decimal :property_tax, precision: 10, scale: 2
      t.decimal :rental_income, precision: 10, scale: 2
      t.boolean :rented, default: false
      t.string :tenant_name
      t.text :notes
      t.timestamps
    end
  end
end
