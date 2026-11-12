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

    # GET /api/project_journal
    def index
      render json: { projects: Project.ordered.map { |project| { slug: project.slug, name: project.name, status: project.status } } }
    end

    # POST /api/project_journal
    # { project: "prudo", title: "...", body: "- [feat] ...", occurred_on: "2026-11-12", ref: "..." }
    def create
      project = Project.find_by(slug: params[:project].to_s.strip.downcase)
      unless project
        return render json: { error: "Projet inconnu : #{params[:project].inspect}",
                              known: Project.ordered.pluck(:slug) }, status: :not_found
      end

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

    private

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
