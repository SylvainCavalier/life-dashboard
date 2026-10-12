# Rapport du matin d'Alfred (voir DailyReport). Deux usages :
#   - sans argument, c'est le cron (9 h, puis toutes les 15 min jusqu'a 11 h) : il
#     demande le rapport du jour, qui n'est lance qu'une fois (DailyReport.run!) ;
#     un rapport en echec est retente au passage suivant ;
#   - avec un identifiant, il traite le rapport : collecte (sautee si l'instantane
#     existe deja), redaction, puis notification push au premier rapport termine.
class DailyReportJob < ApplicationJob
  queue_as :default

  discard_on ActiveRecord::RecordNotFound

  def perform(report_id = nil)
    return DailyReport.run!(Date.current) if report_id.nil?

    report = DailyReport.find(report_id)
    # Idempotence : une re-execution GoodJob d'un job deja traite ne relance rien.
    return unless report.pending?

    report.update!(status: "running")
    collect(report) if report.snapshot.blank?
    write(report)
    notify(report)
  rescue ActiveRecord::RecordNotFound
    raise
  rescue StandardError => e
    Rails.logger.error "[DailyReportJob] rapport ##{report_id} en echec : #{e.class}: #{e.message}"
    report&.update!(status: "failed", error: e.message.truncate(1000), finished_at: Time.current)
  end

  private

  def collect(report)
    report.advance!("collect")
    report.update!(snapshot: DailyReports::Collector.new(report.report_date, weekend: report.weekend).call)
  end

  def write(report)
    report.advance!("write")
    result = DailyReports::Writer.new(report.snapshot).call
    report.update!(
      content: result[:content], model: result[:model],
      input_tokens: result.dig(:usage, :input), output_tokens: result.dig(:usage, :output),
      status: "done", step: nil, error: nil, finished_at: Time.current
    )
  end

  # Une seule notification par rapport : une regeneration depuis la page ne sonne pas.
  def notify(report)
    return if report.notified_at

    reached = PushNotifications.broadcast(report.push_payload)
    report.update_columns(notified_at: Time.current) if reached.positive?
  end
end
