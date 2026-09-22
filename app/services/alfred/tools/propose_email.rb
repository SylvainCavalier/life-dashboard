module Alfred
  module Tools
    # Redaction d'un mail (nouveau ou reponse). Rien ne part : une AlfredAction
    # « proposed » affiche le mail dans le chat, et seul le bouton Confirmer de
    # Sylvain l'envoie (ou le range en brouillon Gmail).
    class ProposeEmail < Base
      MODES = { "send" => "send_email", "draft" => "draft_email" }.freeze
      EMAIL = URI::MailTo::EMAIL_REGEXP

      def self.definition
        {
          name: "propose_email",
          description: "Propose un mail a envoyer depuis la boite de Monsieur (mode send) ou a ranger en brouillon Gmail " \
                       "(mode draft). RIEN ne part : Monsieur voit le mail complet dans le chat et confirme ou annule " \
                       "lui-meme. Pour repondre, lire d'abord le fil (read_mail_thread) et passer reply_to_thread_id : " \
                       "la reponse est rattachee au fil avec les bons en-tetes. Ecrire le corps en texte brut, en " \
                       "francais sauf demande contraire, signe « Sylvain ». Ne jamais inventer un destinataire : " \
                       "le demander. Apres l'appel, annoncer la proposition en une phrase et s'arreter.",
          input_schema: {
            type: "object",
            properties: {
              mode: { type: "string", enum: MODES.keys, description: "send = envoyer, draft = brouillon Gmail." },
              from: { type: "string", description: "Adresse d'envoi : l'adresse de la boite d'origine du fil si elle " \
                                                   "figure parmi les alias d'envoi (list_mail_labels). Defaut : la boite centrale." },
              to: { type: "array", items: { type: "string" }, description: "Adresses des destinataires." },
              cc: { type: "array", items: { type: "string" } },
              bcc: { type: "array", items: { type: "string" } },
              subject: { type: "string" },
              body: { type: "string", description: "Corps du mail en texte brut." },
              reply_to_thread_id: { type: "string",
                                    description: "Fil auquel repondre (search_mails / read_mail_thread)." },
              summary: { type: "string", description: "Resume en une phrase, en francais, affiche sur la carte." }
            },
            required: %w[mode to subject body summary]
          }
        }
      end

      def self.step_label(input) = "Proposition : #{input['mode'] == 'draft' ? 'brouillon' : 'mail'} a #{Array(input['to']).join(', ')}"

      def call(input)
        ensure_gmail!

        operation = MODES[input["mode"].to_s] or raise ArgumentError, "`mode` doit etre send ou draft"
        to, cc, bcc = %w[to cc bcc].map { |field| addresses(field, input[field]) }
        raise ArgumentError, "`to` doit contenir au moins une adresse" if to.empty?

        subject = input["subject"].to_s.strip
        body = input["body"].to_s.strip
        raise ArgumentError, "`subject` et `body` sont requis" if subject.blank? || body.blank?

        thread_id = input["reply_to_thread_id"].to_s.strip.presence
        headers = thread_id ? Gmail.client.reply_headers(thread_id).merge(thread_id: thread_id) : {}

        attributes = { from: sender(input["from"]), to: to, cc: cc, bcc: bcc, subject: subject, body: body,
                       reply_to_thread_id: thread_id }.compact_blank
        action = @context.conversation.actions.create!(
          message: @context.message, operation: operation, target_model: "Gmail",
          summary: input["summary"].to_s.truncate(250),
          payload: { attributes: attributes, before: {}, headers: headers }.to_json
        )
        { action_id: action.id, status: "en attente de la confirmation de Monsieur dans le chat",
          note: operation == "send_email" ? "Rien n'a ete envoye pour l'instant." : "Aucun brouillon cree pour l'instant." }
      end

      private

      # L'adresse d'envoi doit etre un alias verifie de la boite, sinon Gmail
      # remplacerait silencieusement l'expediteur par l'adresse principale.
      def sender(value)
        requested = value.to_s.strip.downcase.presence
        aliases = Gmail.client.send_as_aliases
        return aliases.first[:email] if requested.nil?
        return requested if aliases.any? { |a| a[:email].casecmp?(requested) }

        raise ArgumentError, "'#{requested}' n'est pas un alias d'envoi de la boite. Disponibles : " \
                             "#{aliases.map { |a| a[:email] }.join(', ')}. Sinon, omettre `from` (boite centrale) " \
                             "et le dire a Monsieur."
      end

      def addresses(field, value)
        list = Array(value).map { |address| address.to_s.strip }.compact_blank
        invalid = list.grep_v(EMAIL)
        raise ArgumentError, "Adresse invalide dans `#{field}` : #{invalid.join(', ')}" if invalid.any?

        list
      end
    end
  end
end
