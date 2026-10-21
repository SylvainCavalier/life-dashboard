class CreateProjectEntries < ActiveRecord::Migration[8.0]
  def change
    create_table :project_entries do |t|
      t.references :project, null: false, foreign_key: true
      t.references :contact, foreign_key: { on_delete: :nullify }
      t.date :occurred_on, null: false
      t.string :kind, null: false, default: "travail"
      t.string :title, null: false
      t.text :body
      t.timestamps
    end
    add_index :project_entries, [:project_id, :occurred_on]
  end
end
