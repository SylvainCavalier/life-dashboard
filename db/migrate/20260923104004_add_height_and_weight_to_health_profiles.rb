class AddHeightAndWeightToHealthProfiles < ActiveRecord::Migration[8.0]
  def change
    add_column :health_profiles, :height_cm, :integer
    add_column :health_profiles, :weight_kg, :decimal, precision: 5, scale: 1
  end
end
