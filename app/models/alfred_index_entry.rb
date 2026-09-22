# Etat d'indexation d'un enregistrement dans le corpus d'Alfred (voir Alfred::Corpus::Indexer).
# == Schema Information
#
# Table name: alfred_index_entries
#
#  id             :bigint           not null, primary key
#  chunks_count   :integer          default(0), not null
#  error          :text
#  file_digest    :string
#  file_extractor :string
#  indexed_at     :datetime
#  record_digest  :string
#  source_type    :string           not null
#  status         :string           default("pending"), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  source_id      :bigint           not null
#
# Indexes
#
#  index_alfred_index_entries_on_source  (source_type,source_id) UNIQUE
#  index_alfred_index_entries_on_status  (status)
#
class AlfredIndexEntry < ApplicationRecord
  STATUSES = %w[pending indexed failed].freeze

  belongs_to :source, polymorphic: true

  validates :status, inclusion: { in: STATUSES }

  scope :failed, -> { where(status: "failed") }
end
