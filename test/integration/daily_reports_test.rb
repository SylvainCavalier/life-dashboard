require "test_helper"

class DailyReportsTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  ACCEPT_JSON = { "Accept" => "application/json" }.freeze

  setup { sign_in_owner }

  test "liste les rapports, l'ouverture marque comme lu" do
    report = create(:daily_report, :done)

    get api_daily_reports_path, headers: ACCEPT_JSON
    entry = JSON.parse(response.body).first
    assert_equal false, entry["read"]
    assert_equal 2, entry["items_count"]
    assert_equal 1, entry["urgent_count"]
    assert_nil entry["content"]

    get api_daily_report_path(report), headers: ACCEPT_JSON
    body = JSON.parse(response.body)
    assert_equal "Une journee chargee.", body["content"]["headline"]
    assert_equal "/", body["links"]["Task#1"]["path"]
    assert body["read"]
    assert_not_nil report.reload.read_at
  end

  test "rapport du jour a la demande, puis regeneration" do
    assert_enqueued_jobs(1, only: DailyReportJob) { post api_daily_reports_path, headers: ACCEPT_JSON }
    assert_response :created
    report = DailyReport.find(JSON.parse(response.body)["id"])
    assert_equal Date.current, report.report_date

    post regenerate_api_daily_report_path(report), headers: ACCEPT_JSON
    assert_response :conflict

    report.update!(status: "done")
    assert_enqueued_jobs(1, only: DailyReportJob) { post regenerate_api_daily_report_path(report), headers: ACCEPT_JSON }
    assert JSON.parse(response.body)["in_progress"]
  end

  test "en parler a Alfred ouvre une conversation dont le prompt contient le rapport" do
    report = create(:daily_report, :done)

    post discuss_api_daily_report_path(report), headers: ACCEPT_JSON
    assert_response :created
    conversation = AlfredConversation.find(JSON.parse(response.body)["conversation_id"])

    assert_equal report, conversation.daily_report
    assert_equal "event", conversation.messages.first.role
    report_block = Alfred::Prompt.system_blocks(conversation).last[:text]
    assert_match "## Rapport du matin dont Sylvain veut parler", report_block
    assert_match "Repondre a l'agence", report_block
    assert_equal 2, Alfred::Prompt.system_blocks.size
  end

  test "pas de conversation sur un rapport pas encore pret" do
    post discuss_api_daily_report_path(create(:daily_report)), headers: ACCEPT_JSON
    assert_response :unprocessable_content
  end
end
