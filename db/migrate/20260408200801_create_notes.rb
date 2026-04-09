class CreateNotes < ActiveRecord::Migration[8.0]
  def change
    create_table :notes do |t|
      t.string :title, null: false
      t.text :content
      t.date :note_date, null: false, default: -> { "CURRENT_DATE" }
      t.boolean :important, default: false, null: false

      t.timestamps
    end

    add_index :notes, :note_date
    add_index :notes, :important
  end
end
