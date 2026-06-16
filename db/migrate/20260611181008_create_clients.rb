class CreateClients < ActiveRecord::Migration[8.0]
  def change
    create_table :clients do |t|
      t.references :company, null: false, foreign_key: true
      t.string :name
      t.string :email
      t.string :phone
      t.string :siret
      t.string :vat_number
      t.string :address_line1
      t.string :address_line2
      t.string :postal_code
      t.string :city
      t.string :country
      t.text :notes

      t.timestamps
    end
  end
end
