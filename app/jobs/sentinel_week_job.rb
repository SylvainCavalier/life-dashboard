# Traite une semaine de veille d'un domaine, en trois étapes :
#   1. collect   : Sentinel::Collector (sources -> documents dédoublonnés et triés)
#   2. summarize : Sentinel::DocumentSummarizer sur les documents retenus non résumés
#   3. digest    : Sentinel::DigestGenerator à partir des résumés
#
# Chaque étape est reprenable : un document déjà collecté ou déjà résumé n'est
# pas retraité. Relancer une semaine en échec (ou interrompue par un
# redémarrage du dyno) ne repaie donc que ce qui manque. La synthèse précédente
# reste consultable tant que la nouvelle n'a pas abouti.
class SentinelWeekJob < ApplicationJob
  queue_as :default

  discard_on ActiveRecord::RecordNotFound

  # Borne le coût d'un lancement. Le surplus est signalé et traité à la relance.
  MAX_SUMMARIES_PER_RUN = 80
  # Les résumés sont des appels réseau indépendants : quelques fils divisent
  # la durée d'une semaine par autant, sans toucher à la base (service pur).
  SUMMARY_THREADS = 4
  # Erreurs qui toucheront tous les appels suivants de la même façon.
  SYSTEMIC_ERRORS = [
    OpenAI::Errors::AuthenticationError, OpenAI::Errors::PermissionDeniedError, OpenAI::Errors::NotFoundError
  ].freeze

  def perform(week_id)
    week = SentinelWeek.find(week_id)
    # Idempotence : une ré-exécution GoodJob d'un job déjà traité ne relance rien.
    return unless week.status == "pending"

    week.update!(status: "running", started_at: Time.current, warnings: [])

    warnings = Sentinel::Collector.new(week).call
    warnings += summarize(week)
    warnings += digest(week)

    week.update!(status: "done", step: nil, error: nil, warnings: warnings, finished_at: Time.current)
    Rails.logger.info "[SentinelWeekJob] #{week.domain} #{week.monday} : #{week.documents.count} documents"
  rescue ActiveRecord::RecordNotFound
    raise
  rescue StandardError => e
    message = readable_error(e)
    Rails.logger.error "[SentinelWeekJob] semaine ##{week_id} en echec : #{message}"
    week&.update!(status: "failed", error: message.truncate(1000), finished_at: Time.current)
  end

  private

  def summarize(week)
    pending = week.documents.relevant.unsummarized.includes(:sentinel_source).order(:id).to_a
    return [] if pending.empty?
    raise Sentinel::Llm::Error, "OPENAI_API_KEY absente de l'environnement" unless Sentinel::Llm.configured?

    batch = pending.first(MAX_SUMMARIES_PER_RUN)
    week.advance!("summarize", total: batch.size)
    domain = week.domain_config
    failures = 0

    batch.each_slice(SUMMARY_THREADS) do |slice|
      results = slice.map { |document| Thread.new { summarize_one(document, domain) } }.map(&:value)

      slice.zip(results).each do |document, result|
        result.is_a?(Hash) ? document.update!(result) : failures += 1
        week.tick!
      end
      # Clé invalide, modèle inconnu, quota épuisé : inutile d'insister sur les 70 suivants.
      fatal = results.find { |result| SYSTEMIC_ERRORS.any? { |klass| result.is_a?(klass) } }
      fatal ||= results.first if results.all?(OpenAI::Errors::RateLimitError)
      raise fatal if fatal
    end

    warnings = []
    warnings << "#{failures} document(s) n'ont pas pu être résumés : relancer la veille pour réessayer" if failures.positive?
    if pending.size > batch.size
      warnings << "#{pending.size - batch.size} document(s) restent à résumer (plafond de #{MAX_SUMMARIES_PER_RUN} " \
                  "par lancement) : relancer la veille pour continuer"
    end
    warnings
  end

  # Exécuté dans un fil : ne renvoie jamais d'exception, mais l'erreur elle-même.
  def summarize_one(document, domain)
    Rails.application.executor.wrap do
      Sentinel::DocumentSummarizer.new(document, domain: domain).call
    end
  rescue StandardError => e
    Rails.logger.warn "[SentinelWeekJob] resume du document ##{document.id} en echec : #{readable_error(e)}"
    e
  end

  def digest(week)
    documents = week.documents.relevant.summarized.includes(:sentinel_source).to_a
    if documents.empty?
      week.update!(digest: {}, digest_model: nil, digest_generated_at: nil)
      return ["Aucun document pertinent cette semaine : pas de synthèse"]
    end

    week.advance!("digest", total: 1)
    result = Sentinel::DigestGenerator.new(week, documents).call
    week.update!(digest: result[:content], digest_model: result[:model], digest_generated_at: Time.current)
    week.tick!
    []
  end

  # Le message d'une erreur HTTP OpenAI ne contient que le statut et l'URL ;
  # le libellé utile (quota épuisé, modèle inconnu...) est dans le corps.
  def readable_error(error)
    return "#{error.class}: #{error.message}" unless error.is_a?(OpenAI::Errors::APIStatusError)

    body = error.body
    detail = body.is_a?(Hash) ? (body.dig(:error, :message) || body.dig("error", "message")) : nil
    "OpenAI (HTTP #{error.status}) : #{detail.presence || error.message}"
  end
end
