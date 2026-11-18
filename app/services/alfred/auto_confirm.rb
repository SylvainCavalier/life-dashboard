module Alfred
  # Actions dispensees de confirmation dans le chat (onglet Confirmations de la page Alfred).
  # Le modele ne fait toujours que proposer : c'est l'outil de proposition qui, apres avoir cree
  # l'AlfredAction, la fait executer aussitot par ActionExecutor (memes verifications qu'une
  # confirmation a la main) quand Sylvain l'a dispensee. Une regle = "Modele:operation".
  #
  # Garde-fous, independants du reglage :
  # - l'envoi d'un mail et d'un texto se confirment toujours (LOCKED) : ils ne se rattrapent pas ;
  # - rien n'est execute d'office dans une conversation qui contient du texte venu d'un tiers
  #   (texto, mail lu pendant le tour, rapport du matin qui cite des mails) : une instruction
  #   cachee dans un mail ne doit pas pouvoir ecrire sans que Sylvain voie la carte.
  module AutoConfirm
    LOCKED = %w[Gmail:send_email Sms:send_sms].freeze
    # Outils qui ramenent du texte ecrit par un tiers : une conversation qui les a appeles une
    # fois le reste (la reponse d'Alfred a pu reprendre le mail, l'historique le rejoue).
    UNTRUSTED_TOOLS = %w[search_mails read_mail_thread].freeze

    module_function

    def key_for(action) = "#{action.target_model}:#{action.operation}"

    # Groupes affiches par la page, dans l'ordre. Chaque regle : { key, label, locked }.
    def catalog
      [
        group("shopping", "Liste de courses", "ShoppingItem",
              shopping_add: "Ajouter des articles", shopping_remove: "Retirer des articles", shopping_clear: "Vider la liste"),
        group("memory", "Memoire d'Alfred", "AlfredMemory",
              remember: "Retenir un fait", revise_memory: "Corriger un fait", forget: "Oublier un fait"),
        group("gmail", "Gmail", "Gmail",
              draft_email: "Preparer un brouillon", triage_email: "Trier des mails (archiver, libeller, corbeille...)",
              send_email: "Envoyer un mail"),
        group("sms", "Textos", "Sms", send_sms: "Envoyer un texto"),
        { key: "records", label: "Fiches du dashboard",
          models: DataAccess::WRITABLE.keys.sort.map do |model|
            { model: model, create: "#{model}:create", update: "#{model}:update" }
          end }
      ]
    end

    def known_keys
      @known_keys ||= begin
        keys = catalog.flat_map { |g| g[:rules] ? g[:rules].pluck(:key) : g[:models].flat_map { |m| [m[:create], m[:update]] } }
        (keys - LOCKED).freeze
      end
    end

    def enabled?(action, setting = AlfredSetting.instance)
      key = key_for(action)
      !LOCKED.include?(key) && setting.auto_confirm.include?(key)
    end

    # Pourquoi une action dispensee reste a confirmer dans ce contexte (nil si rien ne s'y oppose).
    # Brouillon et tri de mails echappent a la regle des mails lus : ils n'ont de sens qu'apres
    # lecture de la boite, restent dans la boite et se rattrapent (brouillon jamais envoye,
    # corbeille videe au bout de 30 jours). Un texto, lui, bloque tout.
    def blocked_reason(action, context)
      conversation = context.conversation
      return "conversation issue d'un texto" if conversation.sms_correspondent_id
      return nil if action.target_model == "Gmail"
      return "conversation sur un rapport du matin, qui cite des mails" if conversation.daily_report_id
      return "contenu venu d'un tiers (mail ou texto) lu dans cette conversation" if context.untrusted || read_mails?(conversation)

      nil
    end

    def read_mails?(conversation)
      conversation.messages.where(role: "assistant")
                  .where("EXISTS (SELECT 1 FROM jsonb_array_elements(steps) AS step WHERE step->>'tool' IN (?))", UNTRUSTED_TOOLS)
                  .exists?
    end

    # Execute l'action si le reglage le permet. Renvoie true si elle a ete traitee (executee ou en echec).
    def apply!(action, context)
      return false unless enabled?(action)
      return false if blocked_reason(action, context)

      action.update!(auto_confirmed: true)
      ActionExecutor.new(action).confirm!
      true
    end

    def group(key, label, target, rules)
      { key: key, label: label,
        rules: rules.map do |operation, text|
          rule = "#{target}:#{operation}"
          { key: rule, label: text, locked: LOCKED.include?(rule) }
        end }
    end
  end
end
