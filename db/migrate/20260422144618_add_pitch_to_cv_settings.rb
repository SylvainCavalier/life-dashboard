class AddPitchToCvSettings < ActiveRecord::Migration[8.0]
  def change
    add_column :cv_settings, :pitch, :text
  end
end
