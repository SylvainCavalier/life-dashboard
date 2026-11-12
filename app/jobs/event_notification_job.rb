# Cron toutes les minutes : previent d'un rendez-vous `reminder_minutes` avant
# (1 h par defaut) par une notification push sur les appareils abonnes (voir
# PushNotifications et la page Rappels). Une seule notification par horaire, sans
# relance ni mail de secours : c'est un avertissement, pas un rappel a acquitter.
#
# La table fait foi (`events.notified_at`) : un dyno qui redemarre rattrape au
# passage suivant tout ce qui n'a pas commence. Le verrou de ligne evite un double
# envoi si deux passages se chevauchent.
class EventNotificationJob < ApplicationJob
  queue_as :default

  def perform(now = Time.current)
    return unless PushNotifications.configured?

    Event.notification_due(now).ordered.find_each do |event|
      event.with_lock do
        next if event.notified_at.present?

        PushNotifications.broadcast(event.notification_payload(now))
        # update_columns : ni push vers Google, ni reindexation du corpus.
        event.update_columns(notified_at: now)
      end
    rescue StandardError => e
      Rails.logger.error "[EventNotificationJob] evenement ##{event.id} : #{e.class} #{e.message}"
    end
  end
end
