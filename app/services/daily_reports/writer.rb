module DailyReports
  # Seconde etape du rapport du matin : un seul appel a Claude, en sortie structuree,
  # sur l'instantane du Collector. Pas de boucle d'outils : tout ce qu'Alfred doit voir
  # est deja dans l'instantane, ce qui garde le cout fixe et le rapport complet.
  # Le personnage est celui du chat (sections « Sylvain » et « Ton » d'Alfred::Prompt,
  # memoires comprises) ; la consigne est la section « Rapport du matin », modifiable
  # depuis la page Alfred. Ne touche pas a la base : renvoie { content:, model:, usage: }.
  class Writer < StructuredSummarizer
    item = {
      type: "object",
      additionalProperties: false,
      required: %w[title detail urgent refs],
      properties: {
        title: { type: "string", description: "Titre court de l'element." },
        detail: { type: "string", description: "Une a trois phrases." },
        urgent: { type: "boolean", description: "Vrai seulement pour ce qui ne peut pas attendre demain." },
        refs: { type: "array", items: { type: "string" }, description: "References (\"ref\") de l'instantane qui fondent l'element, recopiees a l'identique." }
      }
    }
    items = { type: "array", items: item }

    SCHEMA = {
      type: "object",
      additionalProperties: false,
      required: %w[headline opening] + DailyReport::SECTIONS + %w[closing],
      properties: {
        headline: { type: "string", description: "Resume de la journee en moins de 120 caracteres (notification push)." },
        opening: { type: "string" },
        **DailyReport::SECTIONS.to_h { |key| [key.to_sym, items] },
        closing: { type: "string" }
      }
    }.freeze

    def self.model
      ENV.fetch("DAILY_REPORT_MODEL") { super }
    end

    def self.effort
      ENV.fetch("DAILY_REPORT_EFFORT", "medium")
    end

    def initialize(snapshot, client: nil)
      super(client: client)
      @snapshot = snapshot
    end

    def call
      content, model = request(system: self.class.system_prompt, schema: SCHEMA, prompt: user_prompt)
      { content: sanitize(content), model: model, usage: usage }
    end

    def self.system_prompt
      setting = AlfredSetting.instance
      section = ->(key) { setting.override_for(key).presence || Alfred::Prompt.default_for(key) }
      <<~TEXT
        Tu es Alfred, l'intendant personnel de Sylvain, installé dans son life-dashboard (application personnelle, mono-utilisateur).

        ## Sylvain
        #{section.call('sylvain')}

        ## Ton
        #{section.call('tone')}

        ## Boîtes mail
        #{Alfred::Prompt.mailboxes_text}

        ## Mémoire
        #{Alfred::Prompt.memories_text}

        ## Rapport du matin
        #{section.call('daily_report')}
      TEXT
    end

    private

    def user_prompt
      date = Date.iso8601(@snapshot["date"])
      <<~TEXT
        Rapport du #{DailyReport.human_date(date)}#{' (week-end : version allégée)' if @snapshot['weekend']}.
        Les nombres de jours (in_days, age_days...) sont comptés à partir d'aujourd'hui ; les heures sont celles de Paris.

        Instantané :
        #{JSON.pretty_generate(@snapshot.except('refs'))}
      TEXT
    end

    # Garde anti-hallucination : une reference absente de l'instantane est ecartee,
    # comme un element sans titre.
    def sanitize(content)
      known = (@snapshot["refs"] || {}).keys.to_set
      DailyReport::SECTIONS.each do |key|
        content[key] = Array(content[key]).filter_map do |entry|
          next if entry["title"].to_s.strip.empty?

          entry.merge("refs" => Array(entry["refs"]).map(&:to_s).select { |ref| known.include?(ref) }.uniq)
        end
      end
      content
    end
  end
end
