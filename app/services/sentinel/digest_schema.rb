# Sortie structurée de la synthèse hebdomadaire. Le Hash stocké dans
# `sentinel_weeks.digest` reflète exactement ce schéma (l'interface et Alfred
# s'y fient).
module Sentinel
  class DigestSchema < OpenAI::BaseModel
    class TopDocument < OpenAI::BaseModel
      required :document_id, Integer, doc: "Identifiant d'un document de la liste fournie"
      required :why, String, doc: "Une phrase : pourquoi ce document est notable cette semaine"
    end

    required :tldr, String,
             doc: "Synthèse globale en 3 à 5 phrases : l'orientation générale de la semaine, sans énumérer les documents"
    required :key_themes, OpenAI::ArrayOf[String],
             doc: "3 à 6 thèmes saillants, formulés court. Agrège ce qui se recoupe, ne répète pas les titres."
    required :top_documents, OpenAI::ArrayOf[TopDocument],
             doc: "Au maximum 5 documents à ne pas manquer. Moins si la semaine est calme."
    required :impact_summary, String, doc: "1 ou 2 phrases sur ce que la semaine change concrètement pour le lecteur"
  end
end
