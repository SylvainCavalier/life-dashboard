class AddPaymentDetailsToInvoices < ActiveRecord::Migration[8.0]
  def change
    add_column :invoices, :payment_method, :string
    add_column :invoices, :paid_at, :date
  end
end
