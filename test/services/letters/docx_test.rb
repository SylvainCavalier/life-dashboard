require "test_helper"

class Letters::DocxTest < ActiveSupport::TestCase
  PNG_BYTES = Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==")

  def entries(data)
    files = {}
    Zip::File.open_buffer(StringIO.new(data)) { |zip| zip.entries.each { |e| files[e.name] = e.get_input_stream.read.force_encoding(Encoding::UTF_8) } }
    files
  end

  test "produit un paquet WordprocessingML valide, texte echappe" do
    letter = build(:letter, subject: "Loyer < 800 € & charges")
    files = entries(letter.to_docx)

    assert_equal ["[Content_Types].xml", "_rels/.rels", "word/_rels/document.xml.rels", "word/styles.xml", "word/document.xml",
                  "word/footer1.xml"], files.keys
    files.each_value { |xml| Nokogiri::XML(xml) { |config| config.strict } }
    assert_includes files["word/document.xml"], "Objet : Loyer &lt; 800 € &amp; charges"
    assert_includes files["word/footer1.xml"], "SIRET 123 456 789 00010"
  end

  test "embarque la signature du profil quand elle est demandee, sans pied de page vide" do
    profile = PersonalProfile.create!(first_name: "Sylvain", last_name: "Cavalier")
    profile.signature.attach(io: StringIO.new(PNG_BYTES), filename: "signature.png", content_type: "image/png")

    files = entries(build(:letter, include_signature: true, footer: "").to_docx)

    assert_equal PNG_BYTES, files["word/media/signature.png"].b
    assert_includes files["word/_rels/document.xml.rels"], "media/signature.png"
    assert_not files.key?("word/footer1.xml")
  end
end
