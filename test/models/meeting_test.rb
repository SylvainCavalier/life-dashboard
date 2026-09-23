# == Schema Information
#
# Table name: meetings
#
#  id               :bigint           not null, primary key
#  context          :text
#  duration_seconds :integer
#  error            :text
#  finished_at      :datetime
#  held_at          :datetime         not null
#  kind             :string           default("in_person"), not null
#  participants     :text
#  requested_at     :datetime
#  speaker_names    :jsonb            not null
#  status           :string           default("pending"), not null
#  step             :string
#  summary          :jsonb            not null
#  summary_model    :string
#  title            :string           not null
#  transcript       :jsonb            not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  document_id      :bigint
#
# Indexes
#
#  index_meetings_on_document_id  (document_id)
#  index_meetings_on_held_at      (held_at)
#
# Foreign Keys
#
#  fk_rails_...  (document_id => documents.id) ON DELETE => nullify
#
require "test_helper"

class MeetingTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "fusionne les segments consecutifs d'un meme intervenant en tours de parole" do
    meeting = build(:meeting, :transcribed)

    turns = meeting.turns
    assert_equal 2, turns.size
    assert_equal "Bonjour Marie, on fait le point sur le bail. Le locataire part en decembre.", turns.first["text"]
    assert_equal 6.2, turns.first["end"]
    assert_equal %w[speaker_1 speaker_2], meeting.speakers
  end

  test "libelle des intervenants : nom saisi, sinon numero" do
    meeting = build(:meeting, :transcribed, speaker_names: { "speaker_2" => "Marie" })

    assert_equal "Intervenant 1", meeting.speaker_label("speaker_1")
    assert_equal "Marie", meeting.speaker_label("speaker_2")
    assert_match "[00:00:06] Marie : J'envoie", meeting.transcript_text
  end

  test "refuse un fichier qui n'est pas de l'audio" do
    meeting = build(:meeting)
    meeting.audio.attach(io: StringIO.new("%PDF-1.4"), filename: "note.pdf", content_type: "application/pdf")

    assert_not meeting.valid?
    assert meeting.errors[:audio].any?
  end

  test "process! enfile le traitement une seule fois" do
    meeting = create(:meeting, :with_audio)

    assert_enqueued_jobs 1, only: MeetingProcessJob do
      meeting.process!
      meeting.process!
    end
    assert meeting.reload.in_progress?
  end

  test "regenerate! efface la synthese mais garde la transcription" do
    meeting = create(:meeting, :transcribed, status: "done", summary: { "overview" => "ancien" }, summary_model: "x")

    assert_enqueued_jobs 1, only: MeetingProcessJob do
      meeting.regenerate!
    end
    meeting.reload
    assert_equal({}, meeting.summary)
    assert_equal 3, meeting.transcript.size
    assert meeting.pending?
  end

  def attach_chunk(meeting, part, seq, body = "x#{part}#{seq}")
    meeting.audio_chunks.attach(io: StringIO.new(body), filename: Meeting.chunk_filename(part, seq, "audio/webm"),
                                content_type: "audio/webm")
  end

  test "regroupe les morceaux par partie, dans l'ordre, quel que soit l'ordre d'arrivee" do
    meeting = create(:meeting, status: "recording")
    [[1, 1], [2, 0], [1, 0], [1, 10], [1, 2]].each { |part, seq| attach_chunk(meeting, part, seq) }

    parts = meeting.reload.audio_parts.map { |blobs| blobs.map { |blob| blob.filename.to_s } }
    assert_equal [%w[part-001-000000.webm part-001-000001.webm part-001-000002.webm part-001-000010.webm],
                  %w[part-002-000000.webm]], parts
    assert_equal({ chunks: 5, parts: 2, next_part: 3, bytes: meeting.audio_chunks.blobs.sum(&:byte_size) }, meeting.recording_stats)
  end

  test "finish! lance le traitement d'un enregistrement, et le refuse sans audio" do
    meeting = create(:meeting, status: "recording")
    assert_raises(ArgumentError) { meeting.finish! }

    attach_chunk(meeting, 1, 0)
    assert_enqueued_jobs 1, only: MeetingProcessJob do
      meeting.reload.finish!
    end
    assert meeting.reload.pending?
  end

  test "les voix d'une partie reprise sont libellees a part" do
    meeting = build(:meeting)

    assert_equal "Intervenant 1 (partie 2)", meeting.speaker_label("p2_speaker_1")
  end
end

