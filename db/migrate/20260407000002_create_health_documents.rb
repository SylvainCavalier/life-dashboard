class CreateHealthDocuments < ActiveRecord::Migration[8.0]
  def change
    create_table :health_documents do |t|
      t.references :health_profile, null: false, foreign_key: true
      t.string :name, null: false
      t.string :category
      t.date :document_date
      t.text :notes

      t.timestamps
    end
  end
end
