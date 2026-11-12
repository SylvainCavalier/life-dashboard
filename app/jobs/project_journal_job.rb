# Cron horaire : consigne au journal de bord de leur projet les rendez-vous passes
# (Projects::Journal.record_past_events!). La table fait foi (`events.journaled_at`) :
# un dyno qui redemarre rattrape au passage suivant.
class ProjectJournalJob < ApplicationJob
  queue_as :default

  def perform(now = Time.current)
    count = Projects::Journal.record_past_events!(now: now)
    Rails.logger.info "[ProjectJournalJob] #{count} rendez-vous consigne(s) au journal" if count.positive?
  end
end
