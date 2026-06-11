class CreateCvExperiences < ActiveRecord::Migration[8.0]
  def change
    create_table :cv_experiences do |t|
      t.string :title, null: false
      t.string :company, null: false
      t.string :location
      t.date :start_date, null: false
      t.date :end_date
      t.text :description
      t.integer :position, default: 0, null: false

      t.timestamps
    end

    add_index :cv_experiences, :start_date
    add_index :cv_experiences, :position
  end
end
