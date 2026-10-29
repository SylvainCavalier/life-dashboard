class CreateInsurances < ActiveRecord::Migration[8.0]
  def change
    create_table :insurances do |t|
      t.string :name, null: false
      t.string :insurance_type, null: false
      t.string :insurer
      t.string :policy_number
      t.string :status, null: false, default: "active"
      t.date :start_date
      t.date :end_date
      t.date :renewal_date
      t.decimal :premium, precision: 10, scale: 2
      t.string :premium_frequency, null: false, default: "yearly"
      t.text :conditions
      t.text :notes
      t.string :advisor_name
      t.string :advisor_phone
      t.string :advisor_email
      t.string :claims_phone
      t.string :website_url

      t.timestamps
    end
    add_index :insurances, :insurance_type
  end
end
