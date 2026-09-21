module Api
  # Module Sentinelle : semaines de veille d'un domaine. Une semaine est
  # identifiée par son lundi (AAAA-MM-JJ) dans l'URL.
  class SentinelWeeksController < ApplicationController
    RECENT_WEEKS = 8

    before_action :set_domain
    before_action :set_monday, only: [:show, :run, :destroy]

    rescue_from Sentinel::Domains::UnknownDomain do |error|
      render json: { errors: [error.message] }, status: :not_found
    end

    # GET /api/sentinel_domains/:key/weeks
    # Les dernières semaines sont toujours listées, même vides, pour pouvoir
    # lancer une veille sur une semaine jamais traitée.
    def index
      weeks = SentinelWeek.for_domain(@domain.key).index_by(&:monday)
      counts = document_counts

      # La semaine en cours est listée aussi : une veille partielle est possible,
      # et la relancer plus tard ne collecte que les nouveautés.
      current = Date.current.beginning_of_week
      mondays = (0..RECENT_WEEKS).map { |i| current - (7 * i) } | weeks.keys

      render json: mondays.sort.reverse.map { |monday| week_json(weeks[monday], monday, counts[monday]) }
    end

    # GET /api/sentinel_domains/:key/weeks/:monday
    def show
      week = SentinelWeek.for_domain(@domain.key).find_by(monday: @monday)
      documents = SentinelDocument.where(domain: @domain.key, monday: @monday).includes(:sentinel_source)
                                  .sort_by(&:sort_key)

      render json: week_json(week, @monday, counts_for(documents)).merge(
        digest: week&.digest? ? week.digest : nil,
        documents: documents.map(&:api_attributes)
      )
    end

    # POST /api/sentinel_domains/:key/weeks/:monday/run
    # Enfile le traitement. Répond 202, y compris quand un traitement est déjà en cours.
    def run
      if @monday > Date.current
        return render json: { errors: ["Cette semaine n'a pas encore commencé"] }, status: :unprocessable_content
      end

      week = SentinelWeek.run!(@domain.key, @monday)
      render json: week_json(week, @monday, nil), status: :accepted
    end

    # DELETE /api/sentinel_domains/:key/weeks/:monday
    # Supprime la semaine et ses documents : la prochaine veille repart de zéro.
    def destroy
      SentinelDocument.where(domain: @domain.key, monday: @monday).delete_all
      SentinelWeek.for_domain(@domain.key).where(monday: @monday).destroy_all
      head :no_content
    end

    private

    def set_domain
      @domain = Sentinel::Domains.find!(params[:sentinel_domain_key])
    end

    def set_monday
      @monday = SentinelWeek.parse_monday(params[:monday])
    rescue ArgumentError, Date::Error => e
      render json: { errors: ["Semaine invalide : #{e.message}"] }, status: :unprocessable_content
    end

    def document_counts
      scope = SentinelDocument.where(domain: @domain.key)
      totals = scope.group(:monday).count
      relevant = scope.relevant.group(:monday).count
      summarized = scope.relevant.summarized.group(:monday).count

      totals.to_h do |monday, total|
        [monday, { total: total, relevant: relevant[monday].to_i, summarized: summarized[monday].to_i }]
      end
    end

    def counts_for(documents)
      kept = documents.select(&:relevant)
      { total: documents.size, relevant: kept.size, summarized: kept.count(&:summarized?) }
    end

    def week_json(week, monday, counts)
      {
        domain: @domain.key,
        monday: monday,
        sunday: monday + 6,
        complete: monday + 6 < Date.current,
        status: week&.status,
        step: week&.step,
        progress_done: week&.progress_done.to_i,
        progress_total: week&.progress_total.to_i,
        error: week&.error,
        warnings: week&.warnings || [],
        stuck: week&.stuck? || false,
        has_digest: week&.digest? || false,
        digest_headline: week&.digest? ? week.digest["tldr"].to_s.truncate(220) : nil,
        digest_model: week&.digest_model,
        digest_generated_at: week&.digest_generated_at,
        requested_at: week&.requested_at,
        finished_at: week&.finished_at,
        counts: counts || { total: 0, relevant: 0, summarized: 0 }
      }
    end
  end
end
