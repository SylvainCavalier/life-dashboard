# Cron toutes les minutes : envoie les rappels arrives a echeance. Pour chaque
# occurrence : une notification push, deux relances espacees de
# Reminder::RETRY_INTERVAL tant qu'elle n'est pas ouverte, puis un mail
# (Reminders::EmailFallback). Sans appareil abonne, le mail part tout de suite.
#
# Un redemarrage du dyno ne perd rien : la table fait foi et le passage suivant
# rattrape ce qui est echu. Le verrou de ligne evite un double envoi si deux
# passages se chevauchent.
class ReminderDispatchJob < ApplicationJob
  queue_as :default

  def perform(now = Time.current)
    Reminder.due(now).ordered.find_each do |reminder|
      reminder.with_lock { dispatch(reminder, now) }
    rescue StandardError => e
      Rails.logger.error "[ReminderDispatchJob] rappel ##{reminder.id} : #{e.class} #{e.message}"
    end
  end

  private

  def dispatch(reminder, now)
    reminder.catch_up!(now)

    case reminder.delivery_step(now)
    when :push then push(reminder, now)
    when :email then email(reminder, now)
    end
  end

  def push(reminder, now)
    attempts = reminder.attempts + 1
    reached = PushNotifications.broadcast(reminder.push_payload.merge(renotify: attempts > 1))
    # update_columns : pas de callbacks (ni reindexation du corpus a chaque relance).
    reminder.update_columns(attempts: attempts, notified_at: reminder.notified_at || now, last_attempt_at: now)
    return if reached.positive?

    # Personne n'a recu la notification : inutile d'attendre les relances.
    reminder.update_columns(attempts: Reminder::MAX_PUSHES)
    email(reminder, now)
  end

  def email(reminder, now)
    sent = Reminders::EmailFallback.deliver(reminder)
    Rails.logger.warn "[ReminderDispatchJob] rappel ##{reminder.id} : ni notification ni mail possible" unless sent
    # Marque meme en cas d'echec : un mail par occurrence au plus, pas d'envoi en boucle.
    reminder.update_columns(email_sent_at: now, notified_at: reminder.notified_at || now)
  end
end
