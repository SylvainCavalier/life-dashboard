module Alfred
  # Execution des actions Gmail proposees par Alfred (send_email, draft_email,
  # triage_email), appelee par ActionExecutor apres confirmation de Sylvain.
  # Renvoie le texte de la note systeme laissee dans la conversation.
  module MailActions
    TRIAGE = {
      "archive" => { remove: ["INBOX"] }, "unarchive" => { add: ["INBOX"] },
      "mark_read" => { remove: ["UNREAD"] }, "mark_unread" => { add: ["UNREAD"] },
      "star" => { add: ["STARRED"] }, "unstar" => { remove: ["STARRED"] }
    }.freeze

    module_function

    def execute!(action)
      raise Gmail::Client::Error, Gmail::NOT_CONFIGURED unless Gmail.enabled?

      case action.operation
      when "send_email", "draft_email" then deliver!(action)
      when "triage_email" then triage!(action)
      else raise ArgumentError, "operation Gmail inconnue : #{action.operation}"
      end
    end

    def deliver!(action)
      attrs = action.new_attributes
      headers = action.data.fetch("headers", {})
      mail = Gmail::Composer.build(
        from: sender(attrs["from"]), to: attrs["to"], cc: attrs["cc"], bcc: attrs["bcc"],
        subject: attrs["subject"], body: attrs["body"],
        in_reply_to: headers["in_reply_to"], references: headers["references"]
      )
      recipients = Array(attrs["to"]).join(", ")
      if action.operation == "send_email"
        Gmail.client.send_message(mail, thread_id: headers["thread_id"])
        "Mail envoye par Sylvain (confirmation) a #{recipients} : « #{attrs['subject']} »."
      else
        Gmail.client.create_draft(mail, thread_id: headers["thread_id"])
        "Brouillon Gmail cree a l'attention de #{recipients} : « #{attrs['subject']} ». Il reste a envoyer depuis Gmail."
      end
    end

    # Revalide l'alias a l'execution et y joint son nom d'affichage.
    def sender(requested)
      aliases = Gmail.client.send_as_aliases
      chosen = aliases.find { |a| a[:email].casecmp?(requested.to_s) } || (requested.blank? && aliases.first)
      raise Gmail::Client::Error, "'#{requested}' n'est plus un alias d'envoi de la boite" unless chosen

      chosen[:name].present? ? "#{chosen[:name]} <#{chosen[:email]}>" : chosen[:email]
    end

    def triage!(action)
      triage = action.data.fetch("triage")
      client = Gmail.client
      thread_ids = Array(triage["thread_ids"])
      label_id = triage["label"].present? ? client.find_or_create_label(triage["label"]) : nil

      Array(triage["actions"]).each do |name|
        thread_ids.each { |thread_id| apply(client, thread_id, name, label_id) }
      end

      done = Array(triage["actions"]).map { |name| Tools::ProposeMailTriage::LABELS_FR[name] }.join(", ")
      label = triage["label"].present? ? " (libelle « #{triage['label']} »)" : ""
      "Tri Gmail confirme par Sylvain et execute sur #{thread_ids.size} fil(s) : #{done}#{label}."
    end

    def apply(client, thread_id, name, label_id)
      case name
      when "trash" then client.trash_thread(thread_id)
      when "untrash" then client.untrash_thread(thread_id)
      when "add_label" then client.modify_thread(thread_id, add: [label_id])
      when "remove_label" then client.modify_thread(thread_id, remove: [label_id])
      else
        change = TRIAGE.fetch(name) { raise ArgumentError, "action de tri inconnue : #{name}" }
        client.modify_thread(thread_id, add: change[:add] || [], remove: change[:remove] || [])
      end
    end
  end
end
