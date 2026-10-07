class CreateCvPitches < ActiveRecord::Migration[8.0]
  def change
    create_table :cv_pitches do |t|
      t.string :title, null: false
      t.text :content, null: false
      t.integer :position, null: false, default: 0

      t.timestamps
    end
    add_index :cv_pitches, :position
  end
end
