class AddExtraFieldsToContacts < ActiveRecord::Migration[8.0]
  def change
    add_column :contacts, :notes, :text
    add_column :contacts, :likes, :text
    add_column :contacts, :dislikes, :text
    add_column :contacts, :loans, :text
  end
end
