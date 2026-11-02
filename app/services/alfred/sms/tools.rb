module Alfred
  module Sms
    # Les seuls outils d'Alfred par texto. Volontairement hors d'Alfred::Tools::ALL :
    # aucun acces a la base en dehors de ce que ces deux classes renvoient.
    module Tools
      DEFINITIONS = [
        {
          name: "get_availability",
          description: "Disponibilités de Sylvain d'après son agenda, sur une période : créneaux occupés et libres (8 h - 21 h), " \
                       "sans jamais le contenu des rendez-vous. all_day_event = quelque chose est noté sur toute la journée.",
          input_schema: {
            type: "object",
            properties: {
              from_date: { type: "string", description: "Premier jour, AAAA-MM-JJ." },
              to_date: { type: "string", description: "Dernier jour, AAAA-MM-JJ. 31 jours au plus après le premier." }
            },
            required: %w[from_date to_date]
          }
        },
        {
          name: "propose_to_sylvain",
          description: "Transmet à Sylvain une demande de tâche ou de rendez-vous : il reçoit une notification et décide lui-même " \
                       "de l'ajouter ou non. Rien n'est ajouté tant qu'il n'a pas accepté. Une seule proposition par demande.",
          input_schema: {
            type: "object",
            properties: {
              kind: { type: "string", enum: %w[task event] },
              description: { type: "string", description: "task : ce qu'il y a à faire, formulé simplement (« Faire la vaisselle »)." },
              deadline: { type: "string", description: "task, facultatif : date limite demandée, AAAA-MM-JJ." },
              title: { type: "string", description: "event : intitulé du rendez-vous." },
              start_time: { type: "string", description: "event : début, AAAA-MM-JJTHH:MM, heure de Paris." },
              end_time: { type: "string", description: "event, facultatif : fin, même format." },
              location: { type: "string", description: "event, facultatif : lieu." },
              summary: { type: "string", description: "La demande en une phrase, pour Sylvain." }
            },
            required: %w[kind summary]
          }
        }
      ].freeze

      module_function

      def definitions = DEFINITIONS

      # Renvoie [resultat, erreur?]. Une erreur previsible revient au modele pour qu'il
      # corrige son appel ou explique le probleme a son correspondant.
      def run(name, input, correspondent:, inbound:)
        case name.to_s
        when "get_availability" then [Availability.new(input["from_date"], input["to_date"]).call, false]
        when "propose_to_sylvain" then [RequestProposal.new(correspondent, inbound, input).call, false]
        else [{ error: "Outil inconnu : #{name}" }, true]
        end
      rescue ArgumentError => e
        [{ error: e.message.truncate(300) }, true]
      rescue StandardError => e
        Rails.logger.error "[Alfred::Sms::Tools] #{name} : #{e.class}: #{e.message}"
        [{ error: "Outil momentanément indisponible." }, true]
      end
    end
  end
end
