class CreateUsefulSites < ActiveRecord::Migration[8.0]
  def change
    create_table :useful_sites do |t|
      t.string :name, null: false
      t.string :url, null: false
      t.string :description
      t.string :category, null: false

      t.timestamps
    end

    add_index :useful_sites, :category
  end
end
