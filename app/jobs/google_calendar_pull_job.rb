# Google -> application (puis pousse ce qui n'a jamais ete envoye). Lance par
# le cron GoodJob, le bouton de la page Agenda et `rake google_calendar:sync`.
# Ne leve pas : l'echec est consigne dans `calendar_syncs` pour l'interface.
class GoogleCalendarPullJob < ApplicationJob
  queue_as :default

  def perform
    return unless GoogleCalendar.enabled?

    state = CalendarSync.claim!
    return if state.nil?

    report = GoogleCalendar::Sync.new.pull!
    state.finish!(report)
    Rails.logger.info("[GoogleCalendarPullJob] #{report.pulled} recu(s), #{report.pushed} pousse(s), " \
                      "#{report.deleted} supprime(s)")
  rescue StandardError => e
    state&.fail!(e.message)
    Rails.logger.error("[GoogleCalendarPullJob] #{e.class}: #{e.message}")
  end
end
