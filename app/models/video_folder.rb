# == Schema Information
#
# Table name: video_folders
#
#  id         :bigint           not null, primary key
#  name       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_video_folders_on_user_and_lower_name  (user_id, lower((name)::text)) UNIQUE
#  index_video_folders_on_user_id              (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#

# Dossier de classement des telechargements du module Downloader stockes sur
# le cloud OVH. Supprimer un dossier ne supprime pas ses fichiers : ils
# redeviennent simplement "non classes".
class VideoFolder < ApplicationRecord
  include UserOwned

  has_many :video_downloads, dependent: :nullify

  validates :name, presence: true, length: { maximum: 100 },
                   uniqueness: { case_sensitive: false, scope: :user_id }

  scope :ordered, -> { order(Arel.sql("lower(name)")) }
end
