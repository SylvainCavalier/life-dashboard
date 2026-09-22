module Alfred
  module Tools
    # Tri de la boite : archiver, marquer lu, etoiler, etiqueter, mettre a la
    # corbeille... par lots de fils. Comme toute ecriture, une carte a confirmer.
    class ProposeMailTriage < Base
      ACTIONS = %w[archive unarchive mark_read mark_unread star unstar add_label remove_label trash untrash].freeze
      LABEL_ACTIONS = %w[add_label remove_label].freeze
      LABELS_FR = {
        "archive" => "archiver", "unarchive" => "remettre en boite de reception", "mark_read" => "marquer lu",
        "mark_unread" => "marquer non lu", "star" => "etoiler", "unstar" => "retirer l'etoile",
        "add_label" => "ajouter le libelle", "remove_label" => "retirer le libelle",
        "trash" => "mettre a la corbeille", "untrash" => "sortir de la corbeille"
      }.freeze
      MAX_THREADS = 50

      def self.definition
        {
          name: "propose_mail_triage",
          description: "Propose un tri sur un lot de fils Gmail : #{ACTIONS.join(', ')}. Rien n'est modifie : Monsieur " \
                       "voit la liste des fils et les actions dans le chat et confirme lui-meme. Une proposition par lot " \
                       "homogene (memes actions pour tous les fils). Pas de suppression definitive : trash met a la " \
                       "corbeille (30 jours). Apres l'appel, annoncer la proposition en une phrase et s'arreter.",
          input_schema: {
            type: "object",
            properties: {
              thread_ids: { type: "array", items: { type: "string" },
                            description: "Fils concernes (1 a #{MAX_THREADS})." },
              actions: { type: "array", items: { type: "string", enum: ACTIONS },
                         description: "Actions a appliquer, dans l'ordre." },
              label: { type: "string",
                       description: "Nom du libelle (add_label / remove_label). Cree s'il n'existe pas." },
              summary: { type: "string", description: "Resume en une phrase, en francais, affiche sur la carte." }
            },
            required: %w[thread_ids actions summary]
          }
        }
      end

      def self.step_label(input) = "Proposition : tri de #{Array(input['thread_ids']).size} fil(s)"

      def call(input)
        ensure_gmail!

        thread_ids = Array(input["thread_ids"]).map { |id| id.to_s.strip }.compact_blank.uniq
        actions = Array(input["actions"]).map(&:to_s).uniq
        label = input["label"].to_s.strip.presence
        validate!(thread_ids, actions, label)

        threads = Gmail.client.threads_summary(thread_ids)
        missing = thread_ids - threads.pluck(:thread_id)
        raise ArgumentError, "Fils introuvables : #{missing.join(', ')}" if missing.any?

        attributes = {
          fils: threads.map { |thread| "#{thread[:subject]} (#{thread[:from]})" },
          actions: actions.map { |action| LABELS_FR[action] }
        }
        attributes[:libelle] = label if label
        action = @context.conversation.actions.create!(
          message: @context.message, operation: "triage_email", target_model: "Gmail",
          summary: input["summary"].to_s.truncate(250),
          payload: { attributes: attributes, before: {}, triage: { thread_ids: thread_ids, actions: actions, label: label } }.to_json
        )
        { action_id: action.id, status: "en attente de la confirmation de Monsieur dans le chat",
          note: "Rien n'a ete modifie pour l'instant." }
      end

      private

      def validate!(thread_ids, actions, label)
        size_ok = thread_ids.size.between?(1, MAX_THREADS)
        raise ArgumentError, "`thread_ids` doit contenir de 1 a #{MAX_THREADS} fils" unless size_ok

        unknown = actions - ACTIONS
        raise ArgumentError, "Actions inconnues : #{unknown.join(', ')}" if unknown.any? || actions.empty?

        needs_label = actions.intersect?(LABEL_ACTIONS) && label.nil?
        raise ArgumentError, "`label` est requis pour add_label / remove_label" if needs_label
      end
    end
  end
end
