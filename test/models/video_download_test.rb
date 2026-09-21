# == Schema Information
#
# Table name: video_downloads
#
#  id              :bigint           not null, primary key
#  canonical_url   :string
#  completed_at    :datetime
#  description     :text
#  duration        :integer
#  error_message   :text
#  file_size       :bigint
#  filename        :string
#  format          :string           not null
#  platform        :string
#  published_at    :datetime
#  quality         :string
#  status          :string           default("pending"), not null
#  storage         :string           not null
#  thumbnail_url   :string
#  title           :string
#  uploader        :string
#  uploader_handle :string
#  uploader_url    :string
#  url             :string           not null
#  view_count      :bigint
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  video_folder_id :bigint
#
# Indexes
#
#  index_video_downloads_on_created_at       (created_at)
#  index_video_downloads_on_status           (status)
#  index_video_downloads_on_video_folder_id  (video_folder_id)
#
# Foreign Keys
#
#  fk_rails_...  (video_folder_id => video_folders.id)
#
require "test_helper"

class VideoDownloadTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include VideoDownloadStorageHelper

  test "la factory est valide" do
    assert build(:video_download).valid?
    assert build(:video_download, :audio).valid?
  end

  test "l'URL doit etre en http(s)" do
    assert_not build(:video_download, url: "ftp://exemple.fr/video").valid?
    assert_not build(:video_download, url: "--exec=rm").valid?
    assert_not build(:video_download, url: "").valid?
  end

  test "format, stockage et qualite sont restreints aux valeurs connues" do
    assert_not build(:video_download, format: "avi").valid?
    assert_not build(:video_download, storage: "ftp").valid?
    assert_not build(:video_download, quality: "4k").valid?
  end

  test "la qualite est obligatoire en mp4 et ignoree en mp3" do
    assert_not build(:video_download, quality: nil).valid?

    audio = build(:video_download, :audio, quality: "720p")
    assert audio.valid?
    assert_nil audio.quality
  end

  test "un dossier n'est accepte que pour le stockage cloud" do
    folder = create(:video_folder)

    assert_not build(:video_download, video_folder: folder).valid?
    assert build(:video_download, :cloud, video_folder: folder).valid?
  end

  test "enqueue! cree un telechargement en attente et enfile le job" do
    download = nil
    assert_enqueued_with(job: VideoDownloadJob) do
      download = VideoDownload.enqueue!(url: "https://youtu.be/abc", format: "mp3", storage: "local")
    end

    assert download.pending?
    assert_enqueued_with(job: VideoDownloadJob, args: [ download.id ])
  end

  test "enqueue! leve une erreur sans rien enfiler si les attributs sont invalides" do
    assert_no_enqueued_jobs do
      assert_raises(ActiveRecord::RecordInvalid) do
        VideoDownload.enqueue!(url: "pas-une-url", format: "mp4", quality: "original", storage: "local")
      end
    end
  end

  test "storage_key range le fichier par dossier avec un nom assaini" do
    folder = create(:video_folder, name: "Droit du travail")
    download = create(:video_download, :cloud, :completed, video_folder: folder,
                                                           filename: "Héhé l'été [abc].mp4")

    assert_equal "video_downloads/droit-du-travail/#{download.id}-hehe-l-ete-abc.mp4", download.storage_key

    download.video_folder = nil
    assert_match %r{\Avideo_downloads/unsorted/}, download.storage_key
  end

  test "file_available? reflete la presence reelle du fichier local" do
    download = create(:video_download, :completed)
    assert_not download.file_available?

    FileUtils.mkdir_p(download.local_dir)
    File.write(download.local_filepath, "contenu")
    assert download.file_available?
  end

  test "la suppression efface le repertoire local" do
    download = create(:video_download, :completed)
    FileUtils.mkdir_p(download.local_dir)
    File.write(download.local_filepath, "contenu")

    download.destroy
    assert_not File.exist?(download.local_dir)
  end

  test "citation assemble titre, auteur, plateforme, date de publication, URL et date de consultation" do
    download = build(:video_download, :completed, title: "Me at the zoo", uploader: "jawed", platform: "Youtube",
                                                  published_at: Time.utc(2005, 4, 24, 3, 31),
                                                  canonical_url: "https://www.youtube.com/watch?v=jNQXAC9IVRw",
                                                  completed_at: Time.utc(2026, 9, 21, 10))

    assert_equal "« Me at the zoo », jawed (Youtube), publié le 24/04/2005, " \
                 "https://www.youtube.com/watch?v=jNQXAC9IVRw (consulté le 21/09/2026)", download.citation
  end

  test "citation se contente de ce qui est connu, et n'existe pas avant la fin du telechargement" do
    assert_nil build(:video_download).citation

    sparse = build(:video_download, :completed, title: nil, url: "https://crowdbunker.com/v/abc",
                                                completed_at: Time.utc(2026, 9, 21))
    assert_equal "« https://crowdbunker.com/v/abc », https://crowdbunker.com/v/abc (consulté le 21/09/2026)",
                 sparse.citation
  end

  test "supprimer un dossier conserve ses telechargements" do
    folder = create(:video_folder)
    download = create(:video_download, :cloud, video_folder: folder)

    folder.destroy
    assert_nil download.reload.video_folder_id
  end

  test "le nom d'un dossier est unique sans tenir compte de la casse" do
    create(:video_folder, name: "Musique")
    assert_not build(:video_folder, name: "musique").valid?
  end
end
