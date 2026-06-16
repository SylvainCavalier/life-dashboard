class AddClientRefToInvoices < ActiveRecord::Migration[8.0]
  def change
    add_reference :invoices, :client, null: true, foreign_key: true
  end
end
