class CreateInvoices < ActiveRecord::Migration[8.0]
  def change
    create_table :invoices do |t|
      t.references :company, null: false, foreign_key: true
      t.references :quote, null: true, foreign_key: true

      # Auto-generated number (sequential, no gaps)
      t.string :number, null: false

      # Client info
      t.string :client_name, null: false
      t.string :client_email
      t.string :client_phone
      t.string :client_siret
      t.string :client_vat_number
      t.string :client_address_line1
      t.string :client_address_line2
      t.string :client_postal_code
      t.string :client_city
      t.string :client_country, default: "France"

      # Subject
      t.string :subject

      # Financial
      t.decimal :total_ht, precision: 10, scale: 2, default: 0
      t.decimal :total_tva, precision: 10, scale: 2, default: 0
      t.decimal :total_ttc, precision: 10, scale: 2, default: 0
      t.decimal :tva_rate, precision: 5, scale: 2, default: 20.0

      # Status
      t.string :status, null: false, default: "pending"

      # Dates
      t.date :issue_date, null: false
      t.date :due_date

      # Extra
      t.text :notes
      t.text :conditions

      t.timestamps
    end

    add_index :invoices, :number, unique: true
    add_index :invoices, [:company_id, :status]
  end
end
