# Structured output schema for the AI trip report (OpenAI Responses API,
# strict JSON schema). Every field is required by the API; optional values
# are declared nullable with `nil?: true`.
#
# The Hash stored in `trip_plans.content` mirrors this structure exactly, so
# the Vue report component and Alfred can rely on it.
module Trips
  class TripPlanSchema < OpenAI::BaseModel
    class PracticalInfo < OpenAI::BaseModel
      required :label, String,
               doc: "Sujet : monnaie, langue, prises électriques, visa, décalage horaire, santé, sécurité..."
      required :value, String, doc: "Information concise"
    end

    class Rule < OpenAI::BaseModel
      required :title, String, doc: "Intitulé court de la règle, loi, interdiction ou usage"
      required :detail, String, doc: "Explication pratique pour le voyageur"
    end

    class Costs < OpenAI::BaseModel
      required :flights_eur, Float, doc: "Vols aller-retour pour l'ensemble des voyageurs, en euros"
      required :lodging_per_night_eur, Float, doc: "Hébergement par nuit pour l'ensemble des voyageurs, en euros"
      required :food_per_day_eur, Float, doc: "Nourriture par jour pour l'ensemble des voyageurs, en euros"
      required :activities_eur, Float, doc: "Visites et activités sur tout le séjour, en euros"
      required :total_eur, Float, doc: "Total estimé du séjour pour l'ensemble des voyageurs, en euros"
      required :local_currency, String, doc: "Code ISO de la monnaie locale"
      required :exchange_rate_note, String, doc: "Taux de change utilisé et sa date"
      required :assumptions, OpenAI::ArrayOf[String],
               doc: "Hypothèses retenues (classe de vol, catégorie d'hôtel, saison...)"
    end

    class Place < OpenAI::BaseModel
      required :name, String
      required :description, String, doc: "Pourquoi y aller, en deux ou trois phrases"
      required :city, String, doc: "Ville ou zone"
      required :price_eur, Float, nil?: true, doc: "Prix d'entrée par personne en euros, null si inconnu"
      required :price_note, String, nil?: true, doc: "Précision sur le prix (gratuit, tarif réduit...)"
      required :booking_url, String, nil?: true,
                                     doc: "Lien officiel ou de réservation trouvé sur le web, null si aucun lien fiable"
    end

    class Restaurant < OpenAI::BaseModel
      required :name, String
      required :cuisine, String, doc: "Type de cuisine, de préférence locale"
      required :city, String
      required :price_range, OpenAI::EnumOf[:€, :€€, :€€€, :€€€€]
      required :url, String, nil?: true,
                             doc: "Site, page de réservation ou fiche trouvée sur le web, null si aucun lien fiable"
      required :note, String, nil?: true, doc: "Spécialité ou conseil"
    end

    class Activity < OpenAI::BaseModel
      required :moment, OpenAI::EnumOf[:matin, :midi, :apres_midi, :soir]
      required :title, String
      required :description, String
      required :place_name, String, nil?: true,
                                    doc: "Nom du lieu ou du restaurant concerné, s'il figure dans les listes"
      required :url, String, nil?: true
    end

    class ItineraryDay < OpenAI::BaseModel
      required :day_number, Integer, doc: "Numéro du jour, de 1 au nombre de jours du séjour"
      required :title, String, doc: "Thème de la journée"
      required :activities, OpenAI::ArrayOf[Activity]
    end

    class Source < OpenAI::BaseModel
      required :title, String
      required :url, String
    end

    required :summary, String,
             doc: "Présentation du pays et de la destination : ambiance, saison aux dates du voyage, ce qui la caractérise"
    required :history, String, doc: "Résumé historique du pays ou de la ville, en quelques paragraphes"
    required :practical_info, OpenAI::ArrayOf[PracticalInfo]
    required :rules, OpenAI::ArrayOf[Rule],
             doc: "Interdictions, lois et réglementations particulières, usages à respecter"
    required :costs, Costs
    required :places, OpenAI::ArrayOf[Place], doc: "6 à 10 lieux à visiter"
    required :restaurants, OpenAI::ArrayOf[Restaurant], doc: "5 à 8 restaurants, cuisine locale de préférence"
    required :itinerary, OpenAI::ArrayOf[ItineraryDay], doc: "Un élément par jour du séjour"
    required :sources, OpenAI::ArrayOf[Source], doc: "Pages web consultées pour les prix et les liens"
  end
end
