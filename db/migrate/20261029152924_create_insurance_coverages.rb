class CreateInsuranceCoverages < ActiveRecord::Migration[8.0]
  def change
    create_table :insurance_coverages do |t|
      t.references :insurance, null: false, foreign_key: true
      t.string :name, null: false
      t.boolean :included, null: false, default: true
      t.string :ceiling
      t.string :deductible
      t.text :conditions
      t.integer :position, null: false, default: 0

      t.timestamps
    end
  end
end
