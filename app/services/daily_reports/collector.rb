module DailyReports
  # Premiere etape du rapport du matin : rassemble en Ruby pur tout ce qu'Alfred doit
  # passer en revue. Exhaustif et deterministe (aucun appel au modele) : c'est le
  # Writer qui juge ce qui merite d'etre signale.
  #
  # Renvoie un Hash serialisable :
  #   "sections" => { "agenda" => [...], "mails" => [...], ... } : chaque element porte un "ref"
  #   "refs"     => { "Contact#12" => { "label" =>, "path" => } , "Mail#18c..." => { "label" =>, "url" => } }
  #   "warnings" => sources indisponibles (Gmail non configure ou en panne...)
  #   "previous" => points saillants du rapport precedent, pour un suivi d'un jour a l'autre
  #
  # Le week-end, version allegee : ni CRM ni projets, mails limites aux non-lus des
  # deux derniers jours, taches limitees a l'urgent.
  class Collector
    AGENDA_DAYS = 7
    DEADLINE_DAYS = 14
    BIRTHDAY_DAYS = 14
    CRM_DAYS = 7
    # Contact CRM de priorite haute sans nouvelles depuis ce delai : a relancer.
    CRM_STALE_DAYS = 30
    SUBSCRIPTION_DAYS = 30
    # Echeance principale d'une assurance : deux mois, le preavis de resiliation le plus courant.
    INSURANCE_DAYS = 60
    # Garantie d'un objet qui se termine : le dernier mois pour faire jouer le SAV.
    WARRANTY_DAYS = 30
    # Pret dont le retour prevu tombe dans ce delai (ou est depasse) : a reclamer ou a rendre.
    LOAN_DAYS = Loan::DUE_SOON_DAYS
    VEHICLE_DAYS = Vehicle::DUE_SOON_DAYS
    VEHICLE_KM = Vehicle::DUE_SOON_KM
    TASK_DAYS = 7
    # Entrees du journal de bord d'un projet jointes a l'instantane.
    PROJECT_JOURNAL_DAYS = 30
    MAIL_DAYS = 5
    MAX_MAILS = 40
    # Mails recents et non lus dont on lit le dernier message en entier (un appel chacun).
    MAX_MAIL_BODIES = 8
    MAIL_BODY_CHARS = 1_500
    CLOSE_RELATIONSHIPS = %w[ami copine famille collegue].freeze

    def initialize(date, weekend: DailyReport.weekend?(date), gmail: nil)
      @date = date
      @weekend = weekend
      @gmail = gmail
      @refs = {}
      @warnings = []
    end

    def call
      sections = {
        "agenda" => agenda,
        "deadlines" => deadlines,
        "reminders" => reminders,
        "birthdays" => birthdays,
        "subscriptions" => subscriptions,
        "insurances" => insurances,
        "warranties" => warranties,
        "loans" => loans,
        "vehicles" => vehicles,
        "tasks" => tasks
      }
      unless @weekend
        sections["crm"] = crm
        sections["projects"] = projects
      end
      sections["mails"] = mails

      {
        "date" => @date.iso8601,
        "weekday" => DailyReport::DAYS[@date.wday],
        "weekend" => @weekend,
        "sections" => sections,
        "refs" => @refs,
        "warnings" => @warnings,
        "previous" => previous_report
      }
    end

    private

    def window(days)
      @date.in_time_zone.beginning_of_day..(@date + days).in_time_zone.end_of_day
    end

    # Reference d'un enregistrement du dashboard, avec son libelle et sa page.
    def ref_for(record)
      key = "#{record.class.name}##{record.id}"
      @refs[key] ||= begin
        config = Alfred::Corpus.config_for(record) || {}
        { "label" => config[:label]&.call(record).presence || key, "path" => config[:path]&.call(record) }
      end
      key
    end

    def days_until(date)
      (date - @date).to_i
    end

    def time_label(time)
      time.in_time_zone.strftime("%H:%M")
    end

    def agenda
      days = @weekend ? 2 : AGENDA_DAYS
      Event.where.not(event_type: "echeance").where(start_time: window(days)).order(:start_time).limit(60).map do |event|
        {
          "ref" => ref_for(event),
          "title" => event.title,
          "type" => Event::EVENT_TYPE_LABELS[event.event_type],
          "date" => event.start_time.to_date.iso8601,
          "in_days" => days_until(event.start_time.to_date),
          "all_day" => event.all_day,
          "start" => (time_label(event.start_time) unless event.all_day),
          "end" => (time_label(event.end_time) if event.end_time && !event.all_day),
          "location" => event.location.presence,
          "description" => event.description.to_s.squish.truncate(400).presence
        }.compact
      end
    end

    def deadlines
      Deadline.upcoming_occurrences(@date, @date + DEADLINE_DAYS).map do |deadline, date|
        {
          "ref" => ref_for(deadline),
          "title" => deadline.title,
          "category" => deadline.category_label,
          "date" => date.iso8601,
          "in_days" => days_until(date),
          "amount" => deadline.formatted_amount,
          "notes" => deadline.notes.to_s.squish.truncate(200).presence
        }.compact
      end
    end

    # Rappels actifs echus ou prevus d'ici demain soir.
    def reminders
      Reminder.active.where(remind_at: ..(@date + 1).in_time_zone.end_of_day).ordered.limit(30).map do |reminder|
        {
          "ref" => ref_for(reminder),
          "title" => reminder.title,
          "remind_at" => reminder.remind_at.in_time_zone.iso8601,
          "overdue" => reminder.remind_at < @date.in_time_zone.beginning_of_day,
          "recurrence" => (reminder.recurrence_label if reminder.recurring?),
          "notes" => reminder.notes.to_s.squish.truncate(200).presence,
          "about" => reminder.remindable_summary&.dig(:label)
        }.compact
      end
    end

    def birthdays
      Contact.where(relationship_type: CLOSE_RELATIONSHIPS).where.not(birth_date: nil).filter_map do |contact|
        next_birthday = next_birthday(contact.birth_date)
        in_days = days_until(next_birthday)
        next if in_days > BIRTHDAY_DAYS

        {
          "ref" => ref_for(contact),
          "name" => [contact.first_name, contact.last_name].compact_blank.join(" "),
          "relationship" => contact.relationship_type,
          "date" => next_birthday.iso8601,
          "in_days" => in_days,
          "age" => next_birthday.year - contact.birth_date.year,
          "likes" => contact.likes.to_s.squish.truncate(400).presence,
          "dislikes" => contact.dislikes.to_s.squish.truncate(200).presence
        }.compact
      end.sort_by { |b| b["in_days"] }
    end

    # Ne le 29 fevrier : fete le 28 les annees non bissextiles.
    def next_birthday(birth_date)
      [@date.year, @date.year + 1].each do |year|
        day = Date.valid_date?(year, birth_date.month, birth_date.day) ? birth_date.day : 28
        candidate = Date.new(year, birth_date.month, day)
        return candidate if candidate >= @date
      end
    end

    # Fins d'abonnement et renouvellements annuels (les mensuels, eux, ne surprennent personne).
    def subscriptions
      Subscription.active.ordered.filter_map do |subscription|
        ending = subscription.end_date && days_until(subscription.end_date) <= SUBSCRIPTION_DAYS
        renewal = subscription.next_renewal_on(@date)
        renewing = subscription.billing_cycle == "yearly" && renewal && days_until(renewal) <= SUBSCRIPTION_DAYS
        next unless ending || renewing

        {
          "ref" => ref_for(subscription),
          "name" => subscription.name,
          "cost" => "#{format('%.2f', subscription.cost).tr('.', ',')} € / #{subscription.billing_cycle == 'yearly' ? 'an' : 'mois'}",
          "ends_on" => (subscription.end_date.iso8601 if ending),
          "ends_in_days" => (days_until(subscription.end_date) if ending),
          "renews_on" => (renewal.iso8601 if renewing),
          "renews_in_days" => (days_until(renewal) if renewing)
        }.compact
      end
    end

    # Assurances dont l'echeance principale (date limite pour resilier) approche.
    def insurances
      Insurance.where(status: "active").ordered.filter_map do |insurance|
        renewal = insurance.next_renewal_on(@date)
        next unless renewal && days_until(renewal) <= INSURANCE_DAYS

        {
          "ref" => ref_for(insurance),
          "name" => insurance.name,
          "insurer" => insurance.insurer,
          "annual_premium" => (insurance.annual_premium && "#{format('%.2f', insurance.annual_premium).tr('.', ',')} € / an"),
          "renews_on" => renewal.iso8601,
          "renews_in_days" => days_until(renewal)
        }.compact
      end
    end

    # Garanties d'objets qui se terminent sous WARRANTY_DAYS jours.
    def warranties
      Warranty.where(ends_on: @date..(@date + WARRANTY_DAYS)).ordered.map do |warranty|
        {
          "ref" => ref_for(warranty),
          "name" => warranty.name,
          "brand" => warranty.brand.presence,
          "store" => warranty.store.presence,
          "ends_on" => warranty.ends_on.iso8601,
          "ends_in_days" => days_until(warranty.ends_on)
        }.compact
      end
    end

    # Prets en cours dont le retour prevu est depasse ou tombe sous LOAN_DAYS jours.
    def loans
      Loan.outstanding.where(due_on: ..(@date + LOAN_DAYS)).order(:due_on).map do |loan|
        {
          "ref" => ref_for(loan),
          "direction" => loan.direction,
          "person" => loan.person_name,
          "what" => loan.label,
          "remaining" => (loan.money? && "#{format('%.2f', loan.remaining_amount).tr('.', ',')} €"),
          "started_on" => loan.started_on.iso8601,
          "due_on" => loan.due_on.iso8601,
          "due_in_days" => days_until(loan.due_on)
        }.compact
      end
    end

    # Vehicules en service dont le controle technique ou la revision est depasse ou tombe
    # sous VEHICLE_DAYS jours (ou VEHICLE_KM kilometres pour la revision).
    def vehicles
      Vehicle.where(status: "active").includes(:vehicle_interventions).order(:name).filter_map do |vehicle|
        inspection = vehicle.next_inspection_on
        inspection = nil unless inspection && days_until(inspection) <= VEHICLE_DAYS
        service = vehicle.next_service_on
        km_left = vehicle.service_mileage_left
        service_due = (service && days_until(service) <= VEHICLE_DAYS) || (km_left && km_left <= VEHICLE_KM)
        next unless inspection || service_due

        {
          "ref" => ref_for(vehicle),
          "name" => vehicle.name,
          "registration" => vehicle.registration_number,
          "inspection_on" => inspection&.iso8601,
          "inspection_in_days" => (inspection && days_until(inspection)),
          "service_on" => (service&.iso8601 if service_due),
          "service_in_days" => (service && days_until(service) if service_due),
          "service_km_left" => (km_left if service_due),
          "mileage" => vehicle.mileage
        }.compact
      end
    end

    # Taches ouvertes en retard, dues bientot ou prioritaires (4-5 sur 5).
    def tasks
      scope = Task.where(completed: false).includes(:project)
      due_limit = @weekend ? @date + 1 : @date + TASK_DAYS
      urgent = scope.where(deadline: ..due_limit)
      urgent = urgent.or(scope.where(priority: 4..)) unless @weekend
      urgent.order(Arel.sql("deadline ASC NULLS LAST"), priority: :desc).limit(30).map do |task|
        {
          "ref" => ref_for(task),
          "description" => task.description,
          "priority" => task.priority,
          "deadline" => task.deadline&.iso8601,
          "in_days" => (days_until(task.deadline) if task.deadline),
          "project" => task.project&.name
        }.compact
      end
    end

    def crm
      profiles = CrmProfile.includes(contact: :projects)
      soon = profiles.where(next_appointment_on: (@date - 30)..(@date + CRM_DAYS))
      stale = profiles.where(priority: "haute")
                      .where("last_contact_on IS NULL OR last_contact_on < ?", @date - CRM_STALE_DAYS)
      soon.or(stale).limit(30).map do |profile|
        contact = profile.contact
        {
          "ref" => ref_for(contact),
          "name" => [contact.first_name, contact.last_name].compact_blank.join(" "),
          "occupation" => contact.occupation.presence,
          "priority" => profile.priority,
          "next_appointment_on" => profile.next_appointment_on&.iso8601,
          "appointment_in_days" => (days_until(profile.next_appointment_on) if profile.next_appointment_on),
          "last_contact_on" => profile.last_contact_on&.iso8601,
          "last_contact_method" => profile.last_contact_method.presence,
          "notes" => profile.notes.to_s.squish.truncate(300).presence,
          "projects" => contact.projects.map(&:name).presence
        }.compact
      end
    end

    # L'activite se mesure d'abord au journal de bord (ProjectEntry) : la date du
    # projet ou de ses taches ne bouge pas quand Sylvain avance hors du dashboard.
    def projects
      Project.where(status: "en_cours").ordered.limit(6).includes(:tasks, project_entries: :contact).map do |project|
        open_tasks = project.tasks.reject(&:completed).sort_by { |t| [-t.priority, t.deadline || Date.new(9999)] }
        entries = project.project_entries.sort_by { |e| [e.occurred_on, e.created_at] }.reverse
        last_entry_on = entries.first&.occurred_on
        last_activity = [last_entry_on, project.updated_at.to_date, *project.tasks.map { |t| t.updated_at.to_date }].compact.max
        {
          "ref" => ref_for(project),
          "name" => project.name,
          "category" => Project::CATEGORY_LABELS[project.category],
          "priority" => project.priority,
          "progress" => project.progress,
          "description" => project.description.to_s.squish.truncate(200).presence,
          "open_tasks" => open_tasks.size,
          "next_tasks" => open_tasks.first(3).map(&:description),
          "idle_days" => days_until(last_activity).abs,
          "journal_empty" => entries.empty?,
          "last_entry_on" => last_entry_on&.iso8601,
          "recent_entries" => entries.select { |e| e.occurred_on >= @date - PROJECT_JOURNAL_DAYS }.first(3).map do |entry|
            { "date" => entry.occurred_on.iso8601, "kind" => entry.kind_label, "title" => entry.title,
              "with" => entry.contact && [entry.contact.first_name, entry.contact.last_name].compact_blank.join(" ") }.compact
          end.presence
        }.compact
      end
    end

    # Fils de la boite de reception (hors promotions et reseaux sociaux) dont le dernier
    # message n'est pas de Sylvain : non lus, ou lus mais restes sans reponse.
    def mails
      return [] unless gmail_available?

      query = @weekend ? "in:inbox is:unread newer_than:2d" : "in:inbox newer_than:#{MAIL_DAYS}d"
      threads = gmail.search("#{query} -category:promotions -category:social", max_results: MAX_MAILS)
      mine = my_addresses
      threads = threads.reject { |thread| mine.include?(address_of(thread[:from])) }
      bodies = recent_unread_bodies(threads)

      threads.map do |thread|
        date = thread[:date] && Time.zone.parse(thread[:date])
        key = "Mail##{thread[:thread_id]}"
        @refs[key] = { "label" => "#{thread[:subject]} (#{display_name(thread[:from])})".truncate(120), "url" => gmail_url(thread[:thread_id]) }
        {
          "ref" => key,
          "subject" => thread[:subject],
          "from" => thread[:from],
          "mailboxes" => thread[:labels].presence,
          "received_at" => date&.iso8601,
          "age_days" => (days_until(date.to_date).abs if date),
          "unread" => thread[:unread],
          "starred" => thread[:starred],
          "messages" => thread[:message_count],
          "snippet" => CGI.unescapeHTML(thread[:snippet].to_s),
          "last_message" => bodies[thread[:thread_id]]
        }.compact
      end
    rescue Gmail::Client::Error => e
      @warnings << "Mails indisponibles : #{e.message.truncate(200)}"
      []
    end

    def gmail_available?
      return true if @gmail
      return true if Gmail.enabled?

      @warnings << "Mails non consultés : Gmail n'est pas configuré sur ce serveur."
      false
    end

    def gmail
      @gmail ||= Gmail.client
    end

    def recent_unread_bodies(threads)
      recent = threads.select do |thread|
        thread[:unread] && thread[:date] && Time.zone.parse(thread[:date]).to_date >= @date - 1
      end
      recent.first(MAX_MAIL_BODIES).each_with_object({}) do |thread, bodies|
        message = gmail.thread(thread[:thread_id])[:messages].last
        bodies[thread[:thread_id]] = message[:body].to_s.squish.truncate(MAIL_BODY_CHARS) if message
      rescue Gmail::Client::Error => e
        Rails.logger.warn "[DailyReports::Collector] fil #{thread[:thread_id]} illisible : #{e.message}"
      end
    end

    # Adresses de Sylvain : la boite, ses alias d'envoi et les sept boites centralisees.
    def my_addresses
      aliases = begin
        gmail.send_as_aliases.map { |a| a[:email] }
      rescue Gmail::Client::Error, NoMethodError
        []
      end
      mailboxes = Gmail::MAILBOXES.flat_map { |m| m[:address].scan(/[\w.+-]+@[\w.-]+/) }
      [Gmail.user, *aliases, *mailboxes].compact.map(&:downcase).to_set
    end

    def address_of(from)
      from.to_s[/<([^>]+)>/, 1].to_s.presence&.downcase || from.to_s.strip.downcase
    end

    def display_name(from)
      from.to_s.sub(/\s*<[^>]+>\z/, "").delete('"').strip.presence || from.to_s
    end

    def gmail_url(thread_id)
      account = Gmail.user ? "?authuser=#{CGI.escape(Gmail.user)}" : ""
      "https://mail.google.com/mail/u/0/#{account}#all/#{thread_id}"
    end

    # Titres du dernier rapport termine : Alfred fait le suivi au lieu de se repeter.
    def previous_report
      report = DailyReport.where(status: "done").where(report_date: ...@date).recent.first or return nil

      {
        "date" => report.report_date.iso8601,
        "items" => DailyReport::SECTIONS.flat_map { |key| Array(report.content&.dig(key)).map { |item| "#{key} : #{item['title']}" } }
      }
    end
  end
end
