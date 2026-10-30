# == Schema Information
#
# Table name: deadlines
#
#  id              :bigint           not null, primary key
#  amount          :decimal(10, 2)
#  category        :string           default("autre"), not null
#  due_on          :date             not null
#  ends_on         :date
#  generated_until :date
#  notes           :text
#  recurrence      :string           default("none"), not null
#  title           :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_deadlines_on_due_on  (due_on)
#
require "test_helper"

class DeadlineTest < ActiveSupport::TestCase
  setup { travel_to Time.zone.local(2026, 10, 12, 10, 0) }
  teardown { travel_back }

  test "une echeance ponctuelle pose un seul evenement journee entiere, meme passee" do
    deadline = create(:deadline, title: "Déclaration de revenus", recurrence: "none", due_on: Date.new(2026, 5, 20))

    event = deadline.events.sole
    assert event.all_day
    assert_equal "echeance", event.event_type
    assert_equal Date.new(2026, 5, 20), event.start_time.to_date
    assert_match "1 240,00 €", event.description
  end

  test "une echeance mensuelle est posee sur douze mois a partir d'aujourd'hui, fins de mois comprises" do
    deadline = create(:deadline, title: "Crédit", recurrence: "monthly", due_on: Date.new(2025, 1, 31))

    dates = deadline.events.order(:start_time).map { |e| e.start_time.to_date }
    assert_equal Date.new(2026, 10, 31), dates.first
    assert_equal Date.new(2026, 11, 30), dates.second
    assert_equal Date.new(2027, 2, 28), dates[4]
    assert_equal 12, dates.size
    assert_equal Date.new(2027, 10, 12), deadline.reload.generated_until
  end

  test "ends_on arrete la serie" do
    deadline = create(:deadline, recurrence: "quarterly", due_on: Date.new(2026, 1, 5), ends_on: Date.new(2027, 1, 5))

    assert_equal([Date.new(2027, 1, 5)], deadline.events.map { |e| e.start_time.to_date })
  end

  test "le cron prolonge sans reposer une occurrence supprimee a la main" do
    deadline = create(:deadline, recurrence: "monthly", due_on: Date.new(2026, 11, 1))
    deadline.events.order(:start_time).first.destroy!

    travel_to Time.zone.local(2026, 12, 15, 4, 0) do
      DeadlineEventsJob.perform_now
    end

    dates = deadline.events.order(:start_time).map { |e| e.start_time.to_date }
    assert_not_includes dates, Date.new(2026, 11, 1)
    assert_equal Date.new(2027, 12, 1), dates.last
  end

  test "modifier l'echeance repose les occurrences a venir et garde les passees" do
    deadline = create(:deadline, recurrence: "monthly", due_on: Date.new(2026, 9, 10))
    past = Event.create!(title: "Ancienne", start_time: Date.new(2026, 9, 10).in_time_zone, all_day: true,
                         deadline: deadline)

    deadline.update!(title: "Crédit auto", due_on: Date.new(2026, 9, 20))

    upcoming = deadline.events.where(start_time: Time.current..).order(:start_time)
    assert_equal Date.new(2026, 10, 20), upcoming.first.start_time.to_date
    assert(upcoming.all? { |e| e.title == "Crédit auto" })
    assert Event.exists?(past.id)
  end

  test "supprimer l'echeance retire les occurrences a venir, les passees restent sans lien" do
    deadline = create(:deadline, recurrence: "monthly", due_on: Date.new(2026, 11, 1))
    past = Event.create!(title: "Passée", start_time: Date.new(2026, 9, 1).in_time_zone, all_day: true,
                         deadline: deadline)

    deadline.destroy!

    assert_equal [past.id], Event.pluck(:id)
    assert_nil past.reload.deadline_id
  end

  test "upcoming_occurrences trie toutes les echeances par date" do
    create(:deadline, title: "Taxe foncière", recurrence: "yearly", due_on: Date.new(2026, 10, 15))
    create(:deadline, title: "URSSAF", category: "social", recurrence: "quarterly", due_on: Date.new(2026, 7, 31))

    occurrences = Deadline.upcoming_occurrences.map { |deadline, date| [deadline.title, date] }
    assert_equal ["Taxe foncière", Date.new(2026, 10, 15)], occurrences.first
    assert_equal ["URSSAF", Date.new(2026, 10, 31)], occurrences.second
  end

  test "validations" do
    assert_not build(:deadline, category: "inconnue").valid?
    assert_not build(:deadline, recurrence: "weekly").valid?
    assert_not build(:deadline, due_on: Date.new(2026, 5, 1), ends_on: Date.new(2026, 4, 1)).valid?
  end
end
