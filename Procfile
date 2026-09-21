web: bundle exec puma -C config/puma.rb
release: bundle exec rails db:migrate

# Un seul dyno Basic : GoodJob tourne en mode async dans le process web
# (config/initializers/good_job.rb). Pour passer a un worker dedie, decommenter
# la ligne ci-dessous et poser GOOD_JOB_EXECUTION_MODE=external.
# worker: bundle exec good_job start
