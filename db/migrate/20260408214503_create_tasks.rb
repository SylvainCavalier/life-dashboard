class CreateTasks < ActiveRecord::Migration[8.0]
  def change
    create_table :tasks do |t|
      t.string :description, null: false
      t.integer :priority, null: false, default: 3
      t.date :deadline
      t.boolean :completed, null: false, default: false

      t.timestamps
    end

    add_index :tasks, :priority
    add_index :tasks, :completed
  end
end
