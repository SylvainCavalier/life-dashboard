class CreateInsuredItems < ActiveRecord::Migration[8.0]
  def change
    create_table :insured_items do |t|
      t.references :insurance, null: false, foreign_key: true
      t.references :property, foreign_key: { on_delete: :nullify }
      t.string :name, null: false
      t.string :kind, null: false, default: "autre"
      t.text :description
      t.decimal :value, precision: 12, scale: 2

      t.timestamps
    end
  end
end
