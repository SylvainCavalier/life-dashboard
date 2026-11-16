module Projects
  # Entrees du journal de bord ecrites sans que Sylvain ait a les dicter :
  # - un rendez-vous de l'agenda rattache a un projet, une fois passe (ProjectJournalJob) ;
  # - une reunion traitee (MeetingProcessJob), rattachee a un projet a la main ou devinee
  #   par la synthese ;
  # - une session de code, envoyee par /historyupdate (Api::ProjectJournalController).
  #
  # Une entree automatique porte sa `source` et son `source_ref` (Event#12, Meeting#4,
  # code:...). Rendez-vous et reunions ne sont consignes qu'une fois (`journaled_at`) :
  # une entree supprimee a la main ne revient pas. Pas de doublon d'une entree deja
  # saisie (par Sylvain ou Alfred) pour le meme rendez-vous, et une reunion reprend
  # l'entree du rendez-vous du meme jour plutot que d'en ajouter une seconde.
  module Journal
    # Un rendez-vous rattache apres coup a un projet est encore consigne dans ce delai.
    EVENT_LOOKBACK = 14.days
    MAX_DESCRIPTION = 1_500
    MEETING_KIND = "rendez_vous".freeze

    module_function

    # Rendez-vous passes, rattaches a un projet et pas encore consignes. Renvoie le
    # nombre d'entrees creees.
    def record_past_events!(now: Time.current)
      Event.journal_due(now, since: now - EVENT_LOOKBACK).includes(:project).find_each.count do |event|
        record_event(event, now: now)
      end
    end

    # Vrai si une entree a ete creee. Le rendez-vous est marque consigne dans tous les
    # cas : un doublon evite ne doit pas etre reexamine toutes les heures.
    def record_event(event, now: Time.current)
      project = event.project
      return false unless project

      occurred_on = event.start_time.in_time_zone.to_date
      contact = Matcher.new(event_text(event)).contact(project)
      created = false
      unless duplicate_of_event?(project, occurred_on, contact, event)
        project.project_entries.create!(
          source: "agenda", source_ref: "Event##{event.id}", kind: "rendez_vous", occurred_on: occurred_on,
          title: event.title.to_s.truncate(200), body: event_body(event), contact: contact
        )
        created = true
      end
      event.update_columns(journaled_at: now)
      created
    rescue ActiveRecord::RecordNotUnique
      event.update_columns(journaled_at: now)
      false
    end

    # Cree, met a jour, deplace (projet change sur la page de la reunion) ou retire
    # (projet retire) l'entree d'une reunion terminee.
    def record_meeting(meeting, now: Time.current)
      ref = "Meeting##{meeting.id}"
      entry = ProjectEntry.find_by(source: "meeting", source_ref: ref)
      project = meeting.project

      unless project
        entry&.destroy
        return
      end

      occurred_on = meeting.held_at.in_time_zone.to_date
      attributes = {
        project: project, source: "meeting", source_ref: ref, kind: MEETING_KIND, occurred_on: occurred_on,
        title: meeting_title(meeting), body: meeting_body(meeting),
        contact: Matcher.new([meeting.title, meeting.participants].join("\n")).contact(project)
      }

      if entry
        entry.update!(attributes)
      elsif meeting.journaled_at.nil?
        entry = agenda_entry_for(project, occurred_on)
        entry ? entry.update!(attributes) : (entry = ProjectEntry.create!(attributes))
      end
      meeting.update_columns(journaled_at: now) if meeting.journaled_at.nil?
      entry
    end

    # Session de code (resume /historyupdate). `ref` identifie la session (le titre de
    # l'entree de history.md) : la renvoyer enrichie met l'entree a jour au lieu d'en
    # creer une seconde. Renvoie [entry, created].
    def record_code_session(project:, title:, occurred_on: Date.current, body: nil, ref: nil)
      entry = code_session_entry(project, title: title, occurred_on: occurred_on, body: body, ref: ref)
      created = entry.new_record?
      entry.save!
      [entry, created]
    end

    # Plafond d'un rattrapage (/updatejournal) : un history.md entier tient largement dessous.
    MAX_SYNC_SESSIONS = 200

    # Rattrapage de plusieurs sessions d'un coup (history.md d'un projet commence avant le
    # lien avec /historyupdate). Chaque session est « new », « unchanged » ou « changed »
    # par rapport au journal ; en `dry_run`, rien n'est ecrit. Une session invalide est
    # signalee (« invalid ») sans empecher les autres. Renvoie un Hash par session.
    def sync_code_sessions(project:, sessions:, dry_run: false)
      sessions.first(MAX_SYNC_SESSIONS).map do |session|
        entry = code_session_entry(project, **session.slice(:title, :occurred_on, :body, :ref))
        status = if entry.new_record? then "new"
                 elsif entry.changed? then "changed"
                 else "unchanged"
                 end
        result = { ref: session[:ref], title: entry.title, occurred_on: entry.occurred_on, status: status,
                   id: entry.id }
        unless entry.valid?
          next result.merge(status: "invalid", error: entry.errors.full_messages.join(", "))
        end

        entry.save! if !dry_run && status != "unchanged"
        result.merge(id: entry.id)
      end
    end

    def code_session_entry(project, title:, occurred_on: nil, body: nil, ref: nil)
      occurred_on ||= Date.current
      key = (ref.presence || "#{occurred_on} #{title}").to_s.parameterize.first(150)
      entry = project.project_entries.find_or_initialize_by(source_ref: "code:#{key}")
      entry.assign_attributes(source: "code", kind: "travail", occurred_on: occurred_on,
                              title: title.to_s.strip.truncate(200), body: body.to_s.strip.presence)
      entry
    end

    # --- Rendez-vous ---

    def event_text(event)
      [event.title, event.description].compact.join("\n")
    end

    def event_body(event)
      start = event.start_time.in_time_zone
      moment = event.all_day ? "le #{start.strftime('%d/%m/%Y')}" : "le #{start.strftime('%d/%m/%Y à %H:%M')}"
      header = "#{Event::EVENT_TYPE_LABELS.fetch(event.event_type, 'Rendez-vous')} #{moment}"
      header += ", #{event.location}" if event.location.present?
      description = ActionController::Base.helpers.strip_tags(event.description.to_s).squeeze("\n").strip
      ["#{header} (consigné depuis l'agenda).", description.truncate(MAX_DESCRIPTION).presence].compact.join("\n\n")
    end

    # Deja au journal ce jour-la : une reunion (plus riche), ou une entree saisie pour ce
    # rendez-vous (meme interlocuteur, ou meme titre).
    def duplicate_of_event?(project, occurred_on, contact, event)
      entries = project.project_entries.where(occurred_on: occurred_on)
      return true if entries.exists?(source: "meeting")

      title = fold(event.title)
      entries.where(source: "manual", kind: %w[rendez_vous echange]).any? do |entry|
        (contact && entry.contact_id == contact.id) || fold(entry.title) == title
      end
    end

    # --- Reunions ---

    def meeting_title(meeting)
      title = meeting.title.to_s.strip
      (title.match?(/\Ar[ée]union/i) ? title : "Réunion : #{title}").truncate(200)
    end

    def meeting_body(meeting)
      summary = meeting.summary || {}
      parts = [summary["overview"].presence || "Réunion enregistrée (pas de synthèse)."]
      decisions = Array(summary["decisions"]).compact_blank
      parts << "Décisions :\n#{decisions.map { |d| "- #{d}" }.join("\n")}" if decisions.any?
      actions = Array(summary["action_items"]).filter_map { |item| item["description"].presence }
      parts << "À faire :\n#{actions.map { |a| "- #{a}" }.join("\n")}" if actions.any?
      parts << "Compte rendu complet : page Réunions et document « Reunion - #{meeting.title} »."
      parts.join("\n\n")
    end

    # Le rendez-vous du jour deja consigne depuis l'agenda : la reunion le complete. S'il
    # y en a plusieurs, on ne sait pas lequel : nouvelle entree.
    def agenda_entry_for(project, occurred_on)
      candidates = project.project_entries.where(source: "agenda", occurred_on: occurred_on).to_a
      candidates.first if candidates.one?
    end

    def fold(text)
      Alfred::AccentFolding.fold(text).downcase.squish
    end
  end
end
