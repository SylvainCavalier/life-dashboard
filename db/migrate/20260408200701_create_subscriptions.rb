class CreateSubscriptions < ActiveRecord::Migration[8.0]
  def change
    create_table :subscriptions do |t|
      t.string :name, null: false
      t.decimal :cost, precision: 8, scale: 2, null: false
      t.string :billing_cycle, null: false, default: 'monthly'
      t.string :category
      t.date :start_date
      t.date :end_date
      t.string :url

      t.timestamps
    end
  end
end
