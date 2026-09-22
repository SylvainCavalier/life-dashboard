# Application -> Google, un evenement a la fois, enfile par les callbacks
# d'`Event`. `action` : "upsert" (id = Event#id) ou "delete" (id = identifiant
# Google, l'enregistrement local n'existant plus).
class GoogleCalendarPushJob < ApplicationJob
  queue_as :default
  retry_on GoogleCalendar::Client::Error, wait: :polynomially_longer, attempts: 5

  def perform(action, id)
    return unless GoogleCalendar.enabled?

    sync = GoogleCalendar::Sync.new
    case action
    when "upsert"
      event = Event.find_by(id: id)
      sync.push!(event) if event
    when "delete"
      sync.delete!(id)
    else
      raise ArgumentError, "action inconnue : #{action}"
    end
  end
end
