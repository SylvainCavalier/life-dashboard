# Alfred dans le dashboard : corpus RAG et debogage de l'agent.
namespace :alfred do
  desc "Cles API presentes ? pgvector installe ? etat du corpus"
  task check: :environment do
    puts "ANTHROPIC_API_KEY : #{Alfred.llm_configured? ? 'ok' : 'MANQUANTE'} (modele #{Alfred.model})"
    puts "MISTRAL_API_KEY   : #{Alfred.corpus_configured? ? 'ok' : 'MANQUANTE'} (embeddings + OCR)"
    vector = ActiveRecord::Base.connection.select_value("SELECT extversion FROM pg_extension WHERE extname = 'vector'")
    puts "pgvector          : #{vector || 'ABSENT (rails db:migrate)'}"
    puts "Corpus            : #{AlfredChunk.count} passages, #{AlfredIndexEntry.where(status: 'indexed').count} enregistrements indexes"
    AlfredChunk.group(:source_type).count.sort_by { |_, n| -n }.each { |type, n| puts "  #{type.ljust(18)} #{n}" }
    missing = Alfred::Corpus.indexed_models.filter_map do |name|
      pending = name.constantize.where.not(id: AlfredIndexEntry.where(source_type: name).select(:source_id))
      filter = Alfred::Corpus.config_for(name)[:only_if]
      # Les enregistrements ecartes volontairement (only_if) n'ont pas d'entree : normal.
      count = filter ? pending.find_each.count { |record| filter.call(record) } : pending.count
      "#{name}=#{count}" if count.positive?
    end
    puts "Jamais indexes    : #{missing.any? ? "#{missing.join(', ')} (rails alfred:index)" : 'aucun'}"
    extractors = AlfredIndexEntry.where.not(file_extractor: nil).group(:file_extractor).count
    puts "Fichiers          : #{extractors.map { |k, n| "#{k}=#{n}" }.join(', ')}" if extractors.any?
    AlfredIndexEntry.failed.limit(20).each { |e| puts "  ECHEC #{e.source_type}##{e.source_id} : #{e.error}" }
  end

  desc "Indexe le corpus (MODEL=Document pour un seul modele, FORCE=1 pour tout recalculer, OCR compris)"
  task index: :environment do
    abort "MISTRAL_API_KEY manquante" unless Alfred.corpus_configured?

    models = ENV["MODEL"].present? ? ENV["MODEL"].split(",") & Alfred::Corpus.indexed_models : Alfred::Corpus.indexed_models
    abort "Modele inconnu. Disponibles : #{Alfred::Corpus.indexed_models.join(', ')}" if models.empty?

    report = Alfred::Corpus::Reindexer.new(models: models, force: ENV["FORCE"] == "1", logger: ->(line) { puts line }).call
    puts "Termine : #{report.indexed} indexes, #{report.skipped} inchanges, #{report.removed} retires, #{report.failed} en echec"
  end

  desc "Teste la recherche du corpus : rake alfred:search Q=\"bail appartement\""
  task search: :environment do
    hits = Alfred::Corpus::Search.call(query: ENV.fetch("Q"), top_k: (ENV["K"] || 8).to_i)
    puts "Aucun passage au-dessus du plancher (#{Alfred::Corpus::Search::MIN_COSINE_SIMILARITY})" if hits.empty?
    hits.each do |hit|
      puts format("%.3f (cos %.3f)  %s#%d [%s] %s", hit.score, hit.cosine, hit.chunk.source_type, hit.chunk.source_id, hit.chunk.kind, hit.chunk.label)
      puts "    #{hit.chunk.content.squish.truncate(160)}"
    end
  end

  desc "Pose une question a Alfred sans passer par l'interface : rake alfred:ask Q=\"...\""
  task ask: :environment do
    abort "Cles manquantes : #{Alfred.missing_keys.join(', ')}" unless Alfred.configured?

    conversation = AlfredConversation.create!(title: "[rake] #{ENV.fetch('Q').truncate(50)}")
    conversation.messages.create!(role: "user", status: "done", content: ENV.fetch("Q"))
    reply = conversation.messages.create!(role: "assistant", status: "processing", content: "")
    Alfred::Agent.new(reply).call
    reply.reload
    reply.steps.each { |step| puts "  > #{step['label']}" }
    puts reply.content
    puts "\n[#{reply.model}, #{reply.input_tokens} tokens en entree dont #{reply.cached_tokens} en cache, #{reply.output_tokens} en sortie, #{reply.latency_ms} ms]"
    conversation.actions.each { |a| puts "PROPOSITION ##{a.id} : #{a.operation} #{a.target_model} #{a.new_attributes.to_json}" }
  end
end
