# Prolonge chaque nuit les occurrences des echeances recurrentes dans l'agenda
# (fenetre glissante Deadline::HORIZON).
class DeadlineEventsJob < ApplicationJob
  queue_as :default

  def perform
    Deadline.find_each do |deadline|
      deadline.sync_events!
    rescue StandardError => e
      Rails.logger.error("[DeadlineEventsJob] echeance ##{deadline.id} : #{e.message}")
    end
  end
end
