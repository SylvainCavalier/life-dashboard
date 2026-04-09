class AddDiscountToQuoteItems < ActiveRecord::Migration[8.0]
  def change
    add_column :quote_items, :discount_type, :string, default: "none"
    add_column :quote_items, :discount_value, :decimal, precision: 10, scale: 2, default: 0
  end
end
