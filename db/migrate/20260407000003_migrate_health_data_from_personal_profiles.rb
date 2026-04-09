class MigrateHealthDataFromPersonalProfiles < ActiveRecord::Migration[8.0]
  def up
    # Copier les donnees sante existantes de personal_profiles vers health_profiles
    execute <<-SQL
      INSERT INTO health_profiles (blood_type, allergies, attending_physician, health_insurance_number, created_at, updated_at)
      SELECT blood_type, allergies, attending_physician, health_insurance_number, NOW(), NOW()
      FROM personal_profiles
      WHERE blood_type IS NOT NULL
         OR allergies IS NOT NULL
         OR attending_physician IS NOT NULL
         OR health_insurance_number IS NOT NULL
      LIMIT 1
    SQL

    # Supprimer les colonnes sante de personal_profiles
    remove_column :personal_profiles, :blood_type, :string
    remove_column :personal_profiles, :health_insurance_number, :string
    remove_column :personal_profiles, :attending_physician, :string
    remove_column :personal_profiles, :allergies, :text
  end

  def down
    add_column :personal_profiles, :blood_type, :string
    add_column :personal_profiles, :health_insurance_number, :string
    add_column :personal_profiles, :attending_physician, :string
    add_column :personal_profiles, :allergies, :text
  end
end
