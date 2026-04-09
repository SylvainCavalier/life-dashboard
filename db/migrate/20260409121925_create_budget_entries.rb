class CreateBudgetEntries < ActiveRecord::Migration[8.0]
  def change
    create_table :budget_entries do |t|
      t.string :name, null: false
      t.string :entry_type, null: false
      t.string :recurrence, null: false, default: 'fixed'
      t.string :category
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.integer :month
      t.integer :year

      t.timestamps
    end

    add_index :budget_entries, [:entry_type, :recurrence]
    add_index :budget_entries, [:year, :month]
  end
end
