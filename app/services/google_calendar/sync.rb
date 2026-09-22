module GoogleCalendar
  # La synchronisation elle-meme. Google fait foi.
  #
  # `pull!` (cron toutes les 10 min, bouton, rake) relit l'agenda Google sur une
  # fenetre glissante (3 mois en arriere, 2 ans en avant) sans jeton de synchro
  # incrementale : quelques centaines d'evenements au plus, un ou deux appels,
  # et aucun jeton qui expire. Pour chaque evenement Google : creation locale
  # s'il est inconnu, mise a jour si Google a change depuis la derniere synchro,
  # rien sinon. Un evenement local lie a Google, dans la fenetre, que Google ne
  # renvoie plus a ete supprime la-bas : il est supprime ici. Enfin les
  # evenements locaux jamais pousses (anterieurs a la synchro, ou dont le push a
  # echoue) sont envoyes : la relance est donc auto-reparatrice.
  #
  # Tout ce qui s'ecrit ici passe sous `Event.without_google_push` : la copie
  # locale d'un evenement Google ne doit pas repartir vers Google.
  class Sync
    WINDOW_PAST = 3.months
    WINDOW_FUTURE = 2.years
    # Marge sur les bords de la fenetre : Google filtre sur le chevauchement
    # (fin > timeMin, debut < timeMax), on ne supprime pas ce qui est a la limite.
    EDGE_MARGIN = 1.day

    Report = Struct.new(:pulled, :pushed, :deleted, :errors, keyword_init: true)

    attr_reader :client, :logger

    def initialize(client: Client.new, logger: Rails.logger)
      @client = client
      @logger = logger
    end

    def pull!
      now = Time.current
      window = (now - WINDOW_PAST)..(now + WINDOW_FUTURE)
      report = Report.new(pulled: 0, pushed: 0, deleted: 0, errors: [])
      seen_ids = Set.new

      client.each_event(time_min: window.begin, time_max: window.end) do |google_event|
        next if google_event.status == "cancelled" || google_event.id.blank?

        seen_ids << google_event.id
        report.pulled += 1 if mirror!(google_event)
      rescue ActiveRecord::RecordInvalid => e
        report.errors << "#{google_event.summary.to_s.truncate(40)} : #{e.message}"
      end

      report.deleted = remove_missing(window, seen_ids)

      Event.where(google_event_id: nil).find_each do |event|
        push!(event)
        report.pushed += 1
      rescue Client::Error => e
        report.errors << "#{event.title.truncate(40)} : #{e.message}"
      end

      report.errors.each { |message| logger.warn("[GoogleCalendar] #{message}") }
      report
    end

    # Cree ou remplace l'evenement cote Google et memorise son identifiant.
    # Un evenement supprime entre-temps chez Google est recree : il vient
    # d'etre modifie ici, c'est lui qui a raison.
    def push!(event)
      google_event = EventMapper.to_google(event)
      saved =
        if event.google_event_id.present?
          begin
            client.update(event.google_event_id, google_event)
          rescue Client::NotFound
            client.insert(google_event)
          end
        else
          client.insert(google_event)
        end
      event.update_columns(google_event_id: saved.id, google_updated_at: EventMapper.to_time(saved.updated))
      saved
    end

    def delete!(google_event_id)
      client.delete(google_event_id)
    rescue Client::NotFound
      nil
    end

    private

    # Recopie l'evenement Google en local : :created, :updated, ou nil si la
    # version connue est deja la bonne.
    def mirror!(google_event)
      attrs = EventMapper.attributes_from(google_event)
      event = Event.find_by(google_event_id: google_event.id)

      if event.nil?
        type = attrs[:event_type] || EventMapper.default_event_type(google_event)
        attrs = attrs.merge(event_type: type, color: Event::EVENT_TYPE_COLORS[type])
        Event.without_google_push { Event.create!(attrs) }
        :created
      elsif event.google_updated_at.nil? || attrs[:google_updated_at].nil? ||
            attrs[:google_updated_at] > event.google_updated_at
        Event.without_google_push { event.update!(attrs) }
        :updated
      end
    end

    def remove_missing(window, seen_ids)
      inner = (window.begin + EDGE_MARGIN)..(window.end - EDGE_MARGIN)
      missing = Event.where.not(google_event_id: nil).where(start_time: inner)
      missing = missing.where.not(google_event_id: seen_ids.to_a) if seen_ids.any?
      count = 0
      missing.find_each do |event|
        Event.without_google_push { event.destroy! }
        count += 1
      end
      count
    end
  end
end
