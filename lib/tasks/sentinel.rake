# Points d'entree scriptables du module Sentinelle (utilises par Alfred).
# DOMAIN : cle d'un domaine (droit_travail, desinformation) ou "all".
# MONDAY : lundi de la semaine (AAAA-MM-JJ), par defaut la derniere semaine ecoulee.
namespace :sentinel do
  domains_for = lambda do |value|
    value.blank? || value == "all" ? Sentinel::Domains.keys : [Sentinel::Domains.find!(value).key]
  end

  monday_for = lambda do |value|
    value.present? ? SentinelWeek.parse_monday(value) : SentinelWeek.last_completed_monday
  end

  desc "Cles API et sources de chaque domaine : rake sentinel:check"
  task check: :environment do
    puts "OPENAI_API_KEY   #{Sentinel::Llm.configured? ? 'ok' : 'ABSENTE (resumes impossibles)'}"
    puts "PISTE_CLIENT_ID  #{Sentinel::Piste::Client.configured? ? 'ok' : 'ABSENT (Judilibre et Legifrance ignores)'}"
    puts "TAVILY_API_KEY   #{Sentinel::TavilySearch.configured? ? 'ok' : 'ABSENTE (recherche web ignoree)'}"
    puts "Modeles          resumes=#{Sentinel::Llm.summary_model} synthese=#{Sentinel::Llm.digest_model}"
    Sentinel::Domains.all.each do |domain|
      sources = SentinelSource.for_domain(domain.key)
      puts "#{domain.key} : #{sources.active.count} source(s) active(s) sur #{sources.count}"
      sources.where.not(last_error: nil).find_each { |source| puts "  ! #{source.name} : #{source.last_error}" }
    end
  end

  desc "Installe les sources par defaut manquantes : rake sentinel:seed_sources DOMAIN=all"
  task seed_sources: :environment do
    domains_for.call(ENV["DOMAIN"]).each do |key|
      puts "#{key} : #{SentinelSource.seed_defaults!(key)} source(s) ajoutee(s)"
    end
  end

  desc "Enfile la veille d'une semaine (GoodJob) : rake sentinel:run DOMAIN=droit_travail MONDAY=2026-09-14"
  task run: :environment do
    monday = monday_for.call(ENV["MONDAY"])
    domains_for.call(ENV["DOMAIN"]).each do |key|
      week = SentinelWeek.run!(key, monday)
      puts "#{key}, semaine du #{monday} : #{week.status}"
    end
  end

  desc "Traite la veille d'une semaine immediatement, sans GoodJob : rake sentinel:run_now DOMAIN=all"
  task run_now: :environment do
    monday = monday_for.call(ENV["MONDAY"])
    failed = false

    domains_for.call(ENV["DOMAIN"]).each do |key|
      SentinelSource.bootstrap!(key)
      week = SentinelWeek.find_or_create_by!(domain: key, monday: monday)
      if week.in_progress? && !week.stuck?
        warn "#{key} : un traitement est deja en cours pour la semaine du #{monday}"
        failed = true
        next
      end

      week.mark_requested!
      SentinelWeekJob.perform_now(week.id)
      week.reload

      if week.done?
        documents = week.documents
        puts "#{key}, semaine du #{monday} : #{documents.relevant.count} document(s) retenu(s) sur #{documents.count}"
        puts "  #{week.digest['tldr']}" if week.digest?
        week.warnings.each { |warning| puts "  ! #{warning}" }
      else
        warn "#{key} : echec - #{week.error}"
        failed = true
      end
    end

    abort if failed
  end
end
