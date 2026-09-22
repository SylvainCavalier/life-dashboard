module GoogleCalendar
  # Traduction Event <-> evenement Google (objets Google::Apis::CalendarV3).
  #
  # Conventions :
  # - journee entiere : Google donne `start.date` et `end.date` (exclusive) ;
  #   localement `start_time` est minuit heure de Paris et `end_time`, s'il y
  #   en a un, le minuit du DERNIER jour (inclusif) ;
  # - `end_time` nul localement = une heure par defaut cote Google (une fin est
  #   obligatoire la-bas) ; une fin Google qui n'est pas apres le debut devient
  #   nulle ici (le modele la refuserait) ;
  # - le type local voyage dans une propriete privee de l'evenement Google pour
  #   survivre a l'aller-retour ; un evenement ne en venant de Google n'en a pas,
  #   il est classe « visio » s'il porte un lien de visioconference, « autre » sinon ;
  # - les rappels ne sont pas synchronises : ceux que voit l'API sont ceux du
  #   compte de service, pas ceux de Sylvain. `reminder_minutes` reste local.
  module EventMapper
    EVENT_TYPE_KEY = "life_dashboard_event_type".freeze
    EVENT_ID_KEY = "life_dashboard_id".freeze
    DEFAULT_DURATION = 1.hour

    module_function

    def to_google(event)
      google_event = Google::Apis::CalendarV3::Event.new(
        summary: event.title,
        description: event.description.presence,
        location: event.location.presence,
        extended_properties: Google::Apis::CalendarV3::Event::ExtendedProperties.new(
          private: { EVENT_TYPE_KEY => event.event_type, EVENT_ID_KEY => event.id.to_s }
        )
      )

      if event.all_day
        start_date = event.start_time.in_time_zone(TIME_ZONE).to_date
        last_date = [event.end_time&.in_time_zone(TIME_ZONE)&.to_date, start_date].compact.max
        google_event.start = Google::Apis::CalendarV3::EventDateTime.new(date: start_date)
        google_event.end = Google::Apis::CalendarV3::EventDateTime.new(date: last_date + 1)
      else
        # La gem ne serialise correctement qu'un DateTime : un TimeWithZone
        # partirait en "2026-09-25 16:00:00 +0200" et Google repondrait 400.
        start_time = event.start_time.in_time_zone(TIME_ZONE)
        end_time = event.end_time&.in_time_zone(TIME_ZONE) || (start_time + DEFAULT_DURATION)
        google_event.start = Google::Apis::CalendarV3::EventDateTime.new(date_time: start_time.to_datetime,
                                                                         time_zone: TIME_ZONE)
        google_event.end = Google::Apis::CalendarV3::EventDateTime.new(date_time: end_time.to_datetime,
                                                                       time_zone: TIME_ZONE)
      end

      google_event
    end

    # Attributs a poser sur l'Event local. `event_type` n'y figure que si Google
    # le connait (propriete privee) : une mise a jour venue de Google ne doit pas
    # ecraser un classement fait dans l'application.
    def attributes_from(google_event)
      attrs = {
        title: google_event.summary.presence || "(Sans titre)",
        description: google_event.description.presence,
        location: google_event.location.presence || google_event.hangout_link.presence,
        google_event_id: google_event.id,
        google_updated_at: to_time(google_event.updated)
      }

      if google_event.start&.date.present?
        start_date = to_date(google_event.start.date)
        last_date = google_event.end&.date.present? ? to_date(google_event.end.date) - 1 : start_date
        attrs[:all_day] = true
        attrs[:start_time] = start_date.in_time_zone(TIME_ZONE)
        attrs[:end_time] = last_date > start_date ? last_date.in_time_zone(TIME_ZONE) : nil
      else
        start_time = to_time(google_event.start&.date_time)
        end_time = to_time(google_event.end&.date_time)
        attrs[:all_day] = false
        attrs[:start_time] = start_time
        attrs[:end_time] = end_time && start_time && end_time > start_time ? end_time : nil
      end

      known_type = google_event.extended_properties&.private&.dig(EVENT_TYPE_KEY)
      if Event::EVENT_TYPES.include?(known_type)
        attrs[:event_type] = known_type
        attrs[:color] = Event::EVENT_TYPE_COLORS[known_type]
      end

      attrs
    end

    # Type a donner a un evenement qui nait de Google (sans propriete privee).
    def default_event_type(google_event)
      google_event.hangout_link.present? || google_event.conference_data.present? ? "visio" : "autre"
    end

    def to_time(value)
      return nil if value.blank?

      value.respond_to?(:to_time) ? value.to_time.in_time_zone(TIME_ZONE) : Time.zone.parse(value.to_s)
    end

    def to_date(value)
      value.is_a?(Date) ? value : Date.parse(value.to_s)
    end
  end
end
