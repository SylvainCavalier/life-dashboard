# == Schema Information
#
# Table name: alfred_conversations
#
#  id              :bigint           not null, primary key
#  last_message_at :datetime
#  title           :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  daily_report_id :bigint
#
# Indexes
#
#  index_alfred_conversations_on_daily_report_id  (daily_report_id)
#  index_alfred_conversations_on_last_message_at  (last_message_at)
#
# Foreign Keys
#
#  fk_rails_...  (daily_report_id => daily_reports.id) ON DELETE => nullify
#
class AlfredConversation < ApplicationRecord
  # Conversation ouverte depuis un rapport du matin : le rapport est rejoue dans le prompt.
  belongs_to :daily_report, optional: true
  has_many :messages, -> { order(:id) }, class_name: "AlfredMessage", dependent: :destroy
  has_many :actions, class_name: "AlfredAction", dependent: :destroy

  scope :recent, -> { order(Arel.sql("COALESCE(last_message_at, created_at) DESC")) }

  def busy?
    messages.where(status: %w[pending processing]).exists?
  end
end
