class CreateCvFormations < ActiveRecord::Migration[8.0]
  def change
    create_table :cv_formations do |t|
      t.string :title, null: false
      t.string :institution
      t.string :category, null: false, default: "diplome"
      t.string :location
      t.date :start_date
      t.date :end_date
      t.text :description
      t.integer :position, default: 0, null: false

      t.timestamps
    end

    add_index :cv_formations, :category
    add_index :cv_formations, :start_date
    add_index :cv_formations, :position
  end
end
