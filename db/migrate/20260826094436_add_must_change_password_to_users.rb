# Le compte est cree avec un mot de passe de bootstrap, connu et volontairement
# simple. Ce drapeau force son remplacement des la premiere connexion : tant
# qu'il est vrai, toute l'application redirige vers /account/password.
class AddMustChangePasswordToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :must_change_password, :boolean, default: false, null: false
  end
end
