module Api
  # Page Rapports : rapports du matin d'Alfred (voir DailyReport). La table fait foi
  # pour l'etat du traitement : l'interface sonde `show` tant que `in_progress` est vrai.
  class DailyReportsController < ApplicationController
    before_action :set_report, only: [:show, :regenerate, :discuss]

    def index
      render json: DailyReport.recent.limit(120).map { |report| report_json(report) }
    end

    # Ouvrir un rapport termine le marque comme lu.
    def show
      @report.update_columns(read_at: Time.current) if @report.unread?
      render json: report_json(@report, full: true)
    end

    # Rapport du jour, a la demande (sans effet s'il existe deja).
    def create
      report = DailyReport.run!(Date.current)
      render json: report_json(report, full: true), status: :created
    end

    # Nouveau rapport du meme jour, a partir d'une collecte fraiche.
    def regenerate
      return render(json: { errors: ["Rapport deja en cours"] }, status: :conflict) if @report.in_progress? && !@report.stuck?

      @report.process!(force: true)
      render json: report_json(@report.reload, full: true)
    end

    # « En parler a Alfred » : conversation rattachee au rapport, qui suit dans son prompt.
    def discuss
      return render(json: { errors: ["Rapport pas encore pret"] }, status: :unprocessable_content) unless @report.done?

      conversation = AlfredConversation.create!(daily_report: @report, title: "Rapport du #{@report.human_date}", last_message_at: Time.current)
      conversation.messages.create!(role: "event", status: "done", content: "Rapport du #{@report.human_date} joint à la conversation.")
      render json: { conversation_id: conversation.id }, status: :created
    end

    private

    def set_report
      @report = DailyReport.find(params[:id])
    end

    def report_json(report, full: false)
      content = report.content || {}
      json = {
        id: report.id, report_date: report.report_date, human_date: report.human_date, weekend: report.weekend,
        status: report.status, step: report.step, in_progress: report.in_progress?, stuck: report.stuck?,
        error: report.error, read: report.read_at.present?, headline: content["headline"],
        items_count: report.items_count,
        urgent_count: DailyReport::SECTIONS.sum { |key| Array(content[key]).count { |item| item["urgent"] } },
        finished_at: report.finished_at
      }
      return json unless full

      json.merge(
        content: content.presence, links: report.links,
        warnings: report.snapshot&.dig("warnings") || [],
        model: report.model, input_tokens: report.input_tokens, output_tokens: report.output_tokens
      )
    end
  end
end
