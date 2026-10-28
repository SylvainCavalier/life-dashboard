# Comptes d'amis : acces aux seules pages Outils, Downloader et Transfert, avec leurs
# propres donnees (voir ApplicationController#restrict_friends! et le concern UserOwned).
# Pas d'inscription ni de mot de passe oublie : tout passe par ces taches, en local ou via
# `heroku run rails friends:create EMAIL=...`.
namespace :friends do
  find_friend = lambda do
    email = ENV["EMAIL"].presence || abort("EMAIL manquant : rails friends:<tache> EMAIL=ami@example.com")
    User.friends.find_by("lower(email) = ?", email.downcase) || abort("Aucun compte d'ami pour #{email}")
  end

  desc "Cree un compte d'ami avec un mot de passe provisoire : rails friends:create EMAIL=ami@example.com"
  task create: :environment do
    email = ENV["EMAIL"].presence || abort("EMAIL manquant : rails friends:create EMAIL=ami@example.com")
    user, password = User.create_friend!(email: email)
    puts "Compte d'ami cree : #{user.email}"
    puts "Mot de passe provisoire : #{password}"
    puts "A transmettre par un canal sur ; il devra le changer a la premiere connexion."
  rescue ActiveRecord::RecordInvalid => e
    abort "Echec : #{e.record.errors.full_messages.to_sentence}"
  end

  desc "Liste les comptes d'amis et ce qu'ils occupent"
  task list: :environment do
    friends = User.friends.order(:email)
    abort "Aucun compte d'ami." if friends.empty?

    friends.each do |user|
      cloud_bytes = ActiveStorage::Blob.joins(:attachments)
                                       .where(active_storage_attachments: { record_type: "VideoDownload", record_id: user.video_downloads.select(:id) })
                                       .sum(:byte_size)
      puts [
        user.email,
        "derniere connexion #{user.last_sign_in_at&.strftime('%d/%m/%Y %H:%M') || 'jamais'}",
        "#{user.video_downloads.count} telechargement(s) (#{ActiveSupport::NumberHelper.number_to_human_size(cloud_bytes)} sur le bucket)",
        "#{user.file_transfers.active.count} transfert(s) actif(s)",
        "#{user.video_transcripts.count} transcription(s)",
        (user.access_locked? ? "VERROUILLE" : nil),
        (user.must_change_password? ? "mot de passe provisoire" : nil)
      ].compact.join(" | ")
    end
  end

  desc "Nouveau mot de passe provisoire pour un ami : rails friends:reset_password EMAIL=..."
  task reset_password: :environment do
    user = find_friend.call
    password = SecureRandom.alphanumeric(20)
    user.update!(password: password, must_change_password: true)
    user.unlock_access! if user.access_locked?
    puts "Mot de passe provisoire de #{user.email} : #{password}"
  end

  desc "Deverrouille un compte d'ami apres trop d'echecs de connexion : rails friends:unlock EMAIL=..."
  task unlock: :environment do
    user = find_friend.call
    user.unlock_access!
    puts "Compte #{user.email} deverrouille."
  end

  desc "Supprime un compte d'ami ET toutes ses donnees (fichiers compris) : rails friends:destroy EMAIL=... CONFIRM=1"
  task destroy: :environment do
    user = find_friend.call
    summary = "#{user.video_downloads.count} telechargement(s), #{user.file_transfers.count} transfert(s), " \
              "#{user.video_transcripts.count} transcription(s), #{user.video_folders.count} dossier(s)"
    abort "Supprimerait #{user.email} et #{summary}. Relancer avec CONFIRM=1." unless ENV["CONFIRM"] == "1"

    user.destroy!
    puts "Compte #{user.email} supprime avec #{summary}."
  end
end
