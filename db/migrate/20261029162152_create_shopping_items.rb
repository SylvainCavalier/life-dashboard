class CreateShoppingItems < ActiveRecord::Migration[8.0]
  def change
    create_table :shopping_items do |t|
      t.string :name, null: false
      t.datetime :checked_at

      t.timestamps
    end
    add_index :shopping_items, "lower(name)", unique: true, name: "index_shopping_items_on_lower_name"
  end
end
