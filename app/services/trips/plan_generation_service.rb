# Builds the AI trip report by calling the OpenAI Responses API with the
# hosted web search tool and a strict structured output schema
# (Trips::TripPlanSchema). Pure: no database access, so it can be unit tested
# by injecting a fake client.
#
# Returns { content: Hash (string keys), model: String }.
module Trips
  class PlanGenerationService
    class Error < StandardError; end
    class EmptyResponse < Error; end

    DEFAULT_MODEL = "gpt-5.6-sol"
    # The default client timeout (600 s) would pin a web thread for too long:
    # GoodJob runs inside the web dyno.
    TIMEOUT_SECONDS = 240

    def initialize(trip, client: nil)
      @trip = trip
      @client = client
      @model = ENV.fetch("OPENAI_TRIP_MODEL", DEFAULT_MODEL)
    end

    def call
      response = client.responses.create(
        model: @model,
        instructions: instructions,
        input: input,
        tools: [web_search_tool],
        text: Trips::TripPlanSchema
      )

      { content: extract_content(response), model: response.model.to_s }
    end

    private

    def client
      @client ||= OpenAI::Client.new(api_key: ENV.fetch("OPENAI_API_KEY"), timeout: TIMEOUT_SECONDS)
    end

    def web_search_tool
      {
        type: "web_search",
        search_context_size: "medium",
        user_location: {
          type: "approximate",
          country: "FR",
          city: @trip.departure_city.presence || "Paris",
          timezone: "Europe/Paris"
        }
      }
    end

    # The response output holds web_search_call items followed by one or more
    # message items. Only message contents of type output_text carry `parsed`.
    def extract_content(response)
      messages = response.output.grep(OpenAI::Models::Responses::ResponseOutputMessage)
      contents = messages.flat_map(&:content)

      refusal = contents.grep(OpenAI::Models::Responses::ResponseOutputRefusal).first
      raise EmptyResponse, "Le modèle a refusé de répondre : #{refusal.refusal}" if refusal

      parsed = contents.grep(OpenAI::Models::Responses::ResponseOutputText).filter_map(&:parsed).first
      raise EmptyResponse, "Réponse vide ou non structurée du modèle" if parsed.nil?

      JSON.parse(parsed.to_json)
    end

    def instructions
      trip = @trip
      <<~TEXT
        Tu es un conseiller voyage expérimenté. Tu prépares un dossier complet, en français, pour un voyageur qui part de #{trip.departure_city.presence || 'Paris'} (France).

        Méthode :
        - Utilise la recherche web pour obtenir des prix et des liens ACTUELS (billets d'avion aux dates indiquées, hôtels, entrées des sites, restaurants). Ne devine pas un prix quand une recherche peut le donner.
        - N'invente jamais d'URL. Un lien doit provenir d'une page réellement consultée (site officiel, office de tourisme, plateforme de réservation reconnue). Sinon mets null.
        - Tous les montants sont en EUROS. Convertis les prix locaux et indique le taux utilisé dans exchange_rate_note.
        - Les coûts sont calculés pour #{trip.travelers} voyageur(s) au total : vols aller-retour, hébergement par nuit, nourriture par jour, activités. total_eur = vols + (nombre de nuits x hébergement par nuit) + (nombre de jours x nourriture par jour) + activités. Liste tes hypothèses (classe économique, hôtel 3 étoiles, restaurants locaux...) dans assumptions.
        - L'itinéraire couvre EXACTEMENT #{trip.duration_days} jour(s), day_number de 1 à #{trip.duration_days}, en tenant compte de la saison aux dates données et des temps de trajet.
        - Propose 6 à 10 lieux à visiter et 5 à 8 restaurants, de préférence de cuisine locale, avec leur fourchette de prix.
        - Dans rules, concentre-toi sur ce qui peut poser problème à un voyageur français : interdictions, lois particulières, douane, visa, conduite, pourboire, tenue vestimentaire, drones, alcool, photos, comportements à éviter.
        - Dans practical_info, couvre au minimum : monnaie, langue, prises électriques, visa ou formalités, décalage horaire, santé et vaccins, sécurité, transports locaux.
        - Sois précis et concis : pas de remplissage, des faits utiles.
      TEXT
    end

    def input
      trip = @trip
      parts = [
        "Voyage à #{trip.destination} (pays : #{trip.country_code.upcase}, code ISO 3166-1 alpha-2)",
        "du #{trip.start_date.strftime('%d/%m/%Y')} au #{trip.end_date.strftime('%d/%m/%Y')} (#{trip.duration_days} jour(s), #{trip.duration_days - 1} nuit(s))",
        "#{trip.travelers} voyageur(s)",
        "départ de #{trip.departure_city.presence || 'Paris'}"
      ]
      text = parts.join(", ") + "."
      text += "\nNotes du voyageur : #{trip.notes}" if trip.notes.present?
      text
    end
  end
end
