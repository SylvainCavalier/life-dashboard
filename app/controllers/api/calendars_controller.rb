module Api
  class CalendarsController < ApplicationController
    # Un client calendrier abonne (Apple Calendar, Google Agenda...) ne sait pas
    # ouvrir de session Devise : le flux s'authentifie donc par un token secret
    # passe dans l'URL. Une session valide fonctionne aussi, pour tester depuis
    # le navigateur.
    skip_before_action :authenticate_user!, only: :feed
    before_action :authenticate_feed!, only: :feed

    def feed
      calendar = Icalendar::Calendar.new
      calendar.prodid = "-//Life Dashboard//Agenda//FR"
      calendar.x_wr_calname = "Life Dashboard"

      Event.all.find_each do |event|
        calendar.event do |e|
          e.uid = "event-#{event.id}@life-dashboard"
          e.summary = event.title
          e.description = event.description if event.description.present?
          e.location = event.location if event.location.present?
          e.dtstart = event.all_day ? Icalendar::Values::Date.new(event.start_time.to_date) : event.start_time.utc
          if event.end_time.present?
            # DTEND est exclusif en ICS ; `end_time` d'une journee entiere est le dernier jour (inclusif).
            e.dtend = event.all_day ? Icalendar::Values::Date.new(event.end_time.to_date + 1) : event.end_time.utc
          end
          if event.reminder_minutes.present? && event.reminder_minutes > 0
            alarm = Icalendar::Alarm.new
            alarm.action = "DISPLAY"
            alarm.description = event.title
            alarm.trigger = "-PT#{event.reminder_minutes}M"
            e.alarms << alarm
          end
          e.created = event.created_at.utc
          e.last_modified = event.updated_at.utc
        end
      end

      calendar.publish
      render plain: calendar.to_ical, content_type: "text/calendar"
    end

    private

    def authenticate_feed!
      return if user_signed_in?
      return if valid_feed_token?

      head :unauthorized
    end

    def valid_feed_token?
      expected = ENV["CALENDAR_FEED_TOKEN"].presence
      given = params[:token].presence
      return false if expected.nil? || given.nil?

      ActiveSupport::SecurityUtils.secure_compare(given, expected)
    end
  end
end
