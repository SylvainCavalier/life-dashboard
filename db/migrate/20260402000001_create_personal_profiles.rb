class CreatePersonalProfiles < ActiveRecord::Migration[8.0]
  def change
    create_table :personal_profiles do |t|
      # Identité
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :maiden_name
      t.date :birth_date
      t.string :birth_city
      t.string :birth_country
      t.string :nationality
      t.string :gender

      # Contact
      t.string :email
      t.string :phone
      t.string :mobile_phone
      t.string :address_line1
      t.string :address_line2
      t.string :city
      t.string :postal_code
      t.string :state
      t.string :country

      # Documents officiels
      t.string :social_security_number
      t.string :passport_number
      t.date :passport_expiry
      t.string :national_id_number
      t.date :national_id_expiry
      t.string :driver_license_number
      t.date :driver_license_expiry
      t.string :tax_id

      # Professionnel
      t.string :occupation
      t.string :employer
      t.string :employer_address
      t.string :professional_email
      t.string :professional_phone
      t.string :siret_number

      # Famille
      t.string :marital_status
      t.string :spouse_name
      t.integer :number_of_children
      t.string :emergency_contact_name
      t.string :emergency_contact_phone
      t.string :emergency_contact_relationship

      # Santé
      t.string :blood_type
      t.string :health_insurance_number
      t.string :attending_physician
      t.text :allergies

      # Bancaire
      t.string :bank_name
      t.string :iban
      t.string :bic

      t.timestamps
    end
  end
end
