# (Re)indexe un enregistrement dans le corpus d'Alfred. Enfile par les callbacks
# after_commit poses par Alfred::Corpus.install_hooks!.
class AlfredIndexJob < ApplicationJob
  queue_as :default

  # Un echec (OCR indisponible, quota) est consigne sur AlfredIndexEntry ; GoodJob retente.
  retry_on StandardError, wait: :polynomially_longer, attempts: 4

  def perform(class_name, id)
    return unless Alfred::Corpus.indexed_models.include?(class_name)

    record = class_name.constantize.find_by(id: id) or return
    Alfred::Corpus::Indexer.call(record)
  end
end
