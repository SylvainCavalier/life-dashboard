# Good Job configuration
Rails.application.configure do
  # En test, l'adaptateur de test de Rails : les jobs sont enregistres sans etre
  # executes (assert_enqueued_with...). Avec GoodJob en mode inline, un
  # perform_later dans un test executerait le job pour de vrai, par exemple un
  # appel a l'API OpenAI du module Voyages.
  config.active_job.queue_adapter = Rails.env.test? ? :test : :good_job

  # Configure Good Job to use PostgreSQL for job storage
  # Jobs will be stored in the same database as your application
  config.good_job.enable_cron = true
  config.good_job.cron = {
    langochat_sync: {
      cron: "0 22 * * *",
      class: "LangochatSyncJob",
      description: "Synchronise les sessions Langochat quotidiennement a 22h"
    },
    purge_expired_file_transfers: {
      cron: "15 * * * *",
      class: "PurgeExpiredFileTransfersJob",
      description: "Supprime les fichiers partages expires (bucket OVH + base) toutes les heures"
    }
  }

  # Un seul dyno Heroku Basic : pas de process worker separe, les jobs et les
  # crons tournent dans le process web. Passer GOOD_JOB_EXECUTION_MODE=external
  # et decommenter la ligne `worker:` du Procfile le jour ou un worker dedie
  # est ajoute.
  config.good_job.execution_mode = ENV.fetch("GOOD_JOB_EXECUTION_MODE", "async").to_sym if Rails.env.production?

  # Preserve job records for debugging
  config.good_job.preserve_job_records = true
  
  # Clean up old jobs after 7 days
  config.good_job.cleanup_preserved_jobs_before_seconds_ago = 7.days.to_i
  
  # Set maximum number of threads
  config.good_job.max_threads = ENV.fetch("GOOD_JOB_MAX_THREADS", 5).to_i
  
  # LISTEN/NOTIFY : les jobs sont pris en charge immediatement plutot qu'au
  # prochain sondage. Utile en mode async ou le process web fait aussi worker.
  config.good_job.enable_listen_notify = !Rails.env.test?
end
