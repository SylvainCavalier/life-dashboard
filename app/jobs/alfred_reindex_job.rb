# Reindexation complete du corpus d'Alfred (bouton du chat, ou `rails alfred:index`).
class AlfredReindexJob < ApplicationJob
  queue_as :default

  def perform(force: false)
    Alfred::Corpus::Reindexer.new(force: force).call
  end
end
