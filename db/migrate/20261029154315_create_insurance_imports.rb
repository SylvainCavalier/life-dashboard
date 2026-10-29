class CreateInsuranceImports < ActiveRecord::Migration[8.0]
  def change
    create_table :insurance_imports do |t|
      t.string :status, null: false, default: "pending"
      t.jsonb :draft
      t.string :extractor
      t.text :error
      t.datetime :finished_at

      t.timestamps
    end
  end
end
