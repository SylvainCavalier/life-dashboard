require "test_helper"

class Meetings::ReportPdfTest < ActiveSupport::TestCase
  test "produit un PDF avec la synthese et la transcription" do
    meeting = build(:meeting, :transcribed, speaker_names: { "speaker_2" => "Marie <Dupont>" }, summary: {
      "overview" => "Point sur la sortie du locataire.\n\nEtat des lieux a planifier.",
      "key_points" => ["Depart en decembre"], "decisions" => [],
      "action_items" => [{ "description" => "Envoyer l'etat des lieux", "owner" => "Marie", "due_date" => "2026-11-15" }],
      "open_questions" => ["Montant de la caution a rendre ? 🤔"]
    })

    report = Meetings::ReportPdf.new(meeting)
    pdf = report.generate

    assert pdf.start_with?("%PDF")
    assert_equal "reunion-2026-09-22-point-sur-le-bail.pdf", report.filename
    text = PDF::Reader.new(StringIO.new(pdf)).pages.map(&:text).join("\n")
    assert_match "Synthèse", text
    assert_match "Marie <Dupont>", text
    assert_match "15/11/2026", text
    assert_match "Le locataire part en decembre", text
  end

  test "sans synthese ni parole, le PDF reste lisible" do
    pdf = Meetings::ReportPdf.new(build(:meeting)).generate

    assert_match "Aucune parole", PDF::Reader.new(StringIO.new(pdf)).pages.map(&:text).join
  end
end
