class AddCompanyRefToDocuments < ActiveRecord::Migration[8.0]
  def change
    add_reference :documents, :company, null: true, foreign_key: true
  end
end
