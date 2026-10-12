# == Schema Information
#
# Table name: daily_reports
#
#  id            :bigint           not null, primary key
#  content       :text
#  error         :text
#  finished_at   :datetime
#  input_tokens  :integer
#  model         :string
#  notified_at   :datetime
#  output_tokens :integer
#  read_at       :datetime
#  report_date   :date             not null
#  requested_at  :datetime
#  snapshot      :text
#  status        :string           default("pending"), not null
#  step          :string
#  weekend       :boolean          default(FALSE), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
# Indexes
#
#  index_daily_reports_on_report_date  (report_date) UNIQUE
#
# Rapport du matin d'Alfred : chaque jour a 9 h (cron DailyReportJob), Alfred passe
# en revue mails, agenda, echeances, CRM, anniversaires, projets, taches, abonnements
# et rappels, puis redige un rapport (Claude, sortie structuree) et previent Sylvain
# par une notification push. Le samedi et le dimanche, version allegee (`weekend`).
#
# Deux etapes reprenables (`step`) :
#   1. collect : DailyReports::Collector, Ruby pur, rassemble tout dans `snapshot`
#      (ce qu'Alfred a recu, pour audit et pour les liens du rapport) ;
#   2. write   : DailyReports::Writer, un seul appel a Claude, resultat dans `content`.
# `snapshot` et `content` sont chiffres : ils contiennent des extraits de mails.
class DailyReport < ApplicationRecord
  STATUSES = %w[pending running done failed].freeze
  STEPS = %w[collect write].freeze
  SECTIONS = %w[today mails people money priorities remarks].freeze
  # Au-dela, le job est mort avec le dyno : la relance redevient possible.
  STUCK_AFTER = 15.minutes

  serialize :snapshot, coder: JSON
  serialize :content, coder: JSON
  encrypts :snapshot
  encrypts :content

  has_many :conversations, class_name: "AlfredConversation", dependent: :nullify

  validates :report_date, presence: true, uniqueness: true
  validates :status, inclusion: { in: STATUSES }
  validates :step, inclusion: { in: STEPS }, allow_nil: true

  scope :recent, -> { order(report_date: :desc) }

  STATUSES.each do |state|
    define_method("#{state}?") { status == state }
  end

  def self.weekend?(date)
    date.saturday? || date.sunday?
  end

  # Point d'entree unique (cron, page, rake). Idempotent : le rapport d'un jour deja
  # fait ou en cours n'est pas relance, sauf `force` (bouton « Regenerer »), qui repart
  # d'une collecte fraiche. Renvoie le rapport.
  def self.run!(date = Date.current, force: false)
    report = find_or_create_by!(report_date: date) { |r| r.weekend = weekend?(date) }
    report.process!(force: force)
  rescue ActiveRecord::RecordNotUnique
    retry
  end

  def process!(force: false)
    with_lock do
      next if in_progress? && !stuck?
      next if done? && !force

      update!(status: "pending", step: nil, error: nil, requested_at: Time.current, finished_at: nil,
              snapshot: (force ? nil : snapshot), content: (force ? nil : content))
      DailyReportJob.perform_later(id)
    end
    self
  end

  def in_progress?
    (pending? || running?) && requested_at.present?
  end

  def stuck?
    in_progress? && requested_at < STUCK_AFTER.ago
  end

  def advance!(next_step)
    update!(step: next_step)
  end

  def unread?
    done? && read_at.nil?
  end

  # References citees par le rapport ("Contact#12", "Mail#18c...") -> { label, path | url }.
  # Seules celles de l'instantane existent : le Writer a deja ecarte les autres.
  def links
    refs = (snapshot || {})["refs"] || {}
    used = SECTIONS.flat_map { |key| Array(content&.dig(key)).flat_map { |item| Array(item["refs"]) } }.uniq
    refs.slice(*used)
  end

  def items_count
    SECTIONS.sum { |key| Array(content&.dig(key)).size }
  end

  # Texte brut du rapport : contexte d'une conversation « En parler a Alfred »,
  # et lecture par Alfred (query_records, champ calcule).
  def text
    return "" if content.blank?

    titles = { "today" => "Aujourd'hui", "mails" => "Courrier", "people" => "Personnes", "money" => "Échéances et abonnements",
               "priorities" => "Priorités", "remarks" => "Remarques" }
    refs = (snapshot || {})["refs"] || {}
    lines = [content["opening"].to_s]
    SECTIONS.each do |key|
      items = Array(content[key])
      next if items.empty?

      lines << "" << "## #{titles[key]}"
      items.each do |item|
        sources = Array(item["refs"]).map { |ref| "#{ref} (#{refs.dig(ref, 'label')})" }
        line = "- #{item['title']} : #{item['detail']}"
        line += " [#{sources.join(', ')}]" if sources.any?
        lines << line
      end
    end
    lines << "" << content["closing"].to_s
    lines.join("\n").strip
  end

  DAYS = %w[dimanche lundi mardi mercredi jeudi vendredi samedi].freeze
  MONTHS = %w[janvier février mars avril mai juin juillet août septembre octobre novembre décembre].freeze

  # « lundi 12 octobre 2026 »
  def self.human_date(date)
    "#{DAYS[date.wday]} #{date.day == 1 ? '1er' : date.day} #{MONTHS[date.month - 1]} #{date.year}"
  end

  def human_date
    self.class.human_date(report_date)
  end

  def push_payload
    {
      title: "Le rapport du #{human_date.sub(/ \d{4}\z/, '')} est servi",
      body: content&.dig("headline").to_s.truncate(180).presence || "Votre rapport du matin vous attend, Monsieur.",
      url: "/reports/#{id}",
      tag: "daily-report-#{id}"
    }
  end
end
