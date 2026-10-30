# Compare deux PDF (DocumentComparisons::Comparator) puis purge les fichiers.
# La table document_comparisons fait foi : la page sonde le statut jusqu'a done ou failed.
class DocumentComparisonJob < ApplicationJob
  queue_as :default

  discard_on ActiveRecord::RecordNotFound

  def perform(comparison_id, comparator: DocumentComparisons.default)
    comparison = DocumentComparison.find(comparison_id)
    return unless comparison.status == "pending"

    comparison.update!(status: "running")
    outcome = comparator.call(comparison.file_a.blob, comparison.file_b.blob, focus: comparison.focus)
    comparison.update!(status: "done", result: outcome[:result], extractors: outcome[:extractors], error: nil, finished_at: Time.current)
  rescue ActiveRecord::RecordNotFound
    raise
  rescue StandardError => e
    Rails.logger.error "[DocumentComparisonJob] comparaison ##{comparison_id} en echec : #{e.class}: #{e.message}"
    message = e.is_a?(DocumentComparisons::Error) ? e.message : "Erreur inattendue (#{e.class.name})"
    comparison&.update!(status: "failed", error: message.truncate(1000), finished_at: Time.current)
  ensure
    comparison&.purge_files!
  end
end
