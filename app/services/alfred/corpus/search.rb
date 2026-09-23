module Alfred
  module Corpus
    # Recherche dans le corpus. Hybride par defaut (vectoriel + lexical) : dans des
    # donnees personnelles, les noms propres et les references (« MAIF », « Dupont »,
    # un numero de facture) comptent, et un embedding les lisse.
    #
    # INVARIANTS (ne pas revenir dessus) :
    # 1. Le plancher de pertinence porte sur le COSINE BRUT. Rien en dessous
    #    n'atteint le modele : sans resultat, l'outil repond « rien trouve ».
    #    Deux planchers : absolu, et relatif au meilleur cosine de la requete.
    # 2. Le bras lexical ne fait que RECLASSER l'ensemble eligible, il ne l'elargit jamais.
    # 3. La fraicheur ne fait qu'ordonner ; le meilleur cosine brut survit toujours
    #    a la coupe (`ensure_anchor`).
    class Search
      Hit = Struct.new(:chunk, :score, :cosine, keyword_init: true)

      DEFAULT_TOP_K = 8
      MAX_TOP_K = 20
      # Calibre sur mistral-embed, dont les cosines sont tasses vers le haut : deux
      # textes francais sans rapport (une analyse de sang, un arret de la chambre
      # sociale) y sont deja a ~0.70, un passage pertinent a 0.80 et plus.
      MIN_COSINE_SIMILARITY = ENV.fetch("ALFRED_MIN_COSINE", "0.65").to_f
      # Plancher relatif : un passage a plus de cet ecart du meilleur cosine est du
      # bruit de fond, pas une piste. Sans lui, un corpus riche en veille juridique
      # remplit les resultats de jurisprudence des qu'une question porte sur autre chose.
      MAX_COSINE_GAP = ENV.fetch("ALFRED_COSINE_GAP", "0.08").to_f
      VECTOR_WEIGHT = 0.7
      LEXICAL_WEIGHT = 0.3
      CANDIDATE_MULTIPLIER = 4
      # Passages d'un meme enregistrement gardes au maximum : un long PDF ne doit
      # pas occuper tous les resultats.
      PER_SOURCE_CAP = 3

      def self.call(**opts) = new(**opts).call

      def initialize(query:, top_k: DEFAULT_TOP_K, source_types: nil, embedding_provider: Embeddings.default,
                     hybrid: ENV.fetch("ALFRED_HYBRID", "1") == "1")
        @query = query.to_s.strip
        @top_k = top_k.to_i.clamp(1, MAX_TOP_K)
        @source_types = Array(source_types).compact_blank & Corpus.indexed_models
        @embedding_provider = embedding_provider
        @hybrid = hybrid
      end

      def call
        return [] if @query.blank?

        limit = @top_k * CANDIDATE_MULTIPLIER
        eligible = vector_arm(limit)
        return [] if eligible.empty?

        lexical = @hybrid ? lexical_arm(limit) : {}
        anchor_id = eligible.max_by { |_id, data| data[:cosine] }.first

        hits = eligible.map do |id, data|
          relevance = @hybrid ? VECTOR_WEIGHT * data[:cosine] + LEXICAL_WEIGHT * lexical.fetch(id, 0.0) : data[:cosine]
          Hit.new(chunk: data[:chunk], cosine: data[:cosine], score: relevance * Recency.factor(data[:chunk].source_date))
        end.sort_by { |hit| -hit.score }

        ensure_anchor(diversify(cap_per_source(hits)), hits, anchor_id)
      end

      private

      def scope
        @source_types.any? ? AlfredChunk.where(source_type: @source_types) : AlfredChunk.all
      end

      # Les planchers s'appliquent ICI, sur le cosine brut.
      def vector_arm(limit)
        embedding = @embedding_provider.embed(texts: [@query]).first
        candidates = scope.nearest_to(embedding, limit: limit).map { |chunk| [chunk, 1.0 - chunk.neighbor_distance.to_f] }
        best = candidates.map(&:last).max or return {}
        floor = [MIN_COSINE_SIMILARITY, best - MAX_COSINE_GAP].max

        candidates.each_with_object({}) do |(chunk, cosine), eligible|
          eligible[chunk.id] = { chunk: chunk, cosine: cosine } if cosine >= floor
        end
      end

      def lexical_arm(limit)
        folded = AccentFolding.fold(@query)
        pairs = scope.search_lexical(folded).with_pg_search_rank.limit(limit).map { |chunk| [chunk.id, chunk.pg_search_rank.to_f] }
        normalize(pairs)
      rescue ActiveRecord::StatementInvalid => e
        # Une requete que tsquery ne sait pas lire ne doit pas faire perdre la recherche.
        Rails.logger.warn "[Alfred::Corpus::Search] bras lexical ignore : #{e.message.truncate(200)}"
        {}
      end

      # ts_rank n'est pas borne : normalisation min-max dans [0, 1].
      def normalize(pairs)
        return {} if pairs.empty?

        scores = pairs.map(&:last)
        span = scores.max - scores.min
        pairs.to_h { |id, raw| [id, span.zero? ? 1.0 : (raw - scores.min) / span] }
      end

      def cap_per_source(hits)
        seen = Hash.new(0)
        hits.select { |hit| (seen[[hit.chunk.source_type, hit.chunk.source_id]] += 1) <= PER_SOURCE_CAP }
      end

      # Chaque type de source eligible garde une place avant le remplissage par score :
      # vingt lignes de budget ne doivent pas evincer LE document qui repond.
      def diversify(hits)
        return hits.first(@top_k) if hits.size <= @top_k

        guaranteed = hits.group_by { |hit| hit.chunk.source_type }.values.map(&:first).sort_by { |hit| -hit.score }.first(@top_k)
        fill = (hits - guaranteed).first(@top_k - guaranteed.size)
        (guaranteed + fill).sort_by { |hit| -hit.score }
      end

      def ensure_anchor(ranked, hits, anchor_id)
        return ranked if ranked.any? { |hit| hit.chunk.id == anchor_id }

        anchor = hits.find { |hit| hit.chunk.id == anchor_id } or return ranked
        ranked.first(@top_k - 1) + [anchor]
      end
    end
  end
end
