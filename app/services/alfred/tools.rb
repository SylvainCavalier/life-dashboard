module Alfred
  # Les outils d'Alfred. Chaque outil est une classe avec `.definition` (schema JSON
  # envoye a Claude) et `#call(input)` qui renvoie un Hash serialisable. Une erreur
  # previsible est renvoyee AU MODELE ({ error: }) pour qu'il corrige son appel.
  module Tools
    ALL = [Tools::SearchCorpus, Tools::ReadDocument, Tools::DescribeModels, Tools::QueryRecords, Tools::ProposeWrite,
           Tools::SearchMails, Tools::ReadMailThread, Tools::ListMailLabels, Tools::ProposeEmail,
           Tools::ProposeMailTriage].freeze

    # Outils qui parlent a Gmail : sans GMAIL_USER ils repondent une erreur au modele.
    MAIL = [Tools::SearchMails, Tools::ReadMailThread, Tools::ListMailLabels, Tools::ProposeEmail,
            Tools::ProposeMailTriage].freeze
    # Outils qui ne font que proposer (carte a confirmer dans le chat).
    PROPOSALS = [Tools::ProposeWrite, Tools::ProposeEmail, Tools::ProposeMailTriage].freeze

    # seen : [type, id] des enregistrements renvoyes au modele pendant ce tour, seuls
    # citables comme sources (voir Alfred::Citations).
    Context = Struct.new(:conversation, :message, :seen, keyword_init: true)

    module_function

    def definitions
      # Ordre fixe : la liste des outils fait partie du prefixe mis en cache.
      ALL.map(&:definition)
    end

    # Description des outils pour la page Alfred : ce qu'ils font, ce dont ils dependent.
    def catalog
      ALL.map do |tool|
        definition = tool.definition
        mail = MAIL.include?(tool)
        {
          name: definition[:name],
          description: definition[:description],
          kind: PROPOSALS.include?(tool) ? "proposal" : "read",
          integration: mail ? "gmail" : "dashboard",
          available: mail ? Gmail.enabled? : ::Alfred.configured?
        }
      end
    end

    def find(name)
      ALL.find { |tool| tool.definition[:name] == name.to_s }
    end

    # Renvoie [resultat, erreur?].
    def run(name, input, context)
      tool = find(name) or return [{ error: "Outil inconnu : #{name}" }, true]

      input = input.respond_to?(:to_h) ? input.to_h.deep_stringify_keys : {}
      [tool.new(context).call(input), false]
    rescue DataAccess::Denied, ArgumentError, ActiveRecord::RecordNotFound, ActiveRecord::StatementInvalid,
           Gmail::Client::Error => e
      [{ error: e.message.truncate(500) }, true]
    rescue StandardError => e
      # Panne d'un service (embeddings, base...) : Alfred l'apprend et le dit, la reponse n'est pas perdue.
      Rails.logger.error "[Alfred::Tools] #{name} : #{e.class}: #{e.message}"
      [{ error: "Outil momentanement indisponible (#{e.class.name.demodulize})." }, true]
    end
  end
end
