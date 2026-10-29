class CreateShoppingPresets < ActiveRecord::Migration[8.0]
  def change
    create_table :shopping_presets do |t|
      t.string :name, null: false
      t.string :icon

      t.timestamps
    end
    add_index :shopping_presets, "lower(name)", unique: true, name: "index_shopping_presets_on_lower_name"
  end
end
