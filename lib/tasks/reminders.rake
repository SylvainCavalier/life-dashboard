# Module Rappels : configuration des notifications push et points d'entree scriptables.
namespace :reminders do
  desc "Genere une paire de cles VAPID a poser en variables d'environnement : rake reminders:vapid_keys"
  task vapid_keys: :environment do
    key = WebPush.generate_key
    puts "VAPID_PUBLIC_KEY=#{key.public_key}"
    puts "VAPID_PRIVATE_KEY=#{key.private_key}"
    puts
    puts "A ne generer qu'une fois : changer de cles invalide tous les abonnements (il faut reactiver"
    puts "les notifications sur chaque appareil)."
  end

  desc "Configuration push, appareils abonnes, mail de secours, rappels en attente : rake reminders:check"
  task check: :environment do
    puts "VAPID_PUBLIC_KEY / PRIVATE  #{PushNotifications.configured? ? 'ok' : 'ABSENTES (rake reminders:vapid_keys)'}"
    puts "VAPID_SUBJECT               #{PushNotifications.subject || 'ABSENT (VAPID_SUBJECT ou GMAIL_USER)'}"
    puts "Mail de secours             #{Reminders::EmailFallback.available? ? "ok, vers #{Reminders::EmailFallback.recipient}" : 'indisponible (Gmail non configure)'}"
    puts "Appareils abonnes           #{PushSubscription.count}"
    PushSubscription.find_each do |subscription|
      state = subscription.last_error.present? ? "ECHEC : #{subscription.last_error}" : "dernier envoi #{subscription.last_success_at&.strftime('%d/%m %H:%M') || 'jamais'}"
      puts "  - ##{subscription.id} #{subscription.device_label} (#{state})"
    end
    puts "Rappels en cours            #{Reminder.active.count} (dont #{Reminder.due.count} echu(s))"
  end

  desc "Envoie une notification de test a tous les appareils : rake reminders:test"
  task test: :environment do
    abort PushNotifications::NOT_CONFIGURED unless PushNotifications.configured?

    reached = PushNotifications.broadcast(title: "Notification de test", body: "Envoyee depuis le terminal.", url: "/reminders", tag: "reminder-test")
    puts "#{reached} appareil(s) atteint(s) sur #{PushSubscription.count}"
  end

  desc "Traite immediatement les rappels echus, sans attendre le cron : rake reminders:dispatch_now"
  task dispatch_now: :environment do
    ReminderDispatchJob.perform_now
    puts "Rappels echus restant sans reponse : #{Reminder.due.where(acknowledged_at: nil).count}"
  end
end
