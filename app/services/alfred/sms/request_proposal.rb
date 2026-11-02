module Alfred
  module Sms
    # Une demande recue par texto (« dis a Sylvain de faire la vaisselle ») devient une
    # AlfredAction dans sa propre conversation, plus une notification push. Elle suit le
    # circuit habituel : seule la confirmation de Sylvain (ActionExecutor) ecrit en base.
    # Les attributs sont construits ici, champ par champ : le texto ne peut choisir ni le
    # modele, ni un projet, ni une priorite.
    class RequestProposal
      DAILY_LIMIT = 5
      MAX_DESCRIPTION = 200
      MAX_QUOTE = 400

      def initialize(correspondent, inbound, input)
        @correspondent = correspondent
        @inbound = inbound
        @input = input
      end

      def call
        raise ArgumentError, "Trop de demandes transmises aujourd'hui (#{DAILY_LIMIT} par personne)" if over_limit?

        model, attributes = @input["kind"] == "event" ? ["Event", event_attributes] : ["Task", task_attributes]
        record = model.constantize.new(attributes)
        raise ArgumentError, record.errors.full_messages.to_sentence unless record.valid?

        conversation = create_conversation(model, attributes)
        notified = notify(conversation)
        Rails.logger.warn "[Alfred::Sms] demande ##{conversation.id} : aucun appareil notifie" if notified.zero?
        { status: "transmis a Sylvain", note: "Rien n'est ajoute tant qu'il n'a pas accepte." }
      end

      private

      def over_limit?
        AlfredAction.joins(:conversation)
                    .where(alfred_conversations: { sms_correspondent_id: @correspondent.id }, created_at: Time.current.all_day)
                    .count >= DAILY_LIMIT
      end

      def task_attributes
        description = clean(@input["description"])
        raise ArgumentError, "Il manque ce qu'il y a a faire (description)" if description.blank?

        { "description" => "#{description.truncate(MAX_DESCRIPTION)} (via #{@correspondent.name})",
          "deadline" => future_date(@input["deadline"]) }.compact
      end

      def event_attributes
        title = clean(@input["title"])
        raise ArgumentError, "Il manque l'intitule du rendez-vous (title)" if title.blank?

        start = time(@input["start_time"]) or raise ArgumentError, "Il manque l'heure de debut (start_time)"
        raise ArgumentError, "Ce rendez-vous serait dans le passe" if start.past?

        { "title" => title.truncate(MAX_DESCRIPTION), "start_time" => start.iso8601, "end_time" => time(@input["end_time"])&.iso8601,
          "location" => clean(@input["location"]).presence, "event_type" => "autre",
          "description" => "Demande par texto de #{@correspondent.name}." }.compact
      end

      def future_date(value)
        return if value.blank?

        date = Date.iso8601(value.to_s)
        raise ArgumentError, "Cette date limite est passee" if date.past?

        date.iso8601
      rescue Date::Error
        raise ArgumentError, "Date limite invalide (format AAAA-MM-JJ)"
      end

      def time(value)
        return if value.blank?

        # Sans fuseau, Time.zone.parse lit une heure de Paris, changement d'heure compris.
        Time.zone.parse(value.to_s) || raise(ArgumentError)
      rescue ArgumentError
        raise ArgumentError, "Heure invalide (format AAAA-MM-JJTHH:MM)"
      end

      def create_conversation(model, attributes)
        label = attributes["description"] || attributes["title"]
        AlfredConversation.transaction do
          conversation, message = open_conversation(label)
          conversation.actions.create!(
            message: message, operation: "create", target_model: model,
            summary: clean(@input["summary"]).truncate(250).presence || label.truncate(250),
            payload: { attributes: attributes, before: {} }.to_json
          )
          conversation
        end
      end

      def open_conversation(label)
        conversation = AlfredConversation.create!(
          sms_correspondent: @correspondent, title: "Texto de #{@correspondent.name} : #{label}".truncate(60),
          last_message_at: Time.current
        )
        [conversation, conversation.messages.create!(role: "assistant", status: "done", content: introduction)]
      end

      def introduction
        "Monsieur, #{@correspondent.name} m'adresse ce texto, que je vous rapporte tel quel :\n\n" \
          "> #{clean(@inbound.body).truncate(MAX_QUOTE)}\n\nSouhaitez-vous donner suite ?"
      end

      def notify(conversation)
        PushNotifications.broadcast(
          title: "Alfred : texto de #{@correspondent.name}",
          body: clean(@input["summary"]).truncate(160),
          url: "/sms?conversation=#{conversation.id}",
          tag: "sms-request-#{conversation.id}",
          renotify: true
        )
      end

      # Le texte d'un tiers finit dans un rendu Markdown (echappe, mais qui garderait les
      # liens et les marqueurs de citation) et dans le prompt : on retire ces signes.
      def clean(value)
        value.to_s.gsub(/[\[\]`*]/, "").squish
      end
    end
  end
end
