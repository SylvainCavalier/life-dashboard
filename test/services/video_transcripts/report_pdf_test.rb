require "test_helper"

class VideoTranscripts::ReportPdfTest < ActiveSupport::TestCase
  test "garde le cyrillique, les noms et le resume" do
    transcript = build(:video_transcript, :transcribed, created_at: Time.current, speaker_names: { "speaker_2" => "Sylvain" },
                                                        summary: { "overview" => "Une interview 🎬.",
                                                                   "claims" => [{ "timecode" => "00:00:08", "speaker" => "speaker_2", "statement" => "40 %" }] })
    text = PDF::Reader.new(StringIO.new(VideoTranscripts::ReportPdf.new(transcript).generate)).pages.map(&:text).join("\n")

    assert_match "Добрий день!", text
    assert_match "Sylvain", text
    assert_match "Une interview", text
    assert_match "Affirmations notables", text
  end
end
