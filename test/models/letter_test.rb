# == Schema Information
#
# Table name: letters
#
#  id                :bigint           not null, primary key
#  body              :jsonb            not null
#  footer            :text
#  include_signature :boolean          default(TRUE), not null
#  letter_date       :date
#  mention           :string
#  place             :string
#  recipient         :text
#  reference         :string
#  sender            :text
#  signatory         :string
#  subject           :string
#  window_envelope   :boolean          default(FALSE), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  document_id       :bigint
#
# Indexes
#
#  index_letters_on_document_id  (document_id)
#
# Foreign Keys
#
#  fk_rails_...  (document_id => documents.id) ON DELETE => nullify
#
require "test_helper"

class LetterTest < ActiveSupport::TestCase
  PNG_BYTES = Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==")

  test "le contenu s'ecrit en texte brut et se stocke en document Tiptap nettoye" do
    letter = create(:letter, body_text: "Bonjour,\n\nMerci.")

    assert_equal "doc", letter.body["type"]
    assert_equal "Bonjour,\n\nMerci.", letter.reload.body_text
  end

  test "le JSON recu est nettoye a l'enregistrement" do
    letter = create(:letter, body: { "type" => "doc", "content" => [{ "type" => "image", "attrs" => { "src" => "x" } }] })

    assert_equal [], letter.body["content"]
  end

  test "a la creation, les champs absents sont repris du profil, pas les champs vides" do
    PersonalProfile.create!(first_name: "Sylvain", last_name: "Cavalier", city: "Créteil")

    absent = Letter.create!(subject: "Sans expéditeur")
    assert_equal "Sylvain Cavalier\nCréteil", absent.sender
    assert_equal "Sylvain Cavalier", absent.signatory
    assert_equal "Créteil", absent.place
    assert_equal Date.current, absent.letter_date

    empty = Letter.create!(subject: "Choix", sender: "", place: "", signatory: "")
    assert_equal ["", "", ""], [empty.sender, empty.place, empty.signatory]
  end

  test "lieu et date a la francaise, 1er compris" do
    assert_equal "Créteil, le 12 octobre 2026", build(:letter).place_and_date
    assert_equal "le 1er août 2026", build(:letter, place: "", letter_date: Date.new(2026, 8, 1)).place_and_date
  end

  test "libelle : objet, sinon premiere ligne du destinataire" do
    assert_equal "Résiliation de mon abonnement", build(:letter).label
    assert_equal "Free - Service Résiliation", build(:letter, subject: "").label
    assert_equal "Courrier sans objet", build(:letter, subject: "", recipient: "").label
  end

  test "la signature du profil n'est jointe que si elle est demandee" do
    profile = PersonalProfile.create!(first_name: "Sylvain", last_name: "Cavalier")
    profile.signature.attach(io: StringIO.new(PNG_BYTES), filename: "signature.png", content_type: "image/png")

    assert_nil build(:letter, include_signature: false).signature_data
    assert_equal PNG_BYTES, build(:letter, include_signature: true).signature_data.b
  end

  test "save_to_documents! cree le document puis le remplace" do
    letter = create(:letter)

    document = letter.save_to_documents!
    assert_equal "letters", document.domain
    assert_equal "sent", document.category
    assert_equal "Courrier - Résiliation de mon abonnement", document.name
    assert_equal "application/pdf", document.file.content_type

    letter.update!(subject: "Nouvel objet")
    assert_no_difference -> { Document.count } do
      letter.save_to_documents!
    end
    assert_equal "Courrier - Nouvel objet", document.reload.name
  end

  test "supprimer le document detache la lettre sans la supprimer" do
    letter = create(:letter)
    letter.save_to_documents!.destroy

    assert_nil letter.reload.document_id
  end
end
