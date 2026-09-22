# Gmail d'Alfred : diagnostic et recherche hors interface.
namespace :gmail do
  desc "Configuration et connexion a la boite : rake gmail:check"
  task check: :environment do
    puts "GMAIL_USER          #{Gmail.user || 'ABSENT'}"
    puts "Compte de service   #{GoogleServiceAccount.configured? ? "ok (#{GoogleServiceAccount.client_email})" : 'CLE ABSENTE'}"
    puts "Delegation domaine  identifiant client #{GoogleServiceAccount.client_id}, scope #{Gmail::SCOPE}"
    abort "Gmail desactive : variables manquantes" unless Gmail.enabled?

    begin
      client = Gmail.client
      profile = client.profile
      puts "Boite               #{profile[:email]} : #{profile[:messages_total]} messages, #{profile[:threads_total]} fils"
      puts "Libelles            #{client.labels.count { |label| label[:type] == 'user' }} personnalise(s)"
    rescue Gmail::Client::Error => e
      abort "Connexion impossible : #{e.message}"
    end
  end

  desc "Recherche Gmail (syntaxe de la barre de recherche) : rake gmail:search Q='is:unread newer_than:7d'"
  task search: :environment do
    abort "Gmail desactive : variables manquantes" unless Gmail.enabled?

    threads = Gmail.client.search(ENV["Q"].to_s, max_results: ENV.fetch("N", 20))
    puts "#{threads.size} fil(s)"
    threads.each do |thread|
      flags = [("non lu" if thread[:unread]), ("etoile" if thread[:starred])].compact.join(", ")
      line = "#{thread[:date]&.first(10)}  #{thread[:thread_id]}  #{thread[:subject].truncate(60)}  <#{thread[:from]}>"
      line += "  [#{flags}]" if flags.present?
      puts line
    end
  end
end
