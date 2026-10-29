module Alfred
  module Tools
    # Liste de courses : ajouter des articles, en retirer, ou la vider apres les courses.
    # Un seul appel pour tout un lot (« ajoute lait, oeufs et pain »), donc une seule
    # carte a confirmer dans le chat (Alfred::ShoppingActions).
    class ProposeShopping < Base
      OPERATIONS = { "add" => "shopping_add", "remove" => "shopping_remove", "clear" => "shopping_clear" }.freeze
      MAX_ITEMS = 50

      def self.definition
        {
          name: "propose_shopping",
          description: "Propose une modification de la liste de courses (page Courses, une seule liste) : add = ajouter " \
                       "des articles, remove = retirer des articles (par leur id ShoppingItem), clear = vider toute la " \
                       "liste (apres les courses). Rien n'est modifie : Monsieur confirme ou annule la carte dans le " \
                       "chat. Tous les articles d'une demande vont dans le meme appel. Un article deja dans la liste " \
                       "est signale et ignore. Apres l'appel, annoncer la proposition et s'arreter.",
          input_schema: {
            type: "object",
            properties: {
              operation: { type: "string", enum: OPERATIONS.keys },
              items: { type: "array", items: { type: "string" },
                       description: "add : les articles, un par entree, nommes simplement (« Lait », « Pommes de terre »)." },
              ids: { type: "array", items: { type: "integer" }, description: "remove : ids des ShoppingItem a retirer." },
              summary: { type: "string", description: "Resume en une phrase, en francais, affiche sur la carte." }
            },
            required: %w[operation summary]
          }
        }
      end

      def self.step_label(input) = "Proposition : liste de courses (#{input['operation']})"

      def call(input)
        operation = OPERATIONS[input["operation"].to_s] or
          raise ArgumentError, "Operation inconnue '#{input['operation']}' (add, remove ou clear)"

        payload = send(operation, input)
        return payload if payload.key?(:error)

        action = @context.conversation.actions.create!(
          message: @context.message, operation: operation, target_model: "ShoppingItem",
          summary: input["summary"].to_s.truncate(250), payload: payload.to_json
        )
        { action_id: action.id, status: "en attente de la confirmation de Monsieur dans le chat",
          note: "Rien n'a ete modifie pour l'instant." }.merge(payload.slice(:already_listed))
      end

      private

      def shopping_add(input)
        names = Array(input["items"]).map { |name| name.to_s.squish }.compact_blank.uniq(&:downcase)
        raise ArgumentError, "Aucun article a ajouter (items)" if names.empty?
        raise ArgumentError, "#{MAX_ITEMS} articles au plus par proposition" if names.size > MAX_ITEMS

        too_long = names.find { |name| name.length > ShoppingItem::MAX_LENGTH }
        raise ArgumentError, "Article trop long : #{too_long.truncate(40)}" if too_long

        listed = ShoppingItem.where("lower(name) IN (?)", names.map(&:downcase)).pluck(:name)
        fresh = names.reject { |name| listed.any? { |l| l.casecmp?(name) } }
        return { error: "Deja dans la liste : #{listed.join(', ')}. Rien a ajouter." } if fresh.empty?

        { attributes: { "articles" => fresh }, before: {}, items: fresh, already_listed: listed }.compact_blank
      end

      def shopping_remove(input)
        ids = Array(input["ids"]).map(&:to_i).uniq
        raise ArgumentError, "Aucun article a retirer (ids)" if ids.empty?

        items = ShoppingItem.where(id: ids).order(:id)
        missing = ids - items.map(&:id)
        raise ArgumentError, "Articles introuvables dans la liste : #{missing.join(', ')}" if missing.any?

        { attributes: { "articles" => items.map(&:name) }, before: {}, ids: items.map(&:id) }
      end

      def shopping_clear(_input)
        names = ShoppingItem.ordered.pluck(:name)
        return { error: "La liste de courses est deja vide." } if names.empty?

        { attributes: { "articles" => names }, before: {} }
      end
    end
  end
end
