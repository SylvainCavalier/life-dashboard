# == Schema Information
#
# Table name: calendar_syncs
#
#  id             :bigint           not null, primary key
#  deleted_count  :integer          default(0), not null
#  last_error     :text
#  last_synced_at :datetime
#  pulled_count   :integer          default(0), not null
#  pushed_count   :integer          default(0), not null
#  started_at     :datetime
#  status         :string           default("idle"), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
# Etat de la synchronisation Google Calendar, sur une seule ligne. Comme pour le
# Downloader et la Sentinelle, la table fait foi : l'interface la sonde tant
# qu'une synchronisation est en cours.
class CalendarSync < ApplicationRecord
  STATUSES = %w[idle queued running done failed].freeze
  # Au-dela, une synchronisation « en cours » est consideree abandonnee
  # (redemarrage du dyno) et peut etre relancee.
  STALE_AFTER = 20.minutes

  validates :status, inclusion: { in: STATUSES }

  def self.current
    first || create!
  end

  # Point d'entree unique (API et rake) : enfile une synchronisation sauf si une
  # est deja en attente ou en cours.
  def self.run!
    state = current
    return state if state.active?

    state.update!(status: "queued", last_error: nil)
    GoogleCalendarPullJob.perform_later
    state
  end

  # Reserve la synchronisation au job appelant. Un seul gagnant si le cron et
  # le bouton tombent en meme temps : c'est l'UPDATE conditionnel qui tranche.
  def self.claim!
    state = current
    stale_before = Time.current - STALE_AFTER
    claimed = where(id: state.id)
              .where("status <> 'running' OR started_at IS NULL OR started_at < ?", stale_before)
              .update_all(status: "running", started_at: Time.current, last_error: nil, updated_at: Time.current)
    claimed == 1 ? state.reload : nil
  end

  def active?
    return true if status == "queued"

    status == "running" && started_at.present? && started_at > Time.current - STALE_AFTER
  end

  def finish!(report)
    update!(status: "done", last_synced_at: Time.current, pulled_count: report.pulled,
            pushed_count: report.pushed, deleted_count: report.deleted,
            last_error: report.errors.presence&.join(" | "))
  end

  def fail!(message)
    update!(status: "failed", last_error: message)
  end

  def as_json(_options = nil)
    {
      enabled: GoogleCalendar.enabled?,
      calendar_id: GoogleCalendar.calendar_id,
      status: status,
      active: active?,
      last_synced_at: last_synced_at,
      started_at: started_at,
      last_error: last_error,
      pulled_count: pulled_count,
      pushed_count: pushed_count,
      deleted_count: deleted_count
    }
  end
end
