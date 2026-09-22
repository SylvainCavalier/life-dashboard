module Api
  # Etat et declenchement de la synchronisation Google Calendar (page Agenda).
  class CalendarSyncsController < ApplicationController
    # GET /api/calendar_sync
    def show
      render json: CalendarSync.current
    end

    # POST /api/calendar_sync : enfile une synchronisation (sans effet si une
    # est deja en cours).
    def create
      unless GoogleCalendar.enabled?
        message = "Google Calendar n'est pas configure (GOOGLE_CALENDAR_ID, GOOGLE_CALENDAR_CREDENTIALS)"
        return render json: { errors: [message] }, status: :unprocessable_content
      end

      render json: CalendarSync.run!, status: :accepted
    end
  end
end
