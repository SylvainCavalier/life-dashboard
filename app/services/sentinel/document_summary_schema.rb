# Sortie structurée du résumé d'un document (OpenAI Responses API, schéma JSON
# strict). Commun à tous les domaines : ce qui varie d'un domaine à l'autre,
# c'est le prompt et la liste des catégories, pas la forme du résultat.
# Les colonnes de résumé de `sentinel_documents` reflètent exactement ce schéma.
module Sentinel
  class DocumentSummarySchema < OpenAI::BaseModel
    required :display_title, String, nil?: true,
                                     doc: "Titre clair en français si le titre d'origine est dans une autre langue ou " \
                                          "illisible (référence brute, titre à rallonge). null si le titre d'origine convient."
    required :tldr, String, doc: "Résumé en 2 ou 3 phrases : qui, quoi, portée."
    required :key_points, OpenAI::ArrayOf[String],
             doc: "3 à 6 points clés courts et factuels, du plus important au moins important"
    required :importance, OpenAI::EnumOf[:low, :medium, :high]
    required :categories, OpenAI::ArrayOf[String],
             doc: "1 à 3 slugs choisis EXCLUSIVEMENT dans la liste fournie, tableau vide si rien ne correspond"
  end
end
