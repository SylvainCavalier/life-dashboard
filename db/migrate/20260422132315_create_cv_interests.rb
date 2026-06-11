class CreateCvInterests < ActiveRecord::Migration[8.0]
  def change
    create_table :cv_interests do |t|
      t.string :name, null: false
      t.text :description
      t.integer :position, default: 0, null: false

      t.timestamps
    end

    add_index :cv_interests, :position
  end
end
