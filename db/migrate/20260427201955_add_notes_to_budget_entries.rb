class AddNotesToBudgetEntries < ActiveRecord::Migration[8.0]
  def change
    add_column :budget_entries, :notes, :text
  end
end
