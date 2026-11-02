class AddSmsToAlfred < ActiveRecord::Migration[8.0]
  def change
    add_reference :alfred_conversations, :sms_correspondent, foreign_key: { on_delete: :nullify }
    add_column :alfred_settings, :sms_public_facts, :text
  end
end
