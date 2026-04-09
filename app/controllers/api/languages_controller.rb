module Api
  class LanguagesController < ApplicationController
    protect_from_forgery with: :null_session

    def index
      @languages = Language.ordered.includes(:language_sessions)
      existing_names = @languages.map(&:name)
      available_names = Language::NAMES.keys - existing_names

      render json: {
        languages: @languages.map { |l| language_json(l) },
        available_names: available_names
      }
    end

    def create
      @language = Language.new(language_params)
      if @language.save
        render json: language_json(@language), status: :created
      else
        render json: { errors: @language.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def update
      @language = Language.find(params[:id])
      if @language.update(language_params)
        render json: language_json(@language)
      else
        render json: { errors: @language.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def destroy
      @language = Language.find(params[:id])
      @language.destroy
      head :no_content
    end

    # POST /api/languages/:id/log_session
    def log_session
      @language = Language.find(params[:id])
      session = @language.language_sessions.find_or_initialize_by(
        practiced_on: Date.current,
        source: "manual"
      )
      if session.persisted? || session.save
        render json: language_json(@language.reload)
      else
        render json: { errors: session.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # DELETE /api/languages/:id/unlog_session
    def unlog_session
      @language = Language.find(params[:id])
      session = @language.language_sessions.find_by(practiced_on: Date.current, source: "manual")
      session&.destroy
      render json: language_json(@language.reload)
    end

    # POST /api/languages/sync_langochat
    def sync_langochat
      result = Langochat::SyncService.new.sync!
      render json: result
    rescue KeyError => e
      render json: { errors: ["Configuration manquante: #{e.message}"] }, status: :service_unavailable
    end

    # GET /api/languages/:id/stats
    def stats
      @language = Language.find(params[:id])
      months = (params[:months] || 6).to_i
      start_date = months.months.ago.to_date.beginning_of_month

      sessions = @language.language_sessions
                         .where("practiced_on >= ?", start_date)
                         .order(:practiced_on)

      # Group by week for the graph
      weekly = sessions.group_by { |s| s.practiced_on.beginning_of_week }
                       .transform_values(&:count)

      # Group by month
      monthly = sessions.group_by { |s| s.practiced_on.strftime("%Y-%m") }
                        .transform_values(&:count)

      # All practice dates for the heatmap, with source info
      dates_with_source = sessions.pluck(:practiced_on, :source).map { |d, s| { date: d.to_s, source: s } }
      dates = dates_with_source.map { |d| d[:date] }.uniq

      # Count by source
      manual_count = sessions.where(source: "manual").count
      langochat_count = sessions.where(source: "langochat").count

      render json: {
        language_id: @language.id,
        weekly: weekly.map { |week, count| { week: week.to_s, count: count } },
        monthly: monthly.map { |month, count| { month: month, count: count } },
        dates: dates,
        dates_with_source: dates_with_source,
        total_sessions: @language.language_sessions.count,
        manual_sessions: manual_count,
        langochat_sessions: langochat_count,
        streak: @language.streak
      }
    end

    private

    def language_params
      params.require(:language).permit(:name, :level, :color, :flag_emoji, :notes)
    end

    def language_json(language)
      {
        id: language.id,
        name: language.name,
        level: language.level,
        color: language.color,
        flag_emoji: language.flag_emoji,
        notes: language.notes,
        practiced_today: language.practiced_today?,
        streak: language.streak,
        sessions_this_week: language.sessions_this_week,
        total_sessions: language.language_sessions.size,
        created_at: language.created_at,
        updated_at: language.updated_at
      }
    end
  end
end
