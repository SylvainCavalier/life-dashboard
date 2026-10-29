class AddInsuranceToDocuments < ActiveRecord::Migration[8.0]
  def change
    add_reference :documents, :insurance, foreign_key: { on_delete: :nullify }
  end
end
