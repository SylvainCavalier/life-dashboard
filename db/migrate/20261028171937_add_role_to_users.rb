# Deux sortes de comptes : le proprietaire (tout le dashboard) et les amis (Outils,
# Downloader, Transfert). Defaut "friend" : un compte cree sans preciser son role
# n'ouvre jamais les donnees personnelles. Les comptes existants sont le proprietaire.
class AddRoleToUsers < ActiveRecord::Migration[8.0]
  def up
    add_column :users, :role, :string, null: false, default: "friend"
    add_index :users, :role
    execute "UPDATE users SET role = 'owner'"
  end

  def down
    remove_index :users, :role
    remove_column :users, :role
  end
end
