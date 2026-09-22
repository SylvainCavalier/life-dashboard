# == Schema Information
#
# Table name: alfred_conversations
#
#  id              :bigint           not null, primary key
#  last_message_at :datetime
#  title           :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_alfred_conversations_on_last_message_at  (last_message_at)
#
class AlfredConversation < ApplicationRecord
  has_many :messages, -> { order(:id) }, class_name: "AlfredMessage", dependent: :destroy
  has_many :actions, class_name: "AlfredAction", dependent: :destroy

  scope :recent, -> { order(Arel.sql("COALESCE(last_message_at, created_at) DESC")) }

  def busy?
    messages.where(status: %w[pending processing]).exists?
  end
end
