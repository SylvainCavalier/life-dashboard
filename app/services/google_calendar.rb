# Synchronisation bidirectionnelle de l'agenda avec Google Calendar.
#
# L'application parle a l'API avec un compte de service Google Cloud (cle JSON
# dans GOOGLE_CALENDAR_CREDENTIALS) auquel l'agenda vise (GOOGLE_CALENDAR_ID,
# en general l'adresse Gmail) a ete partage avec le droit « modifier les
# evenements ». Pas de flux OAuth, pas de jeton qui expire.
#
# Google fait foi : `GoogleCalendar::Sync#pull!` (cron GoodJob + bouton de la
# page Agenda) recopie l'agenda Google dans la table `events` sur une fenetre
# glissante, et tout evenement cree, modifie ou supprime dans l'application
# (interface, Alfred, skill write) est pousse vers Google par
# `GoogleCalendarPushJob` (callbacks d'`Event`).
module GoogleCalendar
  TIME_ZONE = "Europe/Paris".freeze
  SCOPE = "https://www.googleapis.com/auth/calendar".freeze

  module_function

  def enabled?
    credentials_json.present? && calendar_id.present?
  end

  def calendar_id
    ENV["GOOGLE_CALENDAR_ID"].presence
  end

  def credentials_json
    GoogleServiceAccount.credentials_json
  end

  # Adresse du compte de service, celle a laquelle partager l'agenda.
  def service_account_email
    GoogleServiceAccount.client_email
  end
end
