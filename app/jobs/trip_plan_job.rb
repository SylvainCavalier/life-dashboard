# Génère le rapport IA d'un voyage (Trips::PlanGenerationService) et
# l'enregistre sur le TripPlan. L'ancien contenu est conservé tant que la
# nouvelle génération n'a pas abouti : un échec laisse le rapport précédent
# consultable.
class TripPlanJob < ApplicationJob
  queue_as :default

  # Voyage supprimé entre l'enqueue et l'exécution.
  discard_on ActiveRecord::RecordNotFound

  def perform(trip_plan_id)
    plan = TripPlan.find(trip_plan_id)
    # Idempotence : une ré-exécution GoodJob d'un job déjà traité ne relance
    # pas un appel OpenAI.
    return unless plan.status == "pending"

    plan.update!(status: "running", started_at: Time.current)

    trip = plan.trip
    result = Trips::PlanGenerationService.new(trip).call

    plan.update!(
      status: "done",
      content: result[:content],
      model: result[:model],
      generated_at: Time.current,
      error: nil,
      estimated_total_eur: result[:content].dig("costs", "total_eur"),
      input_fingerprint: trip.plan_fingerprint
    )
    Rails.logger.info "[TripPlanJob] plan ##{plan.id} genere pour le voyage ##{trip.id} (#{result[:model]})"
  rescue ActiveRecord::RecordNotFound
    raise
  rescue StandardError => e
    message = readable_error(e)
    Rails.logger.error "[TripPlanJob] plan ##{trip_plan_id} en echec : #{message}"
    plan&.update!(status: "failed", error: message.truncate(1000))
  end

  private

  # Le message d'une erreur HTTP OpenAI ne contient que le statut et l'URL ;
  # le libellé utile (quota epuise, modele inconnu...) est dans le corps.
  def readable_error(error)
    return "#{error.class}: #{error.message}" unless error.is_a?(OpenAI::Errors::APIStatusError)

    body = error.body
    detail = body.is_a?(Hash) ? (body.dig(:error, :message) || body.dig("error", "message")) : nil
    "OpenAI (HTTP #{error.status}) : #{detail.presence || error.message}"
  end
end
