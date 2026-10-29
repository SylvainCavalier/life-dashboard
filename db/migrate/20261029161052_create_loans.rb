class CreateLoans < ActiveRecord::Migration[8.0]
  def change
    create_table :loans do |t|
      t.string :direction, null: false
      t.string :kind, null: false, default: "object"
      t.references :contact, foreign_key: { on_delete: :nullify }
      t.string :person_name, null: false
      t.string :item
      t.decimal :amount, precision: 10, scale: 2
      t.decimal :repaid_amount, precision: 10, scale: 2
      t.date :started_on, null: false
      t.date :due_on
      t.date :returned_on
      t.text :notes

      t.timestamps
    end
    add_index :loans, :returned_on
  end
end
