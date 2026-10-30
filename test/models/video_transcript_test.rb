# == Schema Information
#
# Table name: video_transcripts
#
#  id                :bigint           not null, primary key
#  duration_seconds  :integer
#  error             :text
#  finished_at       :datetime
#  language          :string           default("auto"), not null
#  requested_at      :datetime
#  source_citation   :text
#  speaker_names     :jsonb            not null
#  status            :string           default("pending"), not null
#  step              :string
#  summary           :jsonb            not null
#  summary_model     :string
#  title             :string           not null
#  transcribed_at    :datetime
#  transcript        :jsonb            not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  document_id       :bigint
#  user_id           :bigint           not null
#  video_download_id :bigint
#
# Indexes
#
#  index_video_transcripts_on_created_at         (created_at)
#  index_video_transcripts_on_document_id        (document_id)
#  index_video_transcripts_on_user_id            (user_id)
#  index_video_transcripts_on_video_download_id  (video_download_id)
#
# Foreign Keys
#
#  fk_rails_...  (document_id => documents.id) ON DELETE => nullify
#  fk_rails_...  (user_id => users.id)
#  fk_rails_...  (video_download_id => video_downloads.id) ON DELETE => nullify
#
require "test_helper"

class VideoTranscriptTest < ActiveSupport::TestCase
  include VideoDownloadStorageHelper

  test "exige une video ou un telechargement disponible" do
    transcript = build(:video_transcript)

    assert_not transcript.valid?
    assert_includes transcript.errors.full_messages, "Aucune video jointe"
  end

  test "refuse un fichier qui n'est ni video ni audio" do
    transcript = build(:video_transcript)
    transcript.video.attach(io: StringIO.new("%PDF"), filename: "x.pdf", content_type: "application/pdf")

    assert_not transcript.valid?
    assert transcript.errors[:video].any?
  end

  test "refuse une langue inconnue et envoie nil a Voxtral en detection automatique" do
    assert_not build(:video_transcript, :with_video, language: "de").valid?
    assert_nil build(:video_transcript, language: "auto").language_code
    assert_equal "uk", build(:video_transcript, language: "uk").language_code
  end

  test "reprend titre et citation d'un telechargement dont le fichier est disponible" do
    download = create(:video_download, :completed, platform: "YouTube", uploader: "Chaine")
    FileUtils.mkdir_p(download.local_dir)
    File.write(download.local_filepath, "fake video")

    transcript = VideoTranscript.build_from_download(download, language: "ru")

    assert transcript.valid?, transcript.errors.full_messages.to_sentence
    assert_equal "Une video", transcript.title
    assert_match "Chaine (YouTube)", transcript.source_citation
    transcript.with_source_file { |path, filename, _| assert_equal [download.local_filepath, download.filename], [path, filename] }
  end

  test "refuse un telechargement dont le fichier a disparu" do
    download = create(:video_download, :completed)

    assert_not VideoTranscript.build_from_download(download).valid?
  end

  test "tours de parole et libelles communs aux reunions" do
    transcript = build(:video_transcript, :transcribed, speaker_names: { "speaker_2" => "Sylvain" })

    assert_equal 2, transcript.turns.size
    assert_equal "Intervenant 1", transcript.speaker_label("speaker_1")
    assert_match "[00:00:08] Sylvain : Merci", transcript.transcript_text
    assert_match "[speaker_2 = Sylvain]", transcript.transcript_for_model
  end

  test "range le PDF dans les documents puis remplace le fichier du meme document" do
    transcript = create(:video_transcript, :transcribed, summary: { "overview" => "Une interview." })

    document = transcript.save_to_documents!
    assert_equal ["transcriptions", "video", "Une interview."], [document.domain, document.category, document.notes]
    assert_equal "application/pdf", document.file.content_type

    transcript.update!(summary: { "overview" => "Nouveau resume." })
    assert_no_difference -> { Document.count } do
      assert_equal document.id, transcript.save_to_documents!.id
    end
    assert_equal "Nouveau resume.", document.reload.notes
  end
end
