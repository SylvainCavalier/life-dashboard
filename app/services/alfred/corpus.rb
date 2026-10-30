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
  #   text     : ->(record) texte ajoute a la fiche (contenu que les colonnes rendent mal, JSON...)
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
      "Deadline" => { title: "Echeance notable", label: ->(r) { r.title }, date: :due_on, path: ->(_) { "/agenda" },
                      except: %w[generated_until] },
      "Reminder" => { title: "Rappel", label: ->(r) { r.title }, date: :remind_at, path: ->(_) { "/reminders" },
                      except: Reminder::DELIVERY_COLUMNS },
      "BudgetEntry" => { title: "Ligne de budget", label: ->(r) { r.name }, path: ->(_) { "/budget" } },
      "Subscription" => { title: "Abonnement", label: ->(r) { r.name }, path: ->(_) { "/subscriptions" } },
      "Property" => { title: "Bien immobilier", label: ->(r) { r.name }, path: ->(_) { "/properties" } },
      # Garanties et biens assures rendus en francais dans la fiche (« Degats des eaux : couverte,
      # franchise... ») : c'est elle que retrouve « mon appartement est-il assure contre... ».
      "Insurance" => { title: "Assurance", label: ->(r) { [r.name, r.insurer].compact_blank.join(" - ") },
                       path: ->(r) { "/insurances/#{r.id}" }, text: ->(r) { Alfred::Corpus.insurance_text(r) } },
      "InsuranceCoverage" => { parent: :insurance },
      "InsuredItem" => { parent: :insurance },
      # La facture jointe est indexee comme le fichier d'un Document (OCR pour une photo).
      "Warranty" => { title: "Garantie", label: ->(r) { [r.name, r.brand].compact_blank.join(" - ") }, date: :purchased_on,
                      file: :receipt, path: ->(_) { "/warranties" }, text: ->(r) { Alfred::Corpus.warranty_text(r) } },
      "Loan" => { title: "Pret", label: ->(r) { "#{r.label} - #{r.person_name}" }, date: :started_on,
                  path: ->(_) { "/loans" }, text: ->(r) { Alfred::Corpus.loan_text(r) } },
      # Carnet d'entretien rendu en francais dans la fiche : c'est elle que retrouve « quand ai-je
      # change les pneus de la moto ? ».
      "Vehicle" => { title: "Vehicule", label: ->(r) { [r.name, r.registration_number].compact_blank.join(" - ") },
                     path: ->(r) { "/vehicles/#{r.id}" }, text: ->(r) { Alfred::Corpus.vehicle_text(r) } },
      "VehicleIntervention" => { parent: :vehicle },
      "Company" => { title: "Entreprise", label: ->(r) { r.trade_name.presence || "Entreprise ##{r.id}" }, path: ->(r) { "/companies/#{r.id}" } },
      "Client" => { title: "Client", label: ->(r) { r.name }, path: ->(r) { "/companies/#{r.company_id}" } },
      "Invoice" => { title: "Facture", label: ->(r) { "Facture #{r.number} - #{r.client_name}" }, date: :issue_date,
                     path: ->(r) { "/companies/#{r.company_id}" }, children: { invoice_items: %w[description quantity unit unit_price total_ht] } },
      "InvoiceItem" => { parent: :invoice },
      "Quote" => { title: "Devis", label: ->(r) { "Devis #{r.number} - #{r.client_name}" }, date: :issue_date,
                   path: ->(r) { "/companies/#{r.company_id}" }, children: { quote_items: %w[description quantity unit unit_price total_ht] } },
      "QuoteItem" => { parent: :quote },
      "Project" => { title: "Projet", label: ->(r) { r.name }, path: ->(r) { "/projects/#{r.id}" },
                     children: { project_skills: %w[name status], project_links: %w[title url] },
                     text: ->(r) { Alfred::Corpus.project_contacts_text(r) } },
      "ProjectContact" => { parent: :project },
      "ProjectEntry" => { title: "Journal de projet", label: ->(r) { "#{r.project.name} : #{r.title}" }, date: :occurred_on,
                          path: ->(r) { "/projects/#{r.project_id}" },
                          text: ->(r) { "Projet : #{r.project.name}" + (r.contact ? "\nAvec : #{[r.contact.first_name, r.contact.last_name].compact_blank.join(' ')}" : "") } },
      "ProjectSkill" => { parent: :project },
      "ProjectLink" => { parent: :project },
      "Document" => { title: "Document", label: ->(r) { r.name }, date: :document_date, file: :file,
                      path: ->(r) { Alfred::Corpus.document_path(r) },
                      text: ->(r) { Alfred::Corpus.document_text(r) } },
      "PersonalProfile" => { title: "Profil personnel", label: ->(_) { "Profil personnel (etat civil, coordonnees, famille)" }, path: ->(_) { "/profile" } },
      "HealthProfile" => { title: "Profil sante", label: ->(_) { "Profil sante" }, path: ->(_) { "/health" } },
      "CvExperience" => { title: "Experience (CV)", label: ->(r) { [r.title, r.company].compact_blank.join(" - ") }, path: ->(_) { "/cv" }, except: %w[position] },
      "CvFormation" => { title: "Formation (CV)", label: ->(r) { [r.title, r.institution].compact_blank.join(" - ") }, path: ->(_) { "/cv" }, except: %w[position] },
      "CvSkill" => { title: "Competence (CV)", label: ->(r) { r.name }, path: ->(_) { "/cv" }, except: %w[position] },
      "CvInterest" => { title: "Centre d'interet (CV)", label: ->(r) { r.name }, path: ->(_) { "/cv" }, except: %w[position] },
      "CvPitch" => { title: "Accroche (CV)", label: ->(r) { r.title }, path: ->(_) { "/cv" }, except: %w[position] },
      "Trip" => { title: "Voyage", label: ->(r) { "Voyage : #{r.destination}" }, date: :start_date, path: ->(r) { "/trips/#{r.id}" },
                  children: { trip_items: %w[day kind title notes cost url] } },
      "TripItem" => { parent: :trip },
      "Letter" => { title: "Courrier", label: ->(r) { r.label }, date: :letter_date, path: ->(r) { "/letters/#{r.id}" },
                    except: %w[body document_id include_signature], text: ->(r) { "Contenu :\n#{r.body_text}" if r.body_text.present? } },
      # Texte integral du script dans la fiche (decoupe en passages par le Chunker).
      "Script" => { title: "Script", label: ->(r) { r.title }, date: :published_on, path: ->(r) { "/scripts/#{r.id}" },
                    except: %w[body script_folder_id], text: ->(r) { Alfred::Corpus.script_text(r) } },
      "ScriptFolder" => { title: "Chaine / compte (scripts)", label: ->(r) { r.name }, path: ->(r) { "/scripts?folder=#{r.id}" } },
      "UsefulSite" => { title: "Site utile", label: ->(r) { r.name }, path: ->(_) { "/useful-sites" } },
      "VideoDownload" => { title: "Video telechargee", label: ->(r) { r.title.presence || r.url }, date: :published_at, path: ->(_) { "/downloader" },
                           only_if: ->(r) { r.status == "completed" && r.user_id == User.owner&.id },
                           except: %w[status error_message file_size filename thumbnail_url quality storage completed_at video_folder_id clip_start clip_end user_id] },
      "SentinelDocument" => { title: "Veille Sentinelle", label: ->(r) { r.display_title.presence || r.title }, date: :published_at,
                              path: ->(r) { "/sentinelle/#{r.domain}/#{r.monday}" },
                              only_if: ->(r) { r.relevant && r.tldr.present? },
                              except: %w[raw_content raw_metadata external_id relevant summarized_at summary_model sentinel_source_id] }
    }.freeze

    IGNORED_COLUMNS = %w[id created_at updated_at].freeze

    module_function

    def script_text(script)
      [
        "Format : #{Script::KIND_LABELS[script.kind]} ; statut : #{Script::STATUS_LABELS[script.status]}",
        script.script_folder && "Chaine / compte : #{script.script_folder.name} " \
                                "(#{ScriptFolder::PLATFORM_LABELS[script.script_folder.platform]})",
        script.body.present? && "Texte :\n#{script.body}"
      ].compact_blank.join("\n")
    end

    # Contacts lies a un projet, par leur nom (ProjectContact n'a que des identifiants).
    def project_contacts_text(project)
      lines = project.project_contacts.includes(:contact).map do |link|
        name = [link.contact.first_name, link.contact.last_name].compact_blank.join(" ")
        "- #{name}#{" (#{link.role})" if link.role.present?}"
      end
      "Contacts du projet :\n#{lines.join("\n")}" if lines.any?
    end

    # Biens assures et garanties d'un contrat d'assurance, en francais.
    def insurance_text(insurance)
      items = insurance.insured_items.map do |item|
        details = [item.kind, item.property && "bien immobilier : #{item.property.name}",
                   item.vehicle && "vehicule : #{item.vehicle.name}",
                   item.value && "valeur #{item.value.to_s('F')} EUR", item.description].compact_blank
        "- #{item.name}#{" (#{details.join(' ; ')})" if details.any?}"
      end
      coverages = insurance.insurance_coverages.map do |coverage|
        details = [coverage.included ? "couverte" : "NON couverte (exclue ou non souscrite)",
                   coverage.ceiling.presence && "plafond : #{coverage.ceiling}",
                   coverage.deductible.presence && "franchise : #{coverage.deductible}",
                   coverage.conditions.presence && "conditions : #{coverage.conditions}"].compact
        "- #{coverage.name} : #{details.join(' ; ')}"
      end
      parts = []
      parts << "Biens et personnes assures :\n#{items.join("\n")}" if items.any?
      parts << "Garanties :\n#{coverages.join("\n")}" if coverages.any?
      parts.join("\n").presence
    end

    # Documents rattaches a un contrat ou a un vehicule : leur page et leur rattachement.
    def document_path(document)
      if document.insurance_id then "/insurances/#{document.insurance_id}"
      elsif document.vehicle_id then "/vehicles/#{document.vehicle_id}"
      else "/documents"
      end
    end

    def document_text(document)
      [document.insurance && "Contrat d'assurance : #{document.insurance.name}",
       document.vehicle && "Vehicule : #{document.vehicle.name}"].compact.join("\n").presence
    end

    # Type, contrats qui le couvrent et carnet d'entretien d'un vehicule. Comme pour les
    # garanties, pas d'etat date-dependant (« controle en retard ») : la fiche n'est pas
    # reindexee quand le temps passe, Alfred compare lui-meme les dates.
    def vehicle_text(vehicle)
      parts = ["Type : #{Vehicle::TYPE_LABELS[vehicle.vehicle_type]}"]
      insurances = vehicle.insurances.map { |i| "- #{[i.name, i.insurer].compact_blank.join(' - ')} (#{i.status})" }
      parts << "Assure par :\n#{insurances.join("\n")}" if insurances.any?
      lines = vehicle.vehicle_interventions.map do |intervention|
        details = [intervention.mileage && "#{intervention.mileage} km",
                   intervention.cost && "#{intervention.cost.to_s('F')} EUR",
                   intervention.garage.presence,
                   intervention.outcome && "resultat : #{VehicleIntervention::OUTCOME_LABELS[intervention.outcome]}"].compact
        line = "- #{intervention.occurred_on.strftime('%d/%m/%Y')} · #{VehicleIntervention::KIND_LABELS[intervention.kind]} : #{intervention.title}"
        line += " (#{details.join(' ; ')})" if details.any?
        line += " : #{intervention.description.squish}" if intervention.description.present?
        line
      end
      parts << "Carnet d'entretien :\n#{lines.join("\n")}" if lines.any?
      parts.join("\n")
    end

    # Dates en clair : une fiche ne dit pas « expiree » (elle n'est pas reindexee quand le
    # temps passe), Alfred compare lui-meme ends_on a la date du jour.
    def warranty_text(warranty)
      [
        "Catégorie : #{Warranty::CATEGORY_LABELS[warranty.category]}",
        warranty.purchased_on && "Achat le #{warranty.purchased_on.strftime('%d/%m/%Y')}#{" chez #{warranty.store}" if warranty.store.present?}",
        warranty.ends_on && "Fin de garantie : #{warranty.ends_on.strftime('%d/%m/%Y')}" \
                            "#{" (garantie de #{warranty.duration_months} mois)" if warranty.duration_months}"
      ].compact.join("\n")
    end

    # Sens du pret en toutes lettres (« Prete par Sylvain a Paul ») : c'est ce que retrouve
    # « qui a ma perceuse ? ». Pas d'etat date-dependant, comme pour les garanties.
    def loan_text(loan)
      who = loan.direction == "lent" ? "Prêté par Sylvain à #{loan.person_name}" : "Prêté à Sylvain par #{loan.person_name}"
      [
        "#{who} : #{loan.money? ? "argent, #{loan.label}" : loan.item}",
        "Depuis le #{loan.started_on.strftime('%d/%m/%Y')}",
        loan.due_on && "Retour prévu le #{loan.due_on.strftime('%d/%m/%Y')}",
        loan.returned_on ? "#{loan.money? ? 'Remboursé' : 'Rendu'} le #{loan.returned_on.strftime('%d/%m/%Y')}" : "En cours",
        loan.money? && loan.repaid_amount.to_d.positive? && !loan.returned? && "Déjà remboursé : #{loan.repaid_amount.to_s('F')} EUR"
      ].compact_blank.join("\n")
    end

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
