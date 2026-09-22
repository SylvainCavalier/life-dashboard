class AlfredConversation < ApplicationRecord
  has_many :messages, -> { order(:id) }, class_name: "AlfredMessage", dependent: :destroy
  has_many :actions, class_name: "AlfredAction", dependent: :destroy

  scope :recent, -> { order(Arel.sql("COALESCE(last_message_at, created_at) DESC")) }

  def busy?
    messages.where(status: %w[pending processing]).exists?
  end
end
