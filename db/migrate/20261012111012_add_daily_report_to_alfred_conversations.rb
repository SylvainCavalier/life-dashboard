class AddDailyReportToAlfredConversations < ActiveRecord::Migration[8.0]
  def change
    add_reference :alfred_conversations, :daily_report, foreign_key: { on_delete: :nullify }, index: true
  end
end
