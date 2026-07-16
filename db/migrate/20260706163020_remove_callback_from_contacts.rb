class RemoveCallbackFromContacts < ActiveRecord::Migration[8.0]
  def change
    remove_index :contacts, :callback_pending
    remove_column :contacts, :callback_pending, :boolean, default: false, null: false
    remove_column :contacts, :callback_on, :date
  end
end
