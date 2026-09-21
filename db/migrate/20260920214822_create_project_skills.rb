class CreateProjectSkills < ActiveRecord::Migration[8.0]
  def change
    create_table :project_skills do |t|
      t.references :project, null: false, foreign_key: true
      t.string :name, null: false
      t.string :status, default: "a_apprendre", null: false
      t.integer :position, default: 0, null: false

      t.timestamps
    end
  end
end
