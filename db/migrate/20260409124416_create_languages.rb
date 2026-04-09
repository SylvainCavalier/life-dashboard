class CreateLanguages < ActiveRecord::Migration[8.0]
  def change
    create_table :languages do |t|
      t.string :name, null: false
      t.string :level, null: false, default: "A1"
      t.string :color, default: "#6366f1"
      t.string :flag_emoji
      t.text :notes

      t.timestamps
    end

    add_index :languages, :name, unique: true
  end
end
