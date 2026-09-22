require "test_helper"

class Gmail::ComposerTest < ActiveSupport::TestCase
  test "un mail simple en texte brut UTF-8" do
    mail = Gmail::Composer.build(from: "admin@sbclabs.fr", to: ["alice@example.com"], subject: "Réunion",
                                 body: "Bonjour,\n\nÀ demain.\n\nSylvain")

    assert_equal ["admin@sbclabs.fr"], mail.from
    assert_equal ["alice@example.com"], mail.to
    assert_equal "Réunion", mail.subject
    assert_match "text/plain", mail.content_type
    assert_equal "Bonjour,\n\nÀ demain.\n\nSylvain", mail.body.decoded.force_encoding("UTF-8")
    assert_nil mail.in_reply_to
  end

  test "une reponse porte In-Reply-To et References dans le RFC 822 produit" do
    mail = Gmail::Composer.build(from: "admin@sbclabs.fr", to: "bob@example.com", cc: ["c@example.com"],
                                 subject: "Re: Devis", body: "Ok", in_reply_to: "<b@x>", references: "<a@x> <b@x>")

    assert_equal "b@x", mail.in_reply_to
    assert_equal %w[a@x b@x], mail.references
    assert_equal ["c@example.com"], mail.cc
    # References est replie sur deux lignes dans le RFC 822 : on ne verifie que In-Reply-To sur le texte brut.
    assert_match "In-Reply-To: <b@x>", mail.to_s
  end
end
