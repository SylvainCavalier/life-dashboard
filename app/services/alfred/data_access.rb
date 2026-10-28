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
      "CvExperience" => :all, "CvFormation" => :all, "CvInterest" => :all, "CvPitch" => :all, "CvSetting" => :all, "CvSkill" => :all,
      "DailyReport" => { exclude: %w[snapshot content] },
      "Deadline" => { exclude: %w[generated_until] }, "Document" => :all, "Event" => :all, "FileTransfer" => :all, "HealthProfile" => :all,
      "Invoice" => :all, "InvoiceItem" => :all, "Language" => :all, "LanguageSession" => :all, "Letter" => { exclude: %w[body] }, "Meeting" => :all,
      "MailAccount" => { exclude: %w[password imap_server imap_port smtp_server smtp_port] },
      "Note" => :all, "PersonalProfile" => :all, "Project" => :all, "ProjectContact" => :all, "ProjectEntry" => :all,
      "ProjectLink" => :all, "ProjectSkill" => :all, "Property" => :all, "Quote" => :all, "QuoteItem" => :all, "Reminder" => :all,
      "SentinelDocument" => { exclude: %w[raw_content raw_metadata] },
      "SentinelSource" => :all, "SentinelWeek" => :all, "Subscription" => :all, "Task" => :all,
      "Trip" => :all, "TripItem" => :all, "TripPlan" => :all, "UsefulSite" => :all,
      "VideoDownload" => :all, "VideoFolder" => :all, "VideoTranscript" => :all
    }.freeze

    SYSTEM_FIELDS = %w[id created_at updated_at].freeze

    # Modeles des outils ouverts aux amis (concern UserOwned) : Alfred ne lit que les
    # lignes du proprietaire, jamais les telechargements ou transferts d'un ami.
    OWNER_SCOPED = %w[FileTransfer VideoDownload VideoFolder VideoTranscript].freeze

    # Champs calcules renvoyes par query_records en plus des colonnes (ni filtre ni tri) :
    # la forme lisible d'une colonne qui ne l'est pas (JSON de l'editeur d'un courrier).
    READABLE_EXTRAS = {
      "DailyReport" => %w[text],
      "Letter" => %w[body_text],
      "Subscription" => %w[next_renewal_on]
    }.freeze

    # Ce que les colonnes ne disent pas : a quelle partie de l'interface correspond
    # un modele, et ou ranger une fiche quand plusieurs modeles semblent convenir.
    # Rendu dans le prompt (section Outils) et renvoye par describe_models.
    MODEL_NOTES = {
      "CvExperience" => "Page CV, trois sections selon category : « Expériences professionnelles » (emploi, freelance, " \
                        "associatif ou vide), « Conférences & Interventions » (intervention : Sylvain y intervient, donne " \
                        "une conférence), « Publications & Médias » (media : article, interview, émission). Une participation " \
                        "à un séminaire, une formation, un concours ou un travail universitaire n'est PAS une CvExperience : " \
                        "c'est une CvFormation.",
      "CvFormation" => "Page CV, section « Formations & travaux » : diplômes (diplome), mémoires (memoire), séminaires " \
                       "suivis (seminaire), certifications (certification), et tout le reste du parcours de formation " \
                       "(autre : concours, prix, travaux universitaires...). institution = établissement ou organisme.",
      "CvSkill" => "Page CV, section « Compétences ».",
      "DailyReport" => "Page Rapports : ton rapport du matin, un par jour (report_date), redige a 9 h. Le champ text le donne " \
                       "en entier (rubriques, elements, references Type#id et Mail#thread_id). Lecture seule.",
      "Subscription" => "next_renewal_on = prochain prelevement, calcule depuis start_date et billing_cycle (nul sans date de debut).",
      "Deadline" => "Page Agenda, module « Échéances notables » : échéances régulières importantes (crédit, charges, " \
                    "URSSAF, impôts, taxe foncière...). due_on = première échéance, recurrence none/monthly/quarterly/" \
                    "semiannual/yearly, ends_on = dernière (fin d'un crédit), category credit/charges/impots/social/" \
                    "assurance/loyer/autre, amount facultatif. Chaque occurrence est posée automatiquement dans l'agenda " \
                    "(Event journée entière, event_type echeance, deadline_id) : ne crée pas les Event toi-même. " \
                    "Une échéance d'argent ou administrative récurrente est une Deadline, pas un Reminder.",
      "ProjectEntry" => "Page du projet, « Journal de bord » : ce que Sylvain a fait, décidé ou appris pour un projet, et " \
                        "quand (occurred_on). kind travail/rendez_vous/echange/decision/jalon/idee/autre, title court, body = " \
                        "le récit détaillé, contact_id facultatif = la personne rencontrée ou contactée. C'est le journal qui " \
                        "dit si un projet avance : voir la section « Projets ».",
      "ProjectContact" => "Page du projet, « Contacts du projet » (mini-CRM) : lie un Contact à un Project (role = son rôle " \
                          "pour le projet). Le suivi (priorité, dernier contact, prochain rendez-vous, notes) reste sur le " \
                          "CrmProfile du contact, partagé avec la page CRM. Un contact ne se lie qu'une fois par projet.",
      "CrmProfile" => "Page CRM : suivi des contacts (priority basse/moyenne/haute, last_contact_on + last_contact_method " \
                      "telephone/email/sms/visio/rencontre/autre, next_appointment_on = date à laquelle le rappeler ou le " \
                      "relancer, notes). Un seul par Contact (contact_id). La page CRM affiche tous les contacts à relancer.",
      "CvInterest" => "Page CV, section « Activités & centres d'intérêt ».",
      "CvPitch" => "Page CV, section « Accroches » : plusieurs accroches enregistrées, celle affichée sur le CV est " \
                   "CvSetting.active_pitch_id.",
      "CvSetting" => "Réglages du CV (ligne unique) : template, couleur, accroche affichée (active_pitch_id).",
      "Letter" => "Page Courrier : lettres mises en page (brouillons), voir la section « Courriers ». Le contenu se lit et " \
                  "s'écrit dans body_text, en texte brut " \
                  "(paragraphes séparés par une ligne vide, formules d'appel et de politesse comprises), jamais dans body " \
                  "(JSON de l'éditeur). sender / recipient : blocs d'adresse multilignes ; sender, place et signatory " \
                  "absents à la création sont repris de PersonalProfile. mention = mode d'envoi (« Lettre recommandée avec accusé de réception »...). " \
                  "Le PDF se télécharge ou se range dans les documents depuis la page (/letters/ID)."
    }.freeze

    # :all = toutes les colonnes sauf SYSTEM_FIELDS ; { create:, update: } = listes explicites.
    # Pas de suppression. Interdits : PasswordEntry, MailAccount, Language, FileTransfer,
    # TripPlan, VideoDownload, VideoTranscript, SentinelWeek, SentinelDocument (voir CLAUDE.md).
    WRITABLE = {
      "Event" => { create: %w[title description event_type start_time end_time location color all_day reminder_minutes] },
      "Note" => { create: %w[title content note_date important] },
      "Deadline" => { create: %w[title category due_on recurrence ends_on amount notes] },
      "Task" => { create: %w[description priority deadline completed project_id] },
      "ProjectEntry" => { create: %w[project_id occurred_on kind title body contact_id],
                          update: %w[occurred_on kind title body contact_id] },
      "ProjectContact" => { create: %w[project_id contact_id role], update: %w[role] },
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
      # body_text : contenu en texte brut, converti en document Tiptap par le modele.
      "Letter" => { create: %w[sender recipient window_envelope place letter_date mention reference subject body_text signatory include_signature footer] },
      # completed_at en modification seulement : marquer un rappel ponctuel comme traite.
      "Reminder" => { create: %w[title notes remind_at recurrence remindable_type remindable_id],
                      update: %w[title notes remind_at recurrence remindable_type remindable_id completed_at] },
      "SentinelSource" => { create: %w[domain name url feed_url web_search on_topic language active],
                            update: %w[name url feed_url web_search on_topic language active] },
      "PersonalProfile" => :all, "HealthProfile" => :all, "Property" => :all, "Document" => :all,
      "Project" => :all, "ProjectLink" => :all, "ProjectSkill" => :all, "Company" => :all, "CrmProfile" => :all,
      "CvExperience" => :all, "CvFormation" => :all, "CvInterest" => :all, "CvPitch" => :all, "CvSetting" => :all, "CvSkill" => :all,
      "Invoice" => :all, "InvoiceItem" => :all, "Quote" => :all, "QuoteItem" => :all
    }.freeze

    module_function

    def readable_class(name)
      raise Denied, "Modele '#{name}' non accessible en lecture" unless READABLE.key?(name.to_s)

      name.to_s.constantize
    end

    def readable_relation(name)
      klass = readable_class(name)
      OWNER_SCOPED.include?(name.to_s) ? klass.where(user_id: User.owner&.id) : klass.all
    end

    def readable_fields(name)
      spec = READABLE.fetch(name.to_s) { raise Denied, "Modele '#{name}' non accessible en lecture" }
      columns = name.to_s.constantize.column_names
      spec == :all ? columns : columns - Array(spec[:exclude])
    end

    def readable_extras(name)
      READABLE_EXTRAS.fetch(name.to_s, [])
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
