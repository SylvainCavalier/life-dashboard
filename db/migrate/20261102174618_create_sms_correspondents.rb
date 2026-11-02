class CreateSmsCorrespondents < ActiveRecord::Migration[8.0]
  def change
    create_table :sms_correspondents do |t|
      t.string :name, null: false
      t.string :phone, null: false
      t.references :contact, foreign_key: { on_delete: :nullify }
      t.boolean :owner, null: false, default: false
      t.boolean :enabled, null: false, default: true

      t.timestamps
    end
    add_index :sms_correspondents, :phone, unique: true
  end
end
