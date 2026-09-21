# Gestion du compte unique de l'application. Il n'y a ni page d'inscription ni
# mailer de reinitialisation : tout passe par ces taches, en local ou via
# `heroku run rails owner:bootstrap`.
namespace :owner do
  desc "Cree le compte avec le mot de passe de bootstrap, a changer a la premiere connexion"
  task bootstrap: :environment do
    abort "Un compte existe deja (#{User.first.email})." if User.exists?

    user = User.bootstrap!
    puts "Compte cree : #{user.email}"
    puts "Mot de passe provisoire : #{User::BOOTSTRAP_PASSWORD}"
    puts
    puts "L'application bloquera sur /account/password tant qu'il n'aura pas ete"
    puts "remplace. Connecte-toi maintenant : ce mot de passe est faible et le"
    puts "site est expose."
  end

  desc "Cree le compte proprietaire avec un mot de passe saisi a la main"
  task create: :environment do
    abort "Un compte existe deja (#{User.first.email}). Utilise owner:reset_password." if User.exists?

    email = prompt("Email : ")
    password = prompt_secret("Mot de passe (#{Devise.password_length.min} caracteres minimum) : ")
    confirmation = prompt_secret("Confirmation : ")
    abort "Les mots de passe ne correspondent pas." unless password == confirmation

    user = User.new(email: email, password: password)
    abort "Echec : #{user.errors.full_messages.join(', ')}" unless user.save

    puts "Compte cree pour #{user.email}."
  end

  desc "Change le mot de passe du compte proprietaire"
  task reset_password: :environment do
    user = User.first or abort "Aucun compte. Lance d'abord owner:bootstrap."

    password = prompt_secret("Nouveau mot de passe (#{Devise.password_length.min} caracteres minimum) : ")
    confirmation = prompt_secret("Confirmation : ")
    abort "Les mots de passe ne correspondent pas." unless password == confirmation

    user.password = password
    abort "Echec : #{user.errors.full_messages.join(', ')}" unless user.save

    user.update_column(:must_change_password, false)
    puts "Mot de passe mis a jour pour #{user.email}."
  end

  desc "Force le changement de mot de passe a la prochaine connexion"
  task force_password_change: :environment do
    user = User.first or abort "Aucun compte."
    user.update_column(:must_change_password, true)
    puts "#{user.email} devra choisir un nouveau mot de passe a la prochaine connexion."
  end

  desc "Deverrouille le compte apres trop de tentatives de connexion echouees"
  task unlock: :environment do
    user = User.first or abort "Aucun compte."
    user.unlock_access!
    puts "Compte #{user.email} deverrouille."
  end

  def prompt(label)
    print label
    $stdin.gets.to_s.strip
  end

  def prompt_secret(label)
    require "io/console"
    print label
    value = $stdin.noecho(&:gets).to_s.strip
    puts
    value
  rescue Errno::ENOTTY, IO::EAGAINWaitReadable
    # Pas de TTY (pipe, CI) : on retombe sur une saisie visible.
    $stdin.gets.to_s.strip
  end
end
