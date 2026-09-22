module Alfred
  # Registre du corpus : quels modeles Alfred peut retrouver par la recherche
  # semantique, et comment les presenter. Ajouter un modele = une entree ici
  # (les callbacks de synchronisation suivent, voir `install_hooks!`).
  #
  # Cles d'une entree :
  #   title    : nom francais du type d'enregistrement
  #   label    : ->(record) libelle court affiche comme source
  #   date     : colonne servant au leger bonus de fraicheur (optionnel)
  #   path     : ->(record) page du dashboard ou voir l'enregistrement
  #   children : { association => [colonnes] } lignes filles incluses dans la fiche
  #   parent   : association a reindexer quand CET enregistrement change (modeles enfants)
  #   except   : colonnes ignorees en plus des colonnes techniques
  #   only_if  : ->(record) false = l'enregistrement est retire du corpus
  #   file     : nom de la piece jointe Active Storage dont le texte est indexe
  #
  # Jamais ici : PasswordEntry (coffre-fort), MailAccount (identifiants), User.
  # Les attributs chiffres (`encrypts`) sont ecartes automatiquement du corpus
  # pour ne pas les recopier en clair ; Alfred les lit a la demande via query_records.
  module Corpus
    REGISTRY = {
      "Contact" => { title: "Contact", label: ->(r) { [r.first_name, r.last_name].compact_blank.join(" ") },
                     path: ->(_) { "/contacts" }, children: { crm_profile: %w[priority last_contact_on last_contact_method next_appointment_on notes] } },
      "CrmProfile" => { parent: :contact },
      "Event" => { title: "Evenement", label: ->(r) { r.title }, date: :start_time, path: ->(_) { "/agenda" },
                   except: %w[color google_event_id google_updated_at] },
      "Note" => { title: "Note", label: ->(r) { r.title.presence || "Note du #{r.note_date || r.created_at.to_date}" }, date: :note_date, path: ->(_) { "/notes" } },
      "Task" => { title: "Tache", label: ->(r) { r.description.to_s.truncate(80) }, path: ->(r) { r.project_id ? "/projects/#{r.project_id}" : "/" } },
      "BudgetEntry" => { title: "Ligne de budget", label: ->(r) { r.name }, path: ->(_) { "/budget" } },
      "Subscription" => { title: "Abonnement", label: ->(r) { r.name }, path: ->(_) { "/subscriptions" } },
      "Property" => { title: "Bien immobilier", label: ->(r) { r.name }, path: ->(_) { "/properties" } },
      "Company" => { title: "Entreprise", label: ->(r) { r.trade_name.presence || "Entreprise ##{r.id}" }, path: ->(r) { "/companies/#{r.id}" } },
      "Client" => { title: "Client", label: ->(r) { r.name }, path: ->(r) { "/companies/#{r.company_id}" } },
      "Invoice" => { title: "Facture", label: ->(r) { "Facture #{r.number} - #{r.client_name}" }, date: :issue_date,
                     path: ->(r) { "/companies/#{r.company_id}" }, children: { invoice_items: %w[description quantity unit unit_price total_ht] } },
      "InvoiceItem" => { parent: :invoice },
      "Quote" => { title: "Devis", label: ->(r) { "Devis #{r.number} - #{r.client_name}" }, date: :issue_date,
                   path: ->(r) { "/companies/#{r.company_id}" }, children: { quote_items: %w[description quantity unit unit_price total_ht] } },
      "QuoteItem" => { parent: :quote },
      "Project" => { title: "Projet", label: ->(r) { r.name }, path: ->(r) { "/projects/#{r.id}" },
                     children: { project_skills: %w[name status], project_links: %w[title url] } },
      "ProjectSkill" => { parent: :project },
      "ProjectLink" => { parent: :project },
      "Document" => { title: "Document", label: ->(r) { r.name }, date: :document_date, path: ->(_) { "/documents" }, file: :file },
      "PersonalProfile" => { title: "Profil personnel", label: ->(_) { "Profil personnel (etat civil, coordonnees, famille)" }, path: ->(_) { "/profile" } },
      "HealthProfile" => { title: "Profil sante", label: ->(_) { "Profil sante" }, path: ->(_) { "/health" } },
      "CvExperience" => { title: "Experience (CV)", label: ->(r) { [r.title, r.company].compact_blank.join(" - ") }, path: ->(_) { "/cv" }, except: %w[position] },
      "CvFormation" => { title: "Formation (CV)", label: ->(r) { [r.title, r.institution].compact_blank.join(" - ") }, path: ->(_) { "/cv" }, except: %w[position] },
      "CvSkill" => { title: "Competence (CV)", label: ->(r) { r.name }, path: ->(_) { "/cv" }, except: %w[position] },
      "CvInterest" => { title: "Centre d'interet (CV)", label: ->(r) { r.name }, path: ->(_) { "/cv" }, except: %w[position] },
      "Trip" => { title: "Voyage", label: ->(r) { "Voyage : #{r.destination}" }, date: :start_date, path: ->(r) { "/trips/#{r.id}" },
                  children: { trip_items: %w[day kind title notes cost url] } },
      "TripItem" => { parent: :trip },
      "UsefulSite" => { title: "Site utile", label: ->(r) { r.name }, path: ->(_) { "/useful-sites" } },
      "VideoDownload" => { title: "Video telechargee", label: ->(r) { r.title.presence || r.url }, date: :published_at, path: ->(_) { "/downloader" },
                           only_if: ->(r) { r.status == "completed" },
                           except: %w[status error_message file_size filename thumbnail_url quality storage completed_at video_folder_id clip_start clip_end] },
      "SentinelDocument" => { title: "Veille Sentinelle", label: ->(r) { r.display_title.presence || r.title }, date: :published_at,
                              path: ->(r) { "/sentinelle/#{r.domain}/#{r.monday}" },
                              only_if: ->(r) { r.relevant && r.tldr.present? },
                              except: %w[raw_content raw_metadata external_id relevant summarized_at summary_model sentinel_source_id] }
    }.freeze

    IGNORED_COLUMNS = %w[id created_at updated_at].freeze

    module_function

    # Modeles qui ont leur propre fiche dans le corpus (les enfants n'en ont pas).
    def indexed_models
      REGISTRY.reject { |_, config| config[:parent] }.keys
    end

    def config_for(record_or_name)
      name = record_or_name.is_a?(String) ? record_or_name : record_or_name.class.name
      REGISTRY[name]
    end

    # Enregistrement a (re)indexer quand `record` change : lui-meme, ou son parent.
    def root_for(record)
      config = config_for(record)
      return nil unless config

      config[:parent] ? record.public_send(config[:parent]) : record
    end

    # Pose les callbacks de synchronisation sur les modeles du registre. Appele
    # dans un `to_prepare` : rejoue a chaque rechargement du code en developpement.
    def install_hooks!
      REGISTRY.each_key do |name|
        klass = name.safe_constantize or next
        next if klass.instance_variable_get(:@alfred_hooked)

        klass.instance_variable_set(:@alfred_hooked, true)
        klass.after_commit(on: [:create, :update]) { Alfred::Corpus.schedule(self) }
        klass.after_commit(on: :destroy) { Alfred::Corpus.forget(self) }
      end
    end

    def schedule(record)
      return unless Alfred.corpus_configured? && hooks_enabled?

      root = root_for(record)
      AlfredIndexJob.perform_later(root.class.name, root.id) if root&.persisted?
    rescue StandardError => e
      # L'indexation ne doit jamais faire echouer une ecriture du dashboard.
      Rails.logger.error "[Alfred::Corpus] planification impossible (#{record.class}##{record.id}) : #{e.message}"
    end

    def forget(record)
      return unless hooks_enabled?

      if config_for(record)&.dig(:parent)
        schedule(record)
      else
        AlfredChunk.for_source(record).delete_all
        AlfredIndexEntry.where(source_type: record.class.name, source_id: record.id).delete_all
      end
    rescue StandardError => e
      Rails.logger.error "[Alfred::Corpus] nettoyage impossible (#{record.class}##{record.id}) : #{e.message}"
    end

    # Coupe-circuit : ALFRED_INDEXING=0 (imports massifs). Desactive en test.
    def hooks_enabled?
      ENV.fetch("ALFRED_INDEXING", Rails.env.test? ? "0" : "1") == "1"
    end
  end
end
