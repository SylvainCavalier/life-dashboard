module Alfred
  # Sources affichees sous une reponse. Alfred marque dans son texte chaque
  # enregistrement sur lequel il s'appuie ([[Document#12]]) ; ne deviennent des
  # sources que les marqueurs qui designent un enregistrement que SES OUTILS lui
  # ont renvoye pendant ce tour (garde anti-hallucination : un identifiant invente
  # ne produit pas de lien). Les marqueurs sont retires du texte final.
  #
  # Ne pas revenir a « toutes les fiches consultees » : la recherche ramene aussi
  # des passages voisins sans rapport, qui se retrouvaient affiches comme sources.
  module Citations
    MARKER = / ?\[\[([A-Z][A-Za-z]+)#(\d+)\]\]/

    module_function

    # Renvoie [texte sans marqueurs, sources].
    def extract(text, seen:)
      keys = text.to_s.scan(MARKER).map { |type, id| [type, id.to_i] }.uniq
      sources = keys.select { |key| seen.include?(key) }.filter_map { |type, id| source_for(type, id) }
      [text.to_s.gsub(MARKER, ""), sources]
    end

    def source_for(type, id)
      config = Corpus.config_for(type)
      return nil if config.nil? || config[:parent]

      record = type.constantize.find_by(id: id) or return nil
      {
        "type" => type, "id" => id, "label" => config[:label].call(record).to_s.truncate(80),
        "page" => config[:path]&.call(record),
        "download" => (type == "Document" ? "/api/documents/#{id}/download" : nil)
      }.compact
    end
  end
end
