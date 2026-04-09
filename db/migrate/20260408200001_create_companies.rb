class CreateCompanies < ActiveRecord::Migration[8.0]
  def change
    create_table :companies do |t|
      t.string :name, null: false
      t.string :legal_form
      t.string :siren
      t.string :siret
      t.string :vat_number
      t.string :activity
      t.string :status, default: 'active'
      t.date :creation_date
      t.decimal :capital, precision: 12, scale: 2
      t.decimal :revenue, precision: 12, scale: 2
      t.integer :employees_count
      t.string :address_line1
      t.string :address_line2
      t.string :postal_code
      t.string :city
      t.string :country, default: 'France'
      t.string :website
      t.string :email
      t.string :phone
      t.text :notes

      t.timestamps
    end
  end
end
