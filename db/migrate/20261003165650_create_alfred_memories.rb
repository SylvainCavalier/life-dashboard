class CreateAlfredMemories < ActiveRecord::Migration[8.0]
  def change
    create_table :alfred_memories do |t|
      t.text :content, null: false
      t.string :category, null: false, default: "other"
      t.string :subject_type
      t.bigint :subject_id

      t.timestamps
    end
    add_index :alfred_memories, :category
  end
end
