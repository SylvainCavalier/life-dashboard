# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# --- Compte proprietaire ---------------------------------------------------
#
# L'application est mono-utilisateur et n'a aucune page d'inscription : sans ce
# compte, impossible de se connecter.
#
# Le mot de passe pose ici est un mot de passe de bootstrap, identique en
# developpement et en production. Il est marque `must_change_password`, donc
# l'application bloque sur /account/password tant qu'il n'a pas ete remplace :
# il ne peut servir qu'une seule fois.
#
# En production, preferer `rails owner:bootstrap`, qui fait la meme chose sans
# dependre de db:seed.
if User.exists?
  puts "Compte deja present (#{User.first.email}) — seed ignoree."
else
  user = User.bootstrap!
  puts "Compte cree :"
  puts "  email        #{user.email}"
  puts "  mot de passe #{User::BOOTSTRAP_PASSWORD}"
  puts "  a changer obligatoirement a la premiere connexion"
end
