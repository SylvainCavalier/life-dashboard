# == Schema Information
#
# Table name: script_folders
#
#  id          :bigint           not null, primary key
#  description :text
#  handle      :string
#  name        :string           not null
#  platform    :string           default("youtube"), not null
#  position    :integer          default(0), not null
#  url         :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_script_folders_on_lower_name  (lower((name)::text)) UNIQUE
#

# Dossier de la page Scripts : une chaine YouTube ou un compte de reseau social.
# Supprimer un dossier ne supprime pas ses scripts : ils redeviennent « non classes ».
class ScriptFolder < ApplicationRecord
  PLATFORMS = %w[youtube x instagram tiktok linkedin facebook bluesky threads podcast other].freeze

  PLATFORM_LABELS = {
    "youtube" => "YouTube", "x" => "X / Twitter", "instagram" => "Instagram", "tiktok" => "TikTok",
    "linkedin" => "LinkedIn", "facebook" => "Facebook", "bluesky" => "Bluesky", "threads" => "Threads",
    "podcast" => "Podcast", "other" => "Autre"
  }.freeze

  # Format propose par defaut pour un nouveau script du dossier.
  DEFAULT_KINDS = { "youtube" => "video", "tiktok" => "short", "instagram" => "short", "x" => "thread",
                    "bluesky" => "thread", "threads" => "thread", "podcast" => "video" }.freeze

  has_many :scripts, dependent: :nullify

  validates :name, presence: true, length: { maximum: 100 }, uniqueness: { case_sensitive: false }
  validates :platform, inclusion: { in: PLATFORMS }
  validates :handle, :url, length: { maximum: 250 }

  scope :ordered, -> { order(:position, Arel.sql("lower(name)")) }

  def default_kind
    DEFAULT_KINDS.fetch(platform, "post")
  end

  def api_attributes(scripts_count: nil)
    attributes.symbolize_keys.merge(
      platform_label: PLATFORM_LABELS[platform],
      default_kind: default_kind,
      scripts_count: scripts_count
    ).compact
  end
end
