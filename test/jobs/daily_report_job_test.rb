require "test_helper"
require "minitest/mock"

class DailyReportJobTest < ActiveJob::TestCase
  class FakeWriter
    def initialize(error: nil)
      @error = error
    end

    def call
      raise StructuredSummarizer::Error, @error if @error

      { content: { "headline" => "Rien de grave.", "opening" => "Bonjour.", "closing" => "Bonne journee.",
                   **DailyReport::SECTIONS.index_with { [] } },
        model: "claude-test", usage: { input: 1000, output: 200 } }
    end
  end

  setup do
    @sent = []
    PushNotifications.transport = ->(_subscription, message) { @sent << JSON.parse(message) }
  end

  teardown { PushNotifications.transport = nil }

  def run_job(report, writer: FakeWriter.new)
    PushNotifications.stub(:configured?, true) do
      Gmail.stub(:enabled?, false) do
        DailyReports::Writer.stub(:new, ->(*) { writer }) { DailyReportJob.perform_now(report.id) }
      end
    end
    report.reload
  end

  test "collecte, redige et notifie une seule fois" do
    create(:push_subscription)
    report = DailyReport.create!(report_date: Date.current, status: "pending", requested_at: Time.current)

    run_job(report)

    assert report.done?, report.error
    assert_equal "Rien de grave.", report.content["headline"]
    assert_equal 1000, report.input_tokens
    assert_includes report.snapshot["warnings"].first, "Gmail"
    assert_equal 1, @sent.size
    assert_equal "/reports/#{report.id}", @sent.first["url"]
    assert_not_nil report.notified_at

    # Regeneration : nouveau contenu, pas de seconde notification.
    report.update!(status: "pending", requested_at: Time.current)
    run_job(report)
    assert_equal 1, @sent.size
  end

  test "un echec de redaction garde l'instantane pour la relance" do
    report = DailyReport.create!(report_date: Date.current, status: "pending", requested_at: Time.current)

    run_job(report, writer: FakeWriter.new(error: "Synthese tronquee"))

    assert report.failed?
    assert_equal "Synthese tronquee", report.error
    assert report.snapshot.present?
    assert_empty @sent
  end

  test "le cron demande le rapport du jour, sans le relancer s'il existe" do
    assert_enqueued_jobs(1, only: DailyReportJob) { DailyReportJob.perform_now }
    assert_no_enqueued_jobs(only: DailyReportJob) { DailyReportJob.perform_now }
  end
end
