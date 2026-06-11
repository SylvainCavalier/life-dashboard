class CreateCvSkills < ActiveRecord::Migration[8.0]
  def change
    create_table :cv_skills do |t|
      t.string :name, null: false
      t.string :category, null: false, default: "autre"
      t.string :level
      t.integer :position, default: 0, null: false

      t.timestamps
    end

    add_index :cv_skills, :category
    add_index :cv_skills, :position
  end
end
