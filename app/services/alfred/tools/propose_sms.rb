module Alfred
  module Tools
    # Alfred du dashboard : proposer un texto a un correspondant autorise. Rien ne part sans
    # la confirmation de Sylvain dans le chat (Alfred::SmsActions).
    class ProposeSms < Base
      def self.definition
        {
          name: "propose_sms",
          description: "Propose d'envoyer un texto depuis le numero d'Alfred a un correspondant autorise (query_records sur " \
                       "SmsCorrespondent pour l'id). Rien ne part : Monsieur confirme ou annule la carte dans le chat. Le texte " \
                       "doit etre bref. Apres l'appel, annoncer la proposition et s'arreter.",
          input_schema: {
            type: "object",
            properties: {
              correspondent_id: { type: "integer" },
              body: { type: "string", description: "Le texte du SMS, sans emojis." },
              summary: { type: "string", description: "Resume en une phrase, en francais, affiche sur la carte." }
            },
            required: %w[correspondent_id body summary]
          }
        }
      end

      def self.step_label(_input) = "Proposition : texto"

      def call(input)
        raise ArgumentError, TwilioSms::NOT_CONFIGURED unless TwilioSms.configured?

        correspondent = SmsCorrespondent.find(input["correspondent_id"])
        raise ArgumentError, "#{correspondent.name} est desactive(e) dans la page Textos" unless correspondent.enabled?

        body = input["body"].to_s.strip
        raise ArgumentError, "Texto vide" if body.empty?
        raise ArgumentError, "Texto trop long (#{SmsMessage::MAX_LENGTH} caracteres au plus)" if body.length > SmsMessage::MAX_LENGTH

        action = @context.conversation.actions.create!(
          message: @context.message, operation: "send_sms", target_model: "Sms",
          summary: input["summary"].to_s.truncate(250),
          payload: { attributes: { "destinataire" => correspondent.name, "texte" => body }, before: {},
                     correspondent_id: correspondent.id }.to_json
        )
        { action_id: action.id, status: "en attente de la confirmation de Monsieur dans le chat", note: "Rien n'est parti pour l'instant." }
      end
    end
  end
end
