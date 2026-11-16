module Api
  # Journal de bord alimente depuis les depots de code : la commande /historyupdate de
  # Claude Code (sur le Mac) y envoie le resume de la session qu'elle vient d'ajouter a
  # .knowledge/history.md (script ~/.claude/scripts/project-journal). Le depot designe son
  # projet par le slug cite dans son CLAUDE.md.
  #
  # Pas de session Devise : authentification par jeton (`Authorization: Bearer`,
  # PROJECT_JOURNAL_TOKEN), comme le flux ICS. Le jeton ne permet que deux choses : lister
  # les projets (slug et nom) et ecrire une entree de source « code ».
  class ProjectJournalController < ApplicationController
    skip_forgery_protection
    # Les filtres de session restent : ils n'agissent que si une session est ouverte
    # (un compte d'ami connecte est refuse comme partout).
    skip_before_action :authenticate_user!
    before_action :authenticate_token!

    # Entrees renvoyees au plus par GET ?project= (les plus recentes d'abord).
    MAX_ENTRIES = 500

    # GET /api/project_journal               -> projets (slug, nom, statut)
    # GET /api/project_journal?project=prudo -> journal de ce projet, toutes sources (since= pour borner)
    def index
      return render_entries if params[:project].present?

      render json: { projects: Project.ordered.map { |project| { slug: project.slug, name: project.name, status: project.status } } }
    end

    # POST /api/project_journal
    # { project: "prudo", title: "...", body: "- [feat] ...", occurred_on: "2026-11-12", ref: "..." }
    def create
      project = find_project or return

      occurred_on = parse_date(params[:occurred_on])
      return render(json: { error: "Date invalide : #{params[:occurred_on].inspect}" }, status: :unprocessable_entity) if occurred_on == :invalid

      entry, created = Projects::Journal.record_code_session(
        project: project, title: params[:title].to_s, body: params[:body].to_s.first(20_000),
        occurred_on: occurred_on || Date.current, ref: params[:ref].to_s.presence
      )
      render json: { id: entry.id, project: project.slug, project_name: project.name, created: created,
                     url: "/projects/#{project.id}" }, status: created ? :created : :ok
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: e.record.errors.full_messages.join(", ") }, status: :unprocessable_entity
    end

    # POST /api/project_journal/sync
    # { project: "prudo", dry_run: true, sessions: [{ title, body, occurred_on, ref }, ...] }
    # Rattrapage par /updatejournal : chaque session revient avec son statut (new, unchanged,
    # changed, invalid) ; sans dry_run, les nouvelles et les modifiees sont ecrites.
    def sync
      project = find_project or return

      sessions = Array(params[:sessions])
      if sessions.empty? || sessions.size > Projects::Journal::MAX_SYNC_SESSIONS
        return render json: { error: "Entre 1 et #{Projects::Journal::MAX_SYNC_SESSIONS} sessions attendues" },
                      status: :unprocessable_entity
      end

      parsed = sessions.map do |session|
        session = session.respond_to?(:permit) ? session.permit(:title, :body, :occurred_on, :ref) : {}
        occurred_on = parse_date(session[:occurred_on])
        if occurred_on == :invalid
          return render json: { error: "Date invalide : #{session[:occurred_on].inspect}" }, status: :unprocessable_entity
        end

        { title: session[:title].to_s, body: session[:body].to_s.first(20_000), occurred_on: occurred_on,
          ref: session[:ref].to_s.presence }
      end

      dry_run = ActiveModel::Type::Boolean.new.cast(params[:dry_run]) || false
      results = ActiveRecord::Base.transaction do
        Projects::Journal.sync_code_sessions(project: project, sessions: parsed, dry_run: dry_run)
      end
      render json: { project: project.slug, project_name: project.name, dry_run: dry_run, url: "/projects/#{project.id}",
                     counts: results.group_by { |r| r[:status] }.transform_values(&:size), sessions: results }
    end

    private

    def find_project
      project = Project.find_by(slug: params[:project].to_s.strip.downcase)
      return project if project

      render json: { error: "Projet inconnu : #{params[:project].inspect}", known: Project.ordered.pluck(:slug) },
             status: :not_found
      nil
    end

    def render_entries
      project = find_project or return

      since = parse_date(params[:since])
      return render(json: { error: "Date invalide : #{params[:since].inspect}" }, status: :unprocessable_entity) if since == :invalid

      scope = project.project_entries.includes(:contact).chronological
      scope = scope.where(occurred_on: since..) if since
      entries = scope.limit(MAX_ENTRIES).map do |entry|
        entry.api_attributes.slice(:id, :occurred_on, :kind, :title, :body, :source, :source_ref, :contact_name)
      end
      render json: { project: { slug: project.slug, name: project.name, status: project.status },
                     total: scope.count, entries: entries }
    end

    def authenticate_token!
      expected = ENV["PROJECT_JOURNAL_TOKEN"].presence
      return render(json: { error: "PROJECT_JOURNAL_TOKEN non configure sur le serveur" }, status: :service_unavailable) unless expected

      given = request.authorization.to_s[/\ABearer (.+)\z/, 1]
      return if given.present? && ActiveSupport::SecurityUtils.secure_compare(given, expected)

      Rails.logger.warn "[ProjectJournal] jeton refuse depuis #{request.remote_ip}"
      render json: { error: "Jeton refuse" }, status: :unauthorized
    end

    def parse_date(value)
      return if value.blank?

      Date.iso8601(value.to_s)
    rescue Date::Error
      :invalid
    end
  end
end
