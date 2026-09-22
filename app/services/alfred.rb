# Alfred, l'intendant du dashboard : un agent a outils (Claude) adosse a un corpus
# RAG (pgvector + mistral-embed) qui couvre les documents et les donnees du dashboard.
# Vue d'ensemble dans CLAUDE.md, section « Alfred dans le dashboard ».
module Alfred
  module_function

  def model
    ENV.fetch("ALFRED_MODEL", "claude-sonnet-5")
  end

  def llm_configured?
    ENV["ANTHROPIC_API_KEY"].present?
  end

  def corpus_configured?
    Embeddings.configured?
  end

  def configured?
    llm_configured? && corpus_configured?
  end

  def missing_keys
    [("ANTHROPIC_API_KEY" unless llm_configured?), ("MISTRAL_API_KEY" unless corpus_configured?)].compact
  end
end
