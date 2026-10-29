# Extrait le brouillon d'une assurance de son contrat (InsuranceImports::Extractor).
# La table insurance_imports fait foi : la page sonde le statut jusqu'a done ou failed.
class InsuranceImportJob < ApplicationJob
  queue_as :default

  discard_on ActiveRecord::RecordNotFound

  def perform(import_id, extractor: InsuranceImports.default)
    import = InsuranceImport.find(import_id)
    return unless import.status == "pending"

    import.update!(status: "running")
    result = extractor.call(import.file.blob)
    import.update!(status: "done", draft: result[:draft], extractor: result[:extractor], error: nil, finished_at: Time.current)
  rescue ActiveRecord::RecordNotFound
    raise
  rescue StandardError => e
    Rails.logger.error "[InsuranceImportJob] import ##{import_id} en echec : #{e.class}: #{e.message}"
    message = e.is_a?(InsuranceImports::Error) ? e.message : "Erreur inattendue (#{e.class.name})"
    import&.update!(status: "failed", error: message.truncate(1000), finished_at: Time.current)
  end
end
