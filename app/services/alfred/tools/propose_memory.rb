module Alfred
  module Tools
    # Memoire d'Alfred : retenir, corriger ou oublier un fait durable. Comme toute
    # ecriture, une carte a confirmer dans le chat (Alfred::MemoryActions).
    class ProposeMemory < Base
      OPERATIONS = { "remember" => "create", "revise_memory" => "update", "forget" => "delete" }.freeze

      def self.definition
        {
          name: "propose_memory",
          description: "Propose de retenir (create), corriger (update) ou oublier (delete) un fait durable dans ta memoire, " \
                       "qui figure ensuite dans ton prompt a chaque conversation (section « Memoire »). Rien n'est " \
                       "enregistre : Monsieur confirme ou annule la carte dans le chat. Un fait par memoire, court, " \
                       "autonome et ecrit a la troisieme personne (« Paul Reboh est un des meilleurs amis de Sylvain ; " \
                       "« Paul » sans precision designe Paul Reboh. »). Avant de creer, verifier qu'aucune memoire ne dit " \
                       "deja la meme chose : la corriger plutot. Apres l'appel, annoncer la proposition et s'arreter.",
          input_schema: {
            type: "object",
            properties: {
              operation: { type: "string", enum: OPERATIONS.values },
              id: { type: "integer", description: "Numero de la memoire (update et delete)." },
              content: { type: "string", description: "Le fait, #{AlfredMemory::MAX_LENGTH} caracteres au plus (create et update)." },
              category: { type: "string", enum: AlfredMemory::CATEGORIES.keys,
                          description: "people (personnes et relations), preferences, context (situation, habitudes, " \
                                       "vocabulaire), other." },
              subject_type: { type: "string", description: "Modele de la fiche concernee, si le fait s'y rapporte (Contact...)." },
              subject_id: { type: "integer", description: "Identifiant de cette fiche." },
              summary: { type: "string", description: "Resume en une phrase, en francais, affiche sur la carte." }
            },
            required: %w[operation summary]
          }
        }
      end

      def self.step_label(input) = "Proposition : memoire (#{input['operation']})"

      def call(input)
        operation = OPERATIONS.key(input["operation"].to_s) or
          raise ArgumentError, "Operation inconnue '#{input['operation']}' (create, update ou delete)"

        memory = operation == "remember" ? AlfredMemory.new : AlfredMemory.find(input["id"])
        before = operation == "remember" ? {} : MemoryActions.snapshot(memory)
        changes = operation == "forget" ? {} : changes_from(input, memory)
        raise ArgumentError, "Rien a modifier sur la memoire ##{memory.id}" if operation == "revise_memory" && changes.empty?

        memory.assign_attributes(changes)
        return { error: "Validation refusee : #{memory.errors.full_messages.to_sentence}" } unless operation == "forget" || memory.valid?

        after = operation == "forget" ? {} : MemoryActions.snapshot(memory)
        shown, shown_before = card(operation, before, after)
        action = @context.conversation.actions.create!(
          message: @context.message, operation: operation, target_model: "AlfredMemory", record_id: memory.id,
          summary: input["summary"].to_s.truncate(250),
          payload: { attributes: shown, before: shown_before, memory: after, snapshot: before }.to_json
        )
        { action_id: action.id, status: "en attente de la confirmation de Monsieur dans le chat",
          note: "Rien n'a ete enregistre pour l'instant." }
      end

      private

      # Creation : le fait ; correction : avant/apres des champs changes ; oubli : le fait oublie.
      def card(operation, before, after)
        case operation
        when "remember" then [MemoryActions.display(after), {}]
        when "revise_memory" then MemoryActions.display_diff(before, after)
        else [MemoryActions.display(before), {}]
        end
      end

      # Seuls les champs passes changent ; subject_type vide detache la fiche.
      def changes_from(input, memory)
        changes = input.slice("content", "category", "subject_type", "subject_id")
        changes["category"] ||= "other" if memory.new_record?
        changes
      end
    end
  end
end
