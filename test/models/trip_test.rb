# == Schema Information
#
# Table name: trips
#
#  id             :bigint           not null, primary key
#  country_code   :string(2)        not null
#  departure_city :string           default("Paris")
#  destination    :string           not null
#  end_date       :date             not null
#  notes          :text
#  start_date     :date             not null
#  status         :string           default("envisage"), not null
#  travelers      :integer          default(1), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
# Indexes
#
#  index_trips_on_country_code  (country_code)
#  index_trips_on_start_date    (start_date)
#  index_trips_on_status        (status)
#
require "test_helper"

class TripTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "un voyage valide s'enregistre" do
    assert build(:trip).valid?
  end

  test "la date de retour ne peut pas preceder la date de depart" do
    trip = build(:trip, start_date: Date.new(2027, 4, 10), end_date: Date.new(2027, 4, 9))
    assert_not trip.valid?
    assert_includes trip.errors[:end_date].join, "postérieure"
  end

  test "le code pays est normalise en minuscules et doit etre ISO alpha-2" do
    trip = create(:trip, country_code: " JP ")
    assert_equal "jp", trip.country_code

    assert_not build(:trip, country_code: "JPN").valid?
    assert_not build(:trip, country_code: "").valid?
  end

  test "le statut est controle" do
    assert_not build(:trip, status: "termine").valid?
  end

  test "duree, passe et visite sont derives des dates et du statut" do
    upcoming = create(:trip)
    past = create(:trip, :past)
    cancelled = create(:trip, :past, :cancelled)

    assert_equal 8, upcoming.duration_days
    assert_not upcoming.past?
    assert_not upcoming.visited?
    assert past.past?
    assert past.visited?
    assert cancelled.past?
    assert_not cancelled.visited?

    assert_equal [past.country_code], Trip.visited_country_codes
  end

  test "generate_plan! cree le plan en attente et enfile le job" do
    trip = create(:trip)

    plan = nil
    assert_enqueued_with(job: TripPlanJob) do
      plan = trip.generate_plan!
    end

    assert plan.persisted?
    assert_equal "pending", plan.status
    assert plan.requested_at.present?
  end

  test "generate_plan! ne relance pas une generation en cours" do
    trip = create(:trip)
    plan = create(:trip_plan, :running, trip: trip, requested_at: 2.minutes.ago)

    assert_no_enqueued_jobs do
      assert_equal plan, trip.generate_plan!
    end
    assert_equal "running", plan.reload.status
  end

  test "generate_plan! relance un plan bloque depuis trop longtemps" do
    trip = create(:trip)
    plan = create(:trip_plan, :running, trip: trip, requested_at: 30.minutes.ago)
    assert plan.stuck?

    assert_enqueued_with(job: TripPlanJob) do
      trip.generate_plan!
    end
    assert_equal "pending", plan.reload.status
  end

  test "generate_plan! regenere un rapport termine en conservant le contenu" do
    trip = create(:trip)
    plan = create(:trip_plan, trip: trip)

    assert_enqueued_with(job: TripPlanJob) { trip.generate_plan! }
    plan.reload
    assert_equal "pending", plan.status
    assert_equal "Le Japon au printemps.", plan.content["summary"]
  end

  test "le rapport est obsolete quand le voyage change" do
    trip = create(:trip)
    plan = create(:trip_plan, trip: trip)
    assert_not plan.outdated?

    trip.update!(end_date: trip.end_date + 2.days)
    assert plan.reload.outdated?
  end

  test "supprimer un voyage supprime son plan et ses items" do
    trip = create(:trip)
    create(:trip_plan, trip: trip)
    create(:trip_item, trip: trip)

    assert_difference ["TripPlan.count", "TripItem.count"], -1 do
      trip.destroy
    end
  end
end
