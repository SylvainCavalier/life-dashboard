class CreateScripts < ActiveRecord::Migration[8.0]
  def change
    create_table :scripts do |t|
      t.references :script_folder, foreign_key: { on_delete: :nullify }
      t.string :title, null: false
      t.string :kind, null: false, default: "video"
      t.string :status, null: false, default: "idea"
      t.text :body, null: false, default: ""
      t.text :notes
      t.date :planned_on
      t.date :published_on
      t.string :published_url
      t.timestamps
    end
    add_index :scripts, :status
    add_index :scripts, :updated_at
  end
end
