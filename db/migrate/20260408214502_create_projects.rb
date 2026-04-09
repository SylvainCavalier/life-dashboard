class CreateProjects < ActiveRecord::Migration[8.0]
  def change
    create_table :projects do |t|
      t.string :name
      t.text :description
      t.string :status, default: 'en_cours'
      t.integer :priority, default: 0
      t.integer :progress, default: 0
      t.string :github_url
      t.string :site_url
      t.text :notes

      t.timestamps
    end
  end
end
