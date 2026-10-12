require "test_helper"

class Letters::PdfTest < ActiveSupport::TestCase
  test "met en page adresses, objet, contenu, signataire et pied de page" do
    letter = build(:letter, reference: "Dossier 42 <b>", body_text: "Madame, Monsieur,\n\nJe résilie l'abonnement « Box ».")

    text = PDF::Reader.new(StringIO.new(letter.to_pdf)).pages.map(&:text).join("\n")

    ["Sylvain Cavalier", "75371 Paris Cedex 08", "Créteil, le 12 octobre 2026", "Lettre recommandée avec accusé de réception",
     "Réf. : Dossier 42 <b>", "Objet : Résiliation de mon abonnement", "Je résilie l'abonnement « Box ».",
     "SIRET 123 456 789 00010"].each do |expected|
      assert_includes text, expected
    end
  end

  test "un long courrier passe sur plusieurs pages, numerotees" do
    letter = build(:letter, body_text: Array.new(60) { |i| "Paragraphe #{i} " + ("texte " * 30) }.join("\n\n"))

    reader = PDF::Reader.new(StringIO.new(letter.to_pdf))
    assert_operator reader.page_count, :>, 1
    assert_includes reader.pages.first.text, "1 / #{reader.page_count}"
  end

  test "un courrier vide se genere quand meme" do
    assert Letter.new.to_pdf.start_with?("%PDF")
  end

  test "en mise en page compacte, le contenu commence plus haut qu'avec une enveloppe a fenetre" do
    top_of = lambda do |letter|
      receiver = PDF::Reader::PageTextReceiver.new
      PDF::Reader.new(StringIO.new(letter.to_pdf)).pages.first.walk(receiver)
      receiver.runs.find { |run| run.text.include?("Objet") }.origin.y
    end

    assert_operator top_of.call(build(:letter)), :>, top_of.call(build(:letter, window_envelope: true)) + 100
  end
end
