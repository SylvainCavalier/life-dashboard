module Reminders
  # Dernier recours quand les notifications push sont restees sans reponse (ou
  # qu'aucun appareil n'est abonne) : un mail envoye par la boite Gmail d'Alfred.
  # Destinataire : REMINDER_EMAIL_TO, a defaut GMAIL_USER (Gmail affiche un mail
  # envoye a soi-meme dans la boite de reception, mais deja lu : d'ou la variable,
  # pour viser une autre adresse dont l'iPhone notifie les mails).
  module EmailFallback
    module_function

    def recipient
      ENV["REMINDER_EMAIL_TO"].presence || Gmail.user
    end

    def available?
      Gmail.enabled? && recipient.present?
    end

    # Renvoie true si le mail est parti.
    def deliver(reminder)
      return false unless available?

      mail = Gmail::Composer.build(from: Gmail.user, to: recipient, subject: "Rappel : #{reminder.title}", body: body(reminder))
      Gmail.client.send_message(mail)
      true
    rescue Gmail::Client::Error, Google::Apis::Error => e
      Rails.logger.error "[Reminders::EmailFallback] rappel ##{reminder.id} : #{e.message}"
      false
    end

    def body(reminder)
      lines = ["Rappel prévu le #{Reminder.human_time(reminder.remind_at)}, resté sans réponse sur les notifications.", "", reminder.title]
      lines += ["", reminder.notes] if reminder.notes.present?
      if (linked = reminder.remindable_summary)
        lines += ["", "Concerne : #{linked[:label]}"]
      end
      host = ENV["APP_HOST"].presence
      lines += ["", "Marquer comme fait ou reporter : https://#{host}/reminders?open=#{reminder.id}"] if host
      lines += ["", "-- ", "Alfred, depuis le Life Dashboard"]
      lines.join("\n")
    end
  end
end
