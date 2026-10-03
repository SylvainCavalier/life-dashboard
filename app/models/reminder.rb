# == Schema Information
#
# Table name: reminders
#
#  id              :bigint           not null, primary key
#  acknowledged_at :datetime
#  attempts        :integer          default(0), not null
#  completed_at    :datetime
#  email_sent_at   :datetime
#  last_attempt_at :datetime
#  notes           :text
#  notified_at     :datetime
#  recurrence      :string           default("none"), not null
#  remind_at       :datetime         not null
#  remindable_type :string
#  title           :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  remindable_id   :bigint
#
# Indexes
#
#  index_reminders_on_completed_at  (completed_at)
#  index_reminders_on_remind_at     (remind_at)
#  index_reminders_on_remindable    (remindable_type,remindable_id)
#
# Rappel date : a l'heure dite, une notification push part vers chaque appareil
# abonne (voir PushNotifications), puis est relancee tant que Sylvain ne l'a pas
# vue, et un mail prend le relais en dernier recours (ReminderDispatchJob).
#
# `remind_at` est la prochaine echeance. Les colonnes de livraison (attempts,
# notified_at, last_attempt_at, acknowledged_at, email_sent_at) decrivent
# l'occurrence en cours et sont remises a zero des que `remind_at` change :
# reporter un rappel ou passer a l'occurrence suivante relance tout le circuit.
class Reminder < ApplicationRecord
  RECURRENCES = %w[none daily weekly monthly yearly].freeze

  RECURRENCE_LABELS = {
    "none" => "Une seule fois",
    "daily" => "Tous les jours",
    "weekly" => "Toutes les semaines",
    "monthly" => "Tous les mois",
    "yearly" => "Tous les ans"
  }.freeze

  # Fiches du dashboard auxquelles un rappel peut renvoyer.
  REMINDABLE_TYPES = %w[Contact Task Project Event Document Property Subscription Trip Company Note].freeze

  # Une notification, deux relances espacees de RETRY_INTERVAL, puis le mail.
  MAX_PUSHES = 3
  RETRY_INTERVAL = 10.minutes

  DELIVERY_COLUMNS = %w[attempts notified_at last_attempt_at acknowledged_at email_sent_at].freeze

  belongs_to :remindable, polymorphic: true, optional: true

  validates :title, presence: true
  validates :remind_at, presence: true
  validates :recurrence, inclusion: { in: RECURRENCES }
  validates :remindable_type, inclusion: { in: REMINDABLE_TYPES }, allow_nil: true
  # Seulement quand le lien change : une fiche supprimee depuis ne doit pas bloquer
  # les relances ni le report (le rappel garde un lien mort, sans consequence).
  validate :remindable_exists, if: -> { will_save_change_to_remindable_type? || will_save_change_to_remindable_id? }
  validate :remind_at_not_in_past, on: :create

  before_validation { self.remindable_type = remindable_type.presence }
  before_save :reset_delivery, if: :will_save_change_to_remind_at?

  scope :active, -> { where(completed_at: nil) }
  scope :completed, -> { where.not(completed_at: nil) }
  scope :due, ->(now = Time.current) { active.where(remind_at: ..now) }
  scope :ordered, -> { order(remind_at: :asc) }

  def recurring?
    recurrence != "none"
  end

  def due?(now = Time.current)
    completed_at.nil? && remind_at <= now
  end

  # Occurrence qui suit `time` selon la recurrence (nil pour un rappel ponctuel).
  def next_occurrence(time = remind_at)
    case recurrence
    when "daily" then time + 1.day
    when "weekly" then time + 1.week
    when "monthly" then time + 1.month
    when "yearly" then time + 1.year
    end
  end

  # Premiere occurrence strictement posterieure a `now`.
  def upcoming_occurrence(now = Time.current)
    time = remind_at
    time = next_occurrence(time) while time <= now
    time
  end

  # Prochaine etape de livraison de l'occurrence en cours : :push, :email ou nil.
  def delivery_step(now = Time.current)
    return nil unless due?(now) && acknowledged_at.nil?
    return :push if attempts.zero?
    return nil if last_attempt_at && last_attempt_at > now - RETRY_INTERVAL
    return :push if attempts < MAX_PUSHES

    email_sent_at.nil? ? :email : nil
  end

  # Rappel recurrent dont l'occurrence suivante est deja passee (Sylvain n'a rien
  # traite entre-temps) : on saute a la derniere echue, les manquees se fondent en une.
  def catch_up!(now = Time.current)
    return false unless recurring? && completed_at.nil?
    return false unless next_occurrence <= now

    time = remind_at
    time = next_occurrence(time) while next_occurrence(time) <= now
    update!(remind_at: time)
  end

  # Notification ouverte : les relances s'arretent, le rappel reste « a traiter ».
  def acknowledge!(now = Time.current)
    return false unless due?(now) && acknowledged_at.nil?

    update!(acknowledged_at: now)
  end

  # Fait : un rappel ponctuel est termine, un rappel recurrent passe a l'occurrence suivante.
  def done!(now = Time.current)
    if recurring?
      update!(remind_at: upcoming_occurrence(now))
    else
      update!(completed_at: now, acknowledged_at: acknowledged_at || now)
    end
  end

  def snooze!(until_time)
    update!(remind_at: until_time)
  end

  DAYS = %w[dimanche lundi mardi mercredi jeudi vendredi samedi].freeze
  MONTHS = %w[janvier février mars avril mai juin juillet août septembre octobre novembre décembre].freeze

  # « Lundi 5 octobre à 09:00 », heure de Paris (pas de locale fr chargée dans l'application).
  def self.human_time(time)
    time = time.in_time_zone
    "#{DAYS[time.wday].capitalize} #{time.day} #{MONTHS[time.month - 1]} à #{time.strftime('%H:%M')}"
  end

  def recurrence_label
    RECURRENCE_LABELS[recurrence]
  end

  # Libelle et page de la fiche liee, repris du registre du corpus d'Alfred.
  def remindable_summary
    return nil unless remindable

    config = Alfred::Corpus.config_for(remindable) || {}
    {
      type: remindable_type, id: remindable_id,
      label: config[:label]&.call(remindable).presence || "#{remindable_type} ##{remindable_id}",
      path: config[:path]&.call(remindable)
    }
  end

  # Contenu chiffre de la notification (le service worker l'affiche tel quel).
  def push_payload(badge_count: Reminder.due.count)
    {
      title: title,
      body: notes.presence&.truncate(180) || self.class.human_time(remind_at),
      url: "/reminders?open=#{id}",
      tag: "reminder-#{id}",
      reminder_id: id,
      renotify: attempts.positive?,
      badge_count: badge_count
    }
  end

  private

  def reset_delivery
    DELIVERY_COLUMNS.each { |column| self[column] = column == "attempts" ? 0 : nil }
    # Reprogrammer un rappel termine le rouvre.
    self.completed_at = nil unless will_save_change_to_completed_at?
  end

  def remindable_exists
    return if remindable_type.blank? && remindable_id.blank?

    klass = remindable_type.to_s.safe_constantize
    return if klass && remindable_id.present? && klass.exists?(remindable_id)

    errors.add(:remindable, "introuvable (#{remindable_type} ##{remindable_id})")
  end

  def remind_at_not_in_past
    return unless remind_at && remind_at < 10.minutes.ago

    errors.add(:remind_at, "est deja passee")
  end
end
