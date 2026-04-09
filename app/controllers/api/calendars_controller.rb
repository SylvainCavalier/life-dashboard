module Api
  class CalendarsController < ApplicationController
    protect_from_forgery with: :null_session

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
            e.dtend = event.all_day ? Icalendar::Values::Date.new(event.end_time.to_date) : event.end_time.utc
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
  end
end
