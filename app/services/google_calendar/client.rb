require "google/apis/calendar_v3"
require "googleauth"

module GoogleCalendar
  # Enveloppe minimale de l'API Google Calendar : les erreurs de la gem sont
  # traduites en `Client::Error` (et `NotFound` pour un evenement disparu), le
  # reste du module ne connait pas Google::Apis.
  class Client
    class Error < StandardError; end
    class NotFound < Error; end

    PAGE_SIZE = 250

    def initialize(calendar_id: GoogleCalendar.calendar_id, credentials_json: GoogleCalendar.credentials_json)
      if calendar_id.blank? || credentials_json.blank?
        raise Error,
              "GOOGLE_CALENDAR_ID et GOOGLE_CALENDAR_CREDENTIALS sont requis"
      end

      @calendar_id = calendar_id
      @credentials_json = credentials_json
    end

    # Nom de l'agenda : sert de test de connexion (rake google_calendar:check).
    def calendar_name
      call { service.get_calendar(@calendar_id).summary }
    rescue NotFound
      # Google repond 404 (et non 403) pour un agenda auquel on n'a pas acces.
      raise Error, "agenda '#{@calendar_id}' invisible pour le compte de service : est-il partage avec lui " \
                   "en « modifier les evenements » ? (compte Workspace : le partage externe doit etre autorise " \
                   "dans la console d'administration)"
    end

    # Toutes les occurrences (recurrences developpees) chevauchant la fenetre,
    # page par page. Les evenements annules ne sont pas renvoyes.
    def each_event(time_min:, time_max:, &block)
      page_token = nil
      loop do
        page = call do
          service.list_events(@calendar_id, single_events: true, show_deleted: false, max_results: PAGE_SIZE,
                                            time_min: time_min.iso8601, time_max: time_max.iso8601,
                                            page_token: page_token)
        end
        page.items.to_a.each(&block)
        page_token = page.next_page_token
        break if page_token.blank?
      end
    end

    def insert(google_event)
      call { service.insert_event(@calendar_id, google_event) }
    end

    # PUT complet et non PATCH : la gem n'envoie pas les champs nil, un PATCH ne
    # saurait donc pas effacer une description ou un lieu.
    def update(google_id, google_event)
      call { service.update_event(@calendar_id, google_id, google_event) }
    end

    def delete(google_id)
      call { service.delete_event(@calendar_id, google_id) }
    end

    private

    def service
      @service ||= Google::Apis::CalendarV3::CalendarService.new.tap do |svc|
        svc.client_options.application_name = "Life Dashboard"
        svc.request_options.retries = 2
        svc.authorization = GoogleServiceAccount.credentials(scope: SCOPE, json: @credentials_json)
      end
    end

    def call
      yield
    rescue Google::Apis::AuthorizationError, Signet::AuthorizationError => e
      raise Error, "Google Calendar : acces refuse (#{e.message.truncate(120)}). L'agenda est-il partage avec le compte de service ?"
    rescue Google::Apis::ClientError => e
      raise NotFound, "Google Calendar : evenement introuvable" if [404, 410].include?(e.status_code)

      raise Error, "Google Calendar : #{e.message}"
    rescue Google::Apis::Error => e
      raise Error, "Google Calendar : #{e.message}"
    end
  end
end
