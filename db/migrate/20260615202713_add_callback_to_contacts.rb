class AddCallbackToContacts < ActiveRecord::Migration[8.0]
  def change
    add_column :contacts, :callback_pending, :boolean, default: false, null: false
    add_column :contacts, :callback_on, :date
    add_index :contacts, :callback_pending
  end
end
