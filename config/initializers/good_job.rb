# Good Job configuration
Rails.application.configure do
  config.active_job.queue_adapter = :good_job

  # Configure Good Job to use PostgreSQL for job storage
  # Jobs will be stored in the same database as your application
  config.good_job.enable_cron = true
  config.good_job.cron = {
    langochat_sync: {
      cron: "0 22 * * *",
      class: "LangochatSyncJob",
      description: "Synchronise les sessions Langochat quotidiennement a 22h"
    }
  }

  # Preserve job records for debugging
  config.good_job.preserve_job_records = true
  
  # Clean up old jobs after 7 days
  config.good_job.cleanup_preserved_jobs_before_seconds_ago = 7.days.to_i
  
  # Set maximum number of threads
  config.good_job.max_threads = ENV.fetch("GOOD_JOB_MAX_THREADS", 5).to_i
  
  # Enable dashboard in development
  config.good_job.enable_listen_notify = Rails.env.development?
end
