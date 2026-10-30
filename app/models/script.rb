# == Schema Information
#
# Table name: scripts
#
#  id               :bigint           not null, primary key
#  body             :text             default(""), not null
#  kind             :string           default("video"), not null
#  notes            :text
#  planned_on       :date
#  published_on     :date
#  published_url    :string
#  status           :string           default("idea"), not null
#  title            :string           not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  script_folder_id :bigint
#
# Indexes
#
#  index_scripts_on_script_folder_id  (script_folder_id)
#  index_scripts_on_status            (status)
#  index_scripts_on_updated_at        (updated_at)
#
# Foreign Keys
#
#  fk_rails_...  (script_folder_id => script_folders.id) ON DELETE => nullify
#

# Script d'une video YouTube, d'un short, d'un thread ou d'un post (page Scripts), range
# dans le dossier de sa chaine ou de son compte (`script_folder`, facultatif). Le texte
# est brut (`body`) : c'est lui que liront les futurs outils d'aide a l'ecriture.
# Dans un thread, une ligne `---` separe deux messages.
class Script < ApplicationRecord
  KINDS = %w[video short thread post other].freeze
  KIND_LABELS = { "video" => "Vidéo", "short" => "Short / Reel", "thread" => "Thread",
                  "post" => "Post", "other" => "Autre" }.freeze

  STATUSES = %w[idea draft review ready published abandoned].freeze
  STATUS_LABELS = { "idea" => "Idée", "draft" => "Brouillon", "review" => "À relire", "ready" => "Prêt",
                    "published" => "Publié", "abandoned" => "Abandonné" }.freeze

  # Debit de lecture face camera, pour estimer la duree d'une video (a reprendre dans useScripts.js).
  WORDS_PER_MINUTE = 150
  # Longueur d'un message sur X (sans abonnement) : signale les messages trop longs d'un thread.
  POST_MAX_CHARS = 280
  THREAD_SEPARATOR = /^[ \t]*-{3,}[ \t]*$/
  MAX_BODY_LENGTH = 200_000

  belongs_to :script_folder, optional: true

  validates :title, presence: true, length: { maximum: 250 }
  validates :kind, inclusion: { in: KINDS }
  validates :status, inclusion: { in: STATUSES }
  validates :body, length: { maximum: MAX_BODY_LENGTH }
  validates :published_url, length: { maximum: 500 }

  before_validation { self.body = body.to_s }
  before_save :stamp_publication

  scope :ordered, -> { order(updated_at: :desc) }

  def word_count
    body.scan(/[[:alnum:]]+(?:['’-][[:alnum:]]+)*/).size
  end

  # Duree estimee a voix haute, en secondes (videos et shorts).
  def estimated_duration
    (word_count * 60.0 / WORDS_PER_MINUTE).round
  end

  # Messages d'un thread, sans les blocs vides.
  def thread_posts
    body.split(THREAD_SEPARATOR).map(&:strip).reject(&:empty?)
  end

  def api_attributes(full: true)
    base = attributes.symbolize_keys.except(:body).merge(
      kind_label: KIND_LABELS[kind],
      status_label: STATUS_LABELS[status],
      folder_name: script_folder&.name,
      word_count: word_count,
      estimated_duration: estimated_duration,
      posts_count: kind == "thread" ? thread_posts.size : nil
    )
    full ? base.merge(body: body) : base.merge(excerpt: body.squish.truncate(220))
  end

  private

  # Passe a « publie » sans date : la date du jour.
  def stamp_publication
    self.published_on ||= Date.current if status == "published" && will_save_change_to_status?
  end
end
