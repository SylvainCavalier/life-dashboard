class AddFollowedToContacts < ActiveRecord::Migration[8.0]
  def change
    add_column :contacts, :followed, :boolean, default: false, null: false
  end
end
