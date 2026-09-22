# Fabrique du fournisseur d'embeddings. Le reste de l'application appelle
# `Embeddings.default.embed(texts:)` et ne connait jamais Mistral directement.
module Embeddings
  DIMENSIONS = 1024 # DOIT egaler vector(N) sur alfred_chunks / embedding_caches ET la dimension du modele

  module_function

  def default
    provider = build_provider(provider_name)
    cache_enabled? ? CachingProvider.new(provider) : provider
  end

  def provider_name
    ENV.fetch("EMBEDDING_PROVIDER", "mistral")
  end

  def build_provider(name)
    case name
    when "mistral" then MistralProvider.new
    else raise ArgumentError, "EMBEDDING_PROVIDER inconnu : #{name.inspect}"
    end
  end

  def cache_enabled?
    ENV.fetch("EMBEDDING_CACHE", Rails.env.test? ? "0" : "1") == "1"
  end

  def configured?
    provider_name == "mistral" && ENV["MISTRAL_API_KEY"].present?
  end
end
