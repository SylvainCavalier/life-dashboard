class CreateDocumentComparisons < ActiveRecord::Migration[8.0]
  def change
    create_table :document_comparisons do |t|
      t.references :user, null: false, foreign_key: true
      t.string :status, null: false, default: "pending"
      t.string :name_a
      t.string :name_b
      t.text :focus
      t.jsonb :result
      t.jsonb :extractors
      t.text :error
      t.datetime :finished_at

      t.timestamps
    end
  end
end
