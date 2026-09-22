module Alfred
  module Tools
    # Alfred n'ecrit jamais lui-meme. Cet outil valide la demande et enregistre une
    # AlfredAction « proposed » : une carte de confirmation apparait dans le chat et
    # seule la confirmation de Sylvain (Alfred::ActionExecutor) touche a la base.
    class ProposeWrite < Base
      def self.definition
        {
          name: "propose_write",
          description: "Propose la creation ou la modification d'UN enregistrement. Rien n'est ecrit : Monsieur voit une carte " \
                       "avant/apres dans le chat et confirme ou annule lui-meme. Pour une modification, lire d'abord " \
                       "l'enregistrement (query_records) et ne passer que les champs qui changent. Ne jamais inventer une valeur " \
                       "manquante : la demander. Pas de suppression. Apres l'appel, annoncer brievement la proposition et s'arreter.",
          input_schema: {
            type: "object",
            properties: {
              operation: { type: "string", enum: AlfredAction::OPERATIONS },
              model: { type: "string", enum: DataAccess::WRITABLE.keys },
              id: { type: "integer", description: "Identifiant de l'enregistrement (update uniquement)." },
              attributes: { type: "object", description: "Champs et valeurs a ecrire." },
              summary: { type: "string", description: "Resume en une phrase, en francais, affiche sur la carte." }
            },
            required: %w[operation model attributes summary]
          }
        }
      end

      def self.step_label(input) = "Proposition : #{input['operation']} #{input['model']}"

      def call(input)
        operation = input["operation"].to_s
        name = input["model"].to_s
        klass = DataAccess.writable_class(name)
        raise ArgumentError, "Operation inconnue '#{operation}'" unless AlfredAction::OPERATIONS.include?(operation)

        attributes = input["attributes"]
        raise ArgumentError, "`attributes` doit etre un objet non vide" unless attributes.is_a?(Hash) && attributes.any?

        forbidden = attributes.keys.map(&:to_s) - DataAccess.writable_fields(name, operation)
        raise ArgumentError, "Champs non modifiables sur #{name} : #{forbidden.join(', ')}" if forbidden.any?

        record = operation == "update" ? klass.find(input["id"]) : klass.new
        before = operation == "update" ? DataAccess.serialize(record, attributes.keys.map(&:to_s)) : {}
        record.assign_attributes(attributes)
        return { error: "Validation refusee : #{record.errors.full_messages.to_sentence}" } unless record.valid?

        action = @context.conversation.actions.create!(
          message: @context.message, operation: operation, target_model: name, record_id: record.id,
          summary: input["summary"].to_s.truncate(250), payload: { attributes: attributes, before: before }.to_json
        )
        { action_id: action.id, status: "en attente de la confirmation de Monsieur dans le chat",
          note: "Rien n'a ete ecrit pour l'instant." }
      end
    end
  end
end
