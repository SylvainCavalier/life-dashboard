class CreateProjectLinks < ActiveRecord::Migration[8.0]
  def change
    create_table :project_links do |t|
      t.references :project, null: false, foreign_key: true
      t.string :title, null: false
      t.string :url, null: false
      t.integer :position, default: 0, null: false

      t.timestamps
    end
  end
end
