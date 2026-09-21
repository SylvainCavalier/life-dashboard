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
# Une semaine va TOUJOURS du lundi au dimanche inclus, à la collecte comme à la
# lecture (veille-juridique collectait du lundi au vendredi mais lisait
# jusqu'au dimanche).
class SentinelWeek < ApplicationRecord
  STATUSES = %w[pending running done failed].freeze
  STEPS = %w[collect summarize digest].freeze

  # Une semaine chargée (200 textes Légifrance, 80 résumés) reste sous ce délai ;
  # au-delà, le job est mort avec le dyno et la relance doit redevenir possible.
  STUCK_AFTER = 30.minutes

  validates :domain, inclusion: { in: ->(_) { Sentinel::Domains.keys } }
  validates :monday, presence: true, uniqueness: { scope: :domain }
  validates :status, inclusion: { in: STATUSES }
  validates :step, inclusion: { in: STEPS }, allow_nil: true
  validate :monday_is_a_monday

  scope :for_domain, ->(domain) { where(domain: domain.to_s) }
  scope :recent, -> { order(monday: :desc) }

  STATUSES.each do |state|
    define_method("#{state}?") { status == state }
  end

  # Dernière semaine entièrement écoulée : c'est elle que l'on traite par défaut.
  def self.last_completed_monday(today = Date.current)
    today.beginning_of_week - 7
  end

  # Bornes horaires d'une semaine, en heure de Paris quel que soit le fuseau de
  # l'application : un article du dimanche 23 h 30 appartient à la semaine qui finit.
  def self.window(monday)
    zone = Time.find_zone!("Europe/Paris")
    zone.local(monday.year, monday.month, monday.day)..(zone.local(monday.year, monday.month, monday.day) + 7.days - 1.second)
  end

  def self.parse_monday(value)
    date = value.is_a?(Date) ? value : Date.iso8601(value.to_s)
    raise ArgumentError, "#{date} n'est pas un lundi" unless date.monday?

    date
  end

  # Point d'entrée unique (API, rake task, Alfred) : prépare la semaine et
  # enfile le traitement. Verrou de ligne contre le double clic ; une relance
  # reprend où le traitement précédent s'est arrêté (documents déjà collectés
  # et déjà résumés conservés).
  def self.run!(domain_key, monday)
    domain = Sentinel::Domains.find!(domain_key)
    SentinelSource.bootstrap!(domain.key)
    week = find_or_create_by!(domain: domain.key, monday: parse_monday(monday))

    week.with_lock do
      next if week.in_progress? && !week.stuck?

      week.mark_requested!
      SentinelWeekJob.perform_later(week.id)
    end
    week
  end

  def mark_requested!
    update!(status: "pending", step: nil, error: nil, requested_at: Time.current, started_at: nil,
            finished_at: nil, progress_done: 0, progress_total: 0)
  end

  def domain_config
    Sentinel::Domains.find!(domain)
  end

  def sunday
    monday + 6
  end

  def documents
    SentinelDocument.where(domain: domain, monday: monday)
  end

  # Une semaine en cours ne peut pas être entièrement collectée.
  def complete?
    sunday < Date.current
  end

  # Une ligne tout juste créée est "pending" sans avoir été demandée : elle
  # n'est pas en cours pour autant.
  def in_progress?
    (pending? || running?) && requested_at.present?
  end

  def stuck?
    in_progress? && requested_at < STUCK_AFTER.ago
  end

  def digest?
    digest.present? && digest["tldr"].present?
  end

  def advance!(step, total: 0)
    update!(step: step, progress_done: 0, progress_total: total)
  end

  def tick!
    increment!(:progress_done) # rubocop:disable Rails/SkipsModelValidations
  end

  private

  def monday_is_a_monday
    errors.add(:monday, "doit etre un lundi") if monday.present? && !monday.monday?
  end
end
