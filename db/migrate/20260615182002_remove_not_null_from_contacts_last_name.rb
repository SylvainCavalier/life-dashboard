class RemoveNotNullFromContactsLastName < ActiveRecord::Migration[8.0]
  def change
    change_column_null :contacts, :last_name, true
  end
end
