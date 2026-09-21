# Points d'entree scriptables du module Voyages (utilises par Alfred).
namespace :trips do
  desc "Enfile la generation du rapport IA d'un voyage : rake trips:plan[ID]"
  task :plan, [:id] => :environment do |_t, args|
    trip = Trip.find(args[:id])
    plan = trip.generate_plan!
    puts "Voyage ##{trip.id} (#{trip.destination}) : rapport #{plan.status} (plan ##{plan.id})"
  end

  desc "Genere le rapport IA d'un voyage immediatement, sans passer par GoodJob : rake trips:plan_now[ID]"
  task :plan_now, [:id] => :environment do |_t, args|
    trip = Trip.find(args[:id])
    plan = trip.trip_plan || trip.build_trip_plan
    if plan.persisted? && plan.in_progress? && !plan.stuck?
      abort "Une generation est deja en cours pour ce voyage (plan ##{plan.id})"
    end

    plan.update!(status: "pending", error: nil, requested_at: Time.current, started_at: nil)
    TripPlanJob.perform_now(plan.id)
    plan.reload
    if plan.done?
      puts "Rapport genere (#{plan.model}) : total estime #{plan.estimated_total_eur} EUR"
    else
      abort "Echec : #{plan.error}"
    end
  end
end
