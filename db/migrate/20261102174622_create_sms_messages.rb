class CreateSmsMessages < ActiveRecord::Migration[8.0]
  def change
    create_table :sms_messages do |t|
      t.references :sms_correspondent, null: false, foreign_key: { on_delete: :cascade }
      t.string :direction, null: false
      t.text :body, null: false
      t.string :status, null: false
      t.string :twilio_sid
      t.text :error

      t.timestamps
    end
    add_index :sms_messages, :twilio_sid, unique: true
    add_index :sms_messages, [:sms_correspondent_id, :created_at]
  end
end
