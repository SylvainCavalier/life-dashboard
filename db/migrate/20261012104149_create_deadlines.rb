class CreateDeadlines < ActiveRecord::Migration[8.0]
  def change
    create_table :deadlines do |t|
      t.string :title, null: false
      t.string :category, null: false, default: "autre"
      t.date :due_on, null: false
      t.string :recurrence, null: false, default: "none"
      t.date :ends_on
      t.decimal :amount, precision: 10, scale: 2
      t.text :notes
      # Derniere date jusqu'a laquelle les occurrences ont ete posees dans l'agenda.
      t.date :generated_until

      t.timestamps
    end
    add_index :deadlines, :due_on
  end
end
