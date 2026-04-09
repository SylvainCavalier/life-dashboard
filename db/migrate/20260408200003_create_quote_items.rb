class CreateQuoteItems < ActiveRecord::Migration[8.0]
  def change
    create_table :quote_items do |t|
      t.references :quote, null: false, foreign_key: true

      t.string :description, null: false
      t.decimal :quantity, precision: 10, scale: 2, null: false, default: 1
      t.string :unit, default: "unite"
      t.decimal :unit_price, precision: 10, scale: 2, null: false
      t.decimal :total_ht, precision: 10, scale: 2, null: false
      t.integer :position, default: 0

      t.timestamps
    end
  end
end
