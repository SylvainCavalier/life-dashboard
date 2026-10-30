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

# Echeance notable (credit, charges trimestrielles, URSSAF, impot, taxe fonciere...)
# affichee sous l'agenda. Chaque occurrence est posee dans l'agenda comme un
# evenement journee entiere (`Event#deadline_id`, type « echeance »), donc part
# aussi dans Google Agenda par les callbacks d'Event.
#
# Les occurrences recurrentes sont materialisees sur HORIZON glissant :
# `generated_until` retient jusqu'ou elles ont ete posees, le cron quotidien
# (DeadlineEventsJob) prolonge. Une occurrence supprimee a la main (dans l'agenda
# ou dans Google) ne revient donc pas, sauf si l'echeance elle-meme est modifiee :
# toute modification repose les occurrences a venir.
class Deadline < ApplicationRecord
  CATEGORIES = %w[credit charges impots social assurance loyer autre].freeze

  CATEGORY_LABELS = {
    "credit" => "Crédit / emprunt",
    "charges" => "Charges / copropriété",
    "impots" => "Impôts et taxes",
    "social" => "URSSAF / social",
    "assurance" => "Assurance",
    "loyer" => "Loyer",
    "autre" => "Autre"
  }.freeze

  RECURRENCES = %w[none monthly quarterly semiannual yearly].freeze

  RECURRENCE_LABELS = {
    "none" => "Une seule fois",
    "monthly" => "Tous les mois",
    "quarterly" => "Tous les trimestres",
    "semiannual" => "Tous les six mois",
    "yearly" => "Tous les ans"
  }.freeze

  RECURRENCE_MONTHS = { "monthly" => 1, "quarterly" => 3, "semiannual" => 6, "yearly" => 12 }.freeze

  HORIZON = 12.months

  # Colonnes dont le changement repose les occurrences a venir dans l'agenda.
  SCHEDULE_COLUMNS = %w[title category due_on recurrence ends_on amount notes].freeze

  has_many :events, dependent: nil # cle etrangere en nullify : les occurrences passees restent dans l'agenda

  validates :title, presence: true
  validates :due_on, presence: true
  validates :category, inclusion: { in: CATEGORIES }
  validates :recurrence, inclusion: { in: RECURRENCES }
  validates :amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validate :ends_on_after_due_on, if: -> { ends_on.present? && due_on.present? }

  after_create :sync_events!
  after_update :rebuild_events!, if: -> { saved_changes.keys.intersect?(SCHEDULE_COLUMNS) }
  before_destroy { remove_upcoming_events(one_off: !recurring?) }

  scope :ordered, -> { order(:due_on) }

  def recurring?
    recurrence != "none"
  end

  def category_label
    CATEGORY_LABELS[category]
  end

  def recurrence_label
    RECURRENCE_LABELS[recurrence]
  end

  # Occurrences comprises entre `from` et `to` (bornes incluses). Chacune est
  # calculee depuis `due_on` et non depuis la precedente : une echeance du 31
  # tombe le 28 fevrier puis de nouveau le 31 mars.
  def occurrences_between(from, to)
    return (from..to).cover?(due_on) ? [due_on] : [] unless recurring?

    step = RECURRENCE_MONTHS.fetch(recurrence)
    last = [to, ends_on].compact.min
    dates = []
    index = 0
    loop do
      date = due_on >> (step * index)
      break if date > last

      dates << date if date >= from
      index += 1
    end
    dates
  end

  def next_occurrence(today = Date.current)
    occurrences_between(today, today + 10.years).first
  end

  # Pose dans l'agenda les occurrences pas encore generees, jusqu'a HORIZON.
  def sync_events!(today = Date.current)
    if recurring?
      horizon = today + HORIZON
      from = generated_until ? [generated_until + 1, today].max : today
      occurrences_between(from, horizon).each { |date| create_event(date) }
      update_column(:generated_until, horizon)
    elsif generated_until.nil?
      create_event(due_on)
      update_column(:generated_until, due_on)
    end
  end

  # Echeance modifiee : les occurrences a venir sont retirees puis reposees.
  def rebuild_events!(today = Date.current)
    was_one_off = (saved_change_to_recurrence? ? recurrence_before_last_save : recurrence) == "none"
    remove_upcoming_events(today, one_off: was_one_off)
    update_column(:generated_until, nil)
    sync_events!(today)
  end

  # Texte de l'evenement d'agenda.
  def event_description
    header = ["Échéance notable", category_label, formatted_amount, recurrence_label].compact.join(" · ")
    [header, notes.presence].compact.join("\n\n")
  end

  def formatted_amount
    return nil if amount.nil?

    integer, decimals = format("%.2f", amount).split(".")
    "#{integer.reverse.scan(/\d{1,3}/).join(' ').reverse},#{decimals} €"
  end

  def self.upcoming_occurrences(today = Date.current, to = today + HORIZON)
    all.flat_map { |deadline| deadline.occurrences_between(today, to).map { |date| [deadline, date] } }
       .sort_by { |deadline, date| [date, deadline.title] }
  end

  private

  def create_event(date)
    events.create!(
      title: title,
      description: event_description,
      event_type: "echeance",
      color: Event::EVENT_TYPE_COLORS["echeance"],
      all_day: true,
      start_time: date.in_time_zone,
      reminder_minutes: 1440
    )
  end

  # Une echeance ponctuelle n'a qu'un evenement : il part avec elle, meme passe.
  def remove_upcoming_events(today = Date.current, one_off:)
    scope = one_off ? events : events.where(start_time: today.in_time_zone..)
    scope.find_each(&:destroy!)
  end

  def ends_on_after_due_on
    errors.add(:ends_on, "doit être après la première échéance") if ends_on < due_on
  end
end
