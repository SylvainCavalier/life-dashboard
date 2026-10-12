# Rapport du matin d'Alfred (DailyReport). Le cron s'en charge chaque jour a 9 h ;
# ces taches servent au debogage et a l'Alfred local.
namespace :daily_reports do
  # Lambda et non `def` : une methode definie ici le serait sur Object, pour toute l'application.
  report_date = -> { ENV["DATE"].present? ? Date.iso8601(ENV["DATE"]) : Date.current }

  desc "Enfile le rapport d'un jour (GoodJob) : rake daily_reports:run [DATE=2026-10-12]"
  task run: :environment do
    report = DailyReport.run!(report_date.call, force: ENV["FORCE"] == "1")
    puts "Rapport ##{report.id} du #{report.human_date} : #{report.status}"
  end

  desc "Redige le rapport immediatement : rake daily_reports:run_now [DATE=...] [FORCE=1 refait la collecte] [WEEKEND=1|0]"
  task run_now: :environment do
    date = report_date.call
    report = DailyReport.find_or_create_by!(report_date: date) { |r| r.weekend = DailyReport.weekend?(date) }
    force = ENV["FORCE"] == "1"
    abort "Rapport du #{report.human_date} deja redige (FORCE=1 pour le refaire)." if report.done? && !force

    weekend = ENV["WEEKEND"].present? ? ENV["WEEKEND"] == "1" : report.weekend
    fresh = force || weekend != report.weekend
    report.update!(status: "pending", step: nil, error: nil, requested_at: Time.current, finished_at: nil, weekend: weekend,
                   snapshot: (fresh ? nil : report.snapshot), content: nil)
    DailyReportJob.perform_now(report.id)
    report.reload
    abort "Echec : #{report.error}" if report.failed?

    puts report.text
    puts
    puts "#{report.model}, #{report.input_tokens} tokens en entree, #{report.output_tokens} en sortie" \
         "#{report.notified_at ? ', notification envoyee' : ''}"
  end

  desc "Affiche un rapport en texte : rake daily_reports:show [DATE=...]"
  task show: :environment do
    report = DailyReport.find_by(report_date: report_date.call) or abort "Aucun rapport pour cette date."
    puts report.done? ? report.text : "Rapport #{report.status}#{" : #{report.error}" if report.error}"
  end
end
