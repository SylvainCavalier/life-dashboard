# Reindexation complete du corpus d'Alfred (bouton de la page Alfred, ou `rails alfred:index`).
# Tourne aussi chaque nuit (cron GoodJob) pour rattraper ce que les callbacks ne voient
# pas : enregistrements anterieurs a leur installation, imports faits avec
# ALFRED_INDEXING=0, echecs passes. Les empreintes font que l'inchange ne coute rien.
class AlfredReindexJob < ApplicationJob
  queue_as :default

  def perform(force: false)
    return unless Alfred.corpus_configured?

    report = Alfred::Corpus::Reindexer.new(force: force).call
    Rails.logger.info "[AlfredReindexJob] #{report.to_h}"
  end
end
