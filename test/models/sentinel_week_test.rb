# == Schema Information
#
# Table name: sentinel_weeks
#
#  id                  :bigint           not null, primary key
#  digest              :jsonb            not null
#  digest_generated_at :datetime
#  digest_model        :string
#  domain              :string           not null
#  error               :text
#  finished_at         :datetime
#  monday              :date             not null
#  progress_done       :integer          default(0), not null
#  progress_total      :integer          default(0), not null
#  requested_at        :datetime
#  started_at          :datetime
#  status              :string           default("pending"), not null
#  step                :string
#  warnings            :jsonb            not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
# Indexes
#
#  index_sentinel_weeks_on_domain_and_monday  (domain,monday) UNIQUE
#
require "test_helper"

class SentinelWeekTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "une semaine doit commencer un lundi" do
    week = build(:sentinel_week, monday: Date.new(2026, 9, 15))
    assert_not week.valid?
    assert_includes week.errors[:monday], "doit etre un lundi"
  end

  test "une seule semaine par domaine et par lundi, mais un meme lundi dans deux domaines" do
    create(:sentinel_week)
    assert_not build(:sentinel_week).valid?
    assert build(:sentinel_week, :labor_law).valid?
  end

  test "domaine inconnu refuse" do
    assert_not build(:sentinel_week, domain: "cuisine").valid?
  end

  test "parse_monday refuse un autre jour et une date illisible" do
    assert_equal Date.new(2026, 9, 14), SentinelWeek.parse_monday("2026-09-14")
    assert_raises(ArgumentError) { SentinelWeek.parse_monday("2026-09-16") }
    assert_raises(Date::Error) { SentinelWeek.parse_monday("n'importe quoi") }
  end

  test "last_completed_monday renvoie le lundi de la semaine ecoulee" do
    assert_equal Date.new(2026, 9, 14), SentinelWeek.last_completed_monday(Date.new(2026, 9, 21))
    assert_equal Date.new(2026, 9, 14), SentinelWeek.last_completed_monday(Date.new(2026, 9, 27))
  end

  test "la fenetre va du lundi 0 h au dimanche 23 h 59, heure de Paris" do
    window = SentinelWeek.window(Date.new(2026, 9, 14))
    assert window.cover?(Time.utc(2026, 9, 13, 22, 30)), "lundi 0 h 30 a Paris"
    assert window.cover?(Time.utc(2026, 9, 20, 21, 30)), "dimanche 23 h 30 a Paris"
    assert_not window.cover?(Time.utc(2026, 9, 20, 22, 30)), "lundi suivant 0 h 30 a Paris"
  end

  test "run! cree la semaine, installe les sources et enfile le job" do
    assert_enqueued_with(job: SentinelWeekJob) do
      week = SentinelWeek.run!("desinformation", "2026-09-14")
      assert week.pending?
      assert week.in_progress?
    end
    assert SentinelSource.for_domain("desinformation").exists?
  end

  test "run! ne relance pas une semaine deja en cours" do
    create(:sentinel_week, :running)
    assert_no_enqueued_jobs { SentinelWeek.run!("desinformation", "2026-09-14") }
  end

  test "run! relance une semaine bloquee" do
    create(:sentinel_week, :running, requested_at: 2.hours.ago)
    assert_enqueued_with(job: SentinelWeekJob) { SentinelWeek.run!("desinformation", "2026-09-14") }
  end

  test "run! refuse un domaine inconnu" do
    assert_raises(Sentinel::Domains::UnknownDomain) { SentinelWeek.run!("cuisine", "2026-09-14") }
  end

  test "une semaine jamais demandee n'est pas en cours" do
    week = SentinelWeek.create!(domain: "desinformation", monday: Date.new(2026, 9, 7))
    assert week.pending?
    assert_not week.in_progress?
  end
end
