class CreateMailAccounts < ActiveRecord::Migration[8.0]
  def change
    create_table :mail_accounts do |t|
      t.string :email, null: false
      t.string :provider, null: false
      t.string :provider_url, null: false
      t.string :password
      t.string :imap_server
      t.integer :imap_port
      t.string :smtp_server
      t.integer :smtp_port

      t.timestamps
    end

    add_index :mail_accounts, :email, unique: true
  end
end
