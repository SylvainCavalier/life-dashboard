module Embeddings
  # Decorateur : memorise les embeddings de n'importe quel fournisseur dans
  # `embedding_caches`, par (fournisseur, modele, SHA256 du texte). Les appelants
  # ne changent pas : ils recoivent toujours un vecteur par texte, dans l'ordre.
  class CachingProvider < BaseProvider
    def initialize(inner)
      @inner = inner
    end

    def name = @inner.name

    def model = @inner.respond_to?(:model) ? @inner.model : nil

    def embed(texts:)
      texts = Array(texts)
      return [] if texts.empty?

      digests = texts.map { |text| EmbeddingCache.digest(text) }
      cached = fetch_cached(digests.uniq)

      missing = digests.uniq.reject { |digest| cached.key?(digest) }
      compute_and_store(missing, digests, texts, cached) unless missing.empty?

      digests.map { |digest| cached[digest] }
    end

    private

    def fetch_cached(digests)
      EmbeddingCache
        .where(provider: provider_key, model: model_key, content_hash: digests)
        .index_by(&:content_hash)
        .transform_values(&:embedding)
    end

    def compute_and_store(missing, digests, texts, cached)
      representative = {}
      digests.each_with_index { |digest, idx| representative[digest] ||= texts[idx] }

      computed = @inner.embed(texts: missing.map { |digest| representative[digest] })

      missing.each_with_index do |digest, idx|
        cached[digest] = computed[idx]
        store(digest, computed[idx])
      end
    end

    # Insertion idempotente : un ecrivain concurrent leve RecordNotUnique, la valeur est la meme.
    def store(digest, embedding)
      EmbeddingCache.create!(provider: provider_key, model: model_key, content_hash: digest, embedding: embedding)
    rescue ActiveRecord::RecordNotUnique
      nil
    end

    def provider_key = @inner.name

    def model_key = model.presence || "default"
  end
end
