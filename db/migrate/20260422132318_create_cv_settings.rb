class CreateCvSettings < ActiveRecord::Migration[8.0]
  def change
    create_table :cv_settings do |t|
      t.string :default_template, default: "classic", null: false
      t.string :default_color, default: "indigo", null: false

      t.timestamps
    end
  end
end
