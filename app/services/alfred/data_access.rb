module Alfred
  # Listes blanches de lecture et d'ecriture d'Alfred DANS le dashboard. Elles
  # reprennent celles des skills locales (~/.claude/skills/life-dashboard*/scripts) :
  # a tenir alignees quand un modele est ajoute ou renomme.
  #
  # Difference voulue avec la skill de lecture locale : ici les champs sensibles
  # (numero de securite sociale, IBAN, passeport...) sont lisibles. Decision de
  # Sylvain : la seule chose qu'Alfred ne doit jamais lire, ce sont les mots de passe
  # (PasswordEntry, et par extension les identifiants de MailAccount).
  module DataAccess
    class Denied < StandardError; end

    READABLE = {
      "BudgetEntry" => :all, "CalendarSync" => :all, "Client" => :all, "Company" => :all, "Contact" => :all, "CrmProfile" => :all,
      "CvExperience" => :all, "CvFormation" => :all, "CvInterest" => :all, "CvSetting" => :all, "CvSkill" => :all,
      "Document" => :all, "Event" => :all, "FileTransfer" => :all, "HealthProfile" => :all,
      "Invoice" => :all, "InvoiceItem" => :all, "Language" => :all, "LanguageSession" => :all,
      "MailAccount" => { exclude: %w[password imap_server imap_port smtp_server smtp_port] },
      "Note" => :all, "PersonalProfile" => :all, "Project" => :all, "ProjectLink" => :all, "ProjectSkill" => :all,
      "Property" => :all, "Quote" => :all, "QuoteItem" => :all,
      "SentinelDocument" => { exclude: %w[raw_content raw_metadata] },
      "SentinelSource" => :all, "SentinelWeek" => :all, "Subscription" => :all, "Task" => :all,
      "Trip" => :all, "TripItem" => :all, "TripPlan" => :all, "UsefulSite" => :all,
      "VideoDownload" => :all, "VideoFolder" => :all
    }.freeze

    SYSTEM_FIELDS = %w[id created_at updated_at].freeze

    # :all = toutes les colonnes sauf SYSTEM_FIELDS ; { create:, update: } = listes explicites.
    # Pas de suppression. Interdits : PasswordEntry, MailAccount, Language, FileTransfer,
    # TripPlan, VideoDownload, SentinelWeek, SentinelDocument (voir CLAUDE.md).
    WRITABLE = {
      "Event" => { create: %w[title description event_type start_time end_time location color all_day reminder_minutes] },
      "Note" => { create: %w[title content note_date important] },
      "Task" => { create: %w[description priority deadline completed project_id] },
      "BudgetEntry" => { create: %w[name entry_type recurrence category amount month year notes] },
      "Contact" => { create: %w[last_name first_name birth_date gender occupation city phone email last_contacted_on
                               relationship_type followed notes likes dislikes loans address met_through met_year
                               social_instagram social_linkedin social_twitter social_facebook social_tiktok
                               social_snapchat social_youtube] },
      "LanguageSession" => { create: %w[language_id practiced_on source notes], update: %w[practiced_on source notes] },
      "UsefulSite" => { create: %w[name url description category] },
      "Subscription" => { create: %w[name cost billing_cycle category start_date end_date url] },
      "Trip" => { create: %w[destination country_code start_date end_date travelers departure_city status notes] },
      "TripItem" => { create: %w[trip_id day kind title url notes start_time cost position],
                      update: %w[day kind title url notes start_time cost position] },
      "VideoFolder" => { create: %w[name] },
      "SentinelSource" => { create: %w[domain name url feed_url web_search on_topic language active],
                            update: %w[name url feed_url web_search on_topic language active] },
      "PersonalProfile" => :all, "HealthProfile" => :all, "Property" => :all, "Document" => :all,
      "Project" => :all, "ProjectLink" => :all, "ProjectSkill" => :all, "Company" => :all, "CrmProfile" => :all,
      "CvExperience" => :all, "CvFormation" => :all, "CvInterest" => :all, "CvSetting" => :all, "CvSkill" => :all,
      "Invoice" => :all, "InvoiceItem" => :all, "Quote" => :all, "QuoteItem" => :all
    }.freeze

    module_function

    def readable_class(name)
      raise Denied, "Modele '#{name}' non accessible en lecture" unless READABLE.key?(name.to_s)

      name.to_s.constantize
    end

    def readable_fields(name)
      spec = READABLE.fetch(name.to_s) { raise Denied, "Modele '#{name}' non accessible en lecture" }
      columns = name.to_s.constantize.column_names
      spec == :all ? columns : columns - Array(spec[:exclude])
    end

    def writable_class(name)
      raise Denied, "Modele '#{name}' non accessible en ecriture" unless WRITABLE.key?(name.to_s)

      name.to_s.constantize
    end

    def writable_fields(name, operation)
      spec = WRITABLE.fetch(name.to_s) { raise Denied, "Modele '#{name}' non accessible en ecriture" }
      return name.to_s.constantize.column_names - SYSTEM_FIELDS if spec == :all

      spec[operation.to_sym] || spec[:create] || []
    end

    def serialize(record, fields)
      fields.index_with { |field| record.public_send(field) }
    end
  end
end
