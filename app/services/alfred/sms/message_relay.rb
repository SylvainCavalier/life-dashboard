module Alfred
  module Sms
    # Un message pour Sylvain qui n'appelle ni tache ni rendez-vous (« dis-lui que je l'attends
    # devant le cine ») : notification push, et une conversation qui cite le texto, ou il peut
    # demander a Alfred de repondre. Rien n'est ecrit en base hors de cette conversation, donc
    # pas de carte a confirmer.
    class MessageRelay < RequestProposal
      DAILY_LIMIT = 15

      def call
        raise ArgumentError, "Trop de messages transmis aujourd'hui (#{DAILY_LIMIT} par personne)" if over_limit?

        summary = clean(@input["summary"])
        raise ArgumentError, "Il manque le message a transmettre (summary)" if summary.blank?

        conversation, = AlfredConversation.transaction { open_conversation(summary) }
        notified = notify(conversation)
        # Sans appareil atteint, le message n'attend que sur la page : Alfred ne doit pas promettre mieux.
        Rails.logger.warn "[Alfred::Sms] message ##{conversation.id} : aucun appareil notifie" if notified.zero?
        { status: "transmis a Sylvain", note: "Il a recu le message, pas forcement lu : ne promets pas sa reponse." }
      end

      private

      def over_limit?
        AlfredConversation.where(sms_correspondent_id: @correspondent.id, created_at: Time.current.all_day).count >= DAILY_LIMIT
      end

      def introduction
        "Monsieur, #{@correspondent.name} m'adresse ce texto, que je vous rapporte tel quel :\n\n" \
          "> #{clean(@inbound.body).truncate(MAX_QUOTE)}\n\nSouhaitez-vous que je lui réponde ?"
      end
    end
  end
end
