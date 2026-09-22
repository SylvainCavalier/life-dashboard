module Alfred
  module Tools
    # Libelles de la boite Gmail, pour trier ou filtrer (label:nom).
    class ListMailLabels < Base
      def self.definition
        {
          name: "list_mail_labels",
          description: "Liste les libelles (dossiers) de la boite Gmail de Monsieur, systeme et personnalises, et les " \
                       "adresses d'envoi disponibles (alias verifies, pour `from` de propose_email). A appeler avant " \
                       "un tri par libelle, une recherche label:nom ou une reponse depuis une autre adresse.",
          input_schema: { type: "object", properties: {} }
        }
      end

      def self.step_label(_input) = "Libelles et alias Gmail"

      def call(_input)
        ensure_gmail!

        client = Gmail.client
        { labels: client.labels.map { |label| { name: label[:name], type: label[:type] } },
          send_as: client.send_as_aliases }
      end
    end
  end
end
