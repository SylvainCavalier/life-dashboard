# Étape 1 du traitement d'une semaine : interroge chaque source active du
# domaine par tous ses canaux (adaptateur, flux RSS, recherche web), dédoublonne
# sur [source, external_id], puis classe chaque nouveau document avec le
# classifieur déterministe du domaine.
#
# Une source en panne ne fait jamais échouer la semaine : l'erreur est notée
# sur la source et remontée en avertissement. Renvoie la liste des avertissements.
module Sentinel
  class Collector
    ADAPTERS = {
      "judilibre" => "Sentinel::Adapters::Judilibre",
      "legifrance" => "Sentinel::Adapters::Legifrance",
      "village_justice" => "Sentinel::Adapters::VillageJustice"
    }.freeze

    # En dessous, le texte vient sans doute d'un extrait de flux : on va chercher la page.
    FULL_TEXT_THRESHOLD = 1500

    def initialize(week)
      @week = week
      @domain = week.domain_config
      @warnings = []
    end

    def call
      sources = SentinelSource.for_domain(@domain.key).active.ordered.to_a
      @warnings << "Aucune source active pour ce domaine" if sources.empty?
      @week.advance!("collect", total: sources.size)

      web_results = web_search(sources)

      sources.each do |source|
        collect_source(source, web_results.fetch(source, []))
        @week.tick!
      end

      @warnings
    end

    private

    def collect_source(source, web_documents)
      count = 0
      errors = []

      channels_for(source).each do |label, adapter|
        adapter.each_document(monday: @week.monday, sunday: @week.sunday) { |attributes| count += 1 if store(source, attributes) }
      rescue StandardError => e
        errors << "#{label} : #{e.message}"
        Rails.logger.warn "[Sentinelle] #{source.name} (#{label}) : #{e.class} #{e.message}"
      end

      web_documents.each { |attributes| count += 1 if store(source, attributes) }

      errors.each { |error| @warnings << "#{source.name} - #{error}" }
      source.record_collection!(count: count, error: errors.join(" | ").presence)
    end

    def channels_for(source)
      channels = []
      channels << ["API", ADAPTERS.fetch(source.adapter).constantize.new(source)] if source.adapter.present?
      channels << ["flux RSS", Sentinel::Adapters::Rss.new(source)] if source.feed_url.present?
      channels
    end

    def web_search(sources)
      searchable = sources.select { |source| source.web_search? && source.host.present? }
      return {} if searchable.empty? || @domain.search_queries.blank?

      found, errors = Sentinel::TavilySearch.new(queries: @domain.search_queries, sources: searchable)
                                            .call(monday: @week.monday, sunday: @week.sunday)
      @warnings.concat(errors)
      found
    rescue Sentinel::TavilySearch::NotConfigured, Sentinel::TavilySearch::TooOld => e
      @warnings << "Recherche web ignorée : #{e.message}"
      {}
    end

    # Renvoie true si le document est nouveau. Un document déjà connu n'est pas
    # retouché : son résumé IA éventuel est conservé.
    def store(source, attributes)
      document = source.sentinel_documents.find_or_initialize_by(external_id: attributes.fetch(:external_id))
      return false if document.persisted?

      document.assign_attributes(attributes.merge(domain: @domain.key, monday: @week.monday))
      classification = @domain.classify(document)
      document.relevant = classification.relevant
      document.relevance_reason = classification.reason
      document.raw_content = classification.relevant ? full_text_for(document) : nil
      document.save!
      true
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
      Rails.logger.warn "[Sentinelle] document ignoré (#{source.name}) : #{e.message}"
      false
    end

    def full_text_for(document)
      content = document.raw_content.to_s
      return content if document.kind != "article" || content.length >= FULL_TEXT_THRESHOLD || document.url.blank?

      fetched = Sentinel::ArticleText.fetch(document.url)
      fetched.to_s.length > content.length ? fetched : content
    end
  end
end
