# Etat d'indexation d'un enregistrement dans le corpus d'Alfred (voir Alfred::Corpus::Indexer).
class AlfredIndexEntry < ApplicationRecord
  STATUSES = %w[pending indexed failed].freeze

  belongs_to :source, polymorphic: true

  validates :status, inclusion: { in: STATUSES }

  scope :failed, -> { where(status: "failed") }
end
