class CreateHealthProfiles < ActiveRecord::Migration[8.0]
  def change
    create_table :health_profiles do |t|
      # Informations generales
      t.string :blood_type
      t.text :allergies
      t.text :current_medications
      t.text :medical_history

      # Medecins
      t.string :attending_physician
      t.string :attending_physician_phone
      t.text :specialists

      # Securite sociale
      t.string :social_security_number

      # Mutuelle
      t.string :health_insurance_name
      t.string :health_insurance_number
      t.string :health_insurance_website

      # Liens utiles
      t.string :ameli_url, default: "https://www.ameli.fr"

      t.timestamps
    end
  end
end
