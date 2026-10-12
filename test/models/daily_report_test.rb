# == Schema Information
#
# Table name: daily_reports
#
#  id            :bigint           not null, primary key
#  content       :text
#  error         :text
#  finished_at   :datetime
#  input_tokens  :integer
#  model         :string
#  notified_at   :datetime
#  output_tokens :integer
#  read_at       :datetime
#  report_date   :date             not null
#  requested_at  :datetime
#  snapshot      :text
#  status        :string           default("pending"), not null
#  step          :string
#  weekend       :boolean          default(FALSE), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
# Indexes
#
#  index_daily_reports_on_report_date  (report_date) UNIQUE
#
require "test_helper"

class DailyReportTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "run! cree le rapport du jour une seule fois et marque le week-end" do
    assert_enqueued_jobs 1, only: DailyReportJob do
      DailyReport.run!(Date.new(2026, 10, 10))
      DailyReport.run!(Date.new(2026, 10, 10))
    end

    report = DailyReport.find_by!(report_date: Date.new(2026, 10, 10))
    assert report.weekend
    assert report.pending?
    assert_not DailyReport.run!(Date.new(2026, 10, 12)).weekend
  end

  test "un rapport termine n'est relance que force, et repart alors d'une collecte fraiche" do
    report = create(:daily_report, :done)

    assert_no_enqueued_jobs { DailyReport.run!(report.report_date) }
    assert_enqueued_jobs(1, only: DailyReportJob) { DailyReport.run!(report.report_date, force: true) }
    report.reload
    assert report.pending?
    assert_nil report.snapshot
    assert_nil report.content
  end

  test "un rapport en echec est retente au passage suivant du cron" do
    report = create(:daily_report, status: "failed", error: "API indisponible")

    assert_enqueued_jobs(1, only: DailyReportJob) { DailyReport.run!(report.report_date) }
    assert report.reload.pending?
  end

  test "instantane et contenu sont chiffres en base" do
    report = create(:daily_report, :done)
    raw = DailyReport.connection.select_value("SELECT content FROM daily_reports WHERE id = #{report.id}")

    assert_not_includes raw, "agence"
    assert_equal "Une journee chargee.", report.reload.content["headline"]
  end

  test "liens et texte du rapport" do
    report = create(:daily_report, :done)

    assert_equal %w[Mail#abc Task#1], report.links.keys.sort
    assert_equal 2, report.items_count
    assert_match "## Courrier", report.text
    assert_match "- Repondre a l'agence : Le bail attend. [Mail#abc (Bail (Agence))]", report.text
    assert_equal "/reports/#{report.id}", report.push_payload[:url]
    assert_equal "Une journee chargee.", report.push_payload[:body]
  end
end
