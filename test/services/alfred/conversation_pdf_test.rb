require "test_helper"

class AlfredConversationPdfTest < ActiveSupport::TestCase
  test "exporte les messages en PDF, sans syntaxe Markdown ni caracteres hors police" do
    conversation = AlfredConversation.create!(title: "Mon bail", last_message_at: Time.current)
    conversation.messages.create!(role: "user", content: "Que dit mon bail sur le dépôt de garantie ?")
    conversation.messages.create!(
      role: "assistant", content: "**Un mois** de loyer, Monsieur 🎩. Voir [le bail](/documents/3) et [Telecharger](https://x.test/f.pdf).",
      steps: [{ "tool" => "search_corpus", "label" => "Recherche : « bail »" }]
    )
    conversation.messages.create!(role: "event", content: "Ecriture confirmee.")

    pdf = Alfred::ConversationPdf.new(conversation)
    data = pdf.generate

    assert data.start_with?("%PDF")
    assert_match(/\Aalfred-\d{4}-\d{2}-\d{2}-#{conversation.id}\.pdf\z/, pdf.filename)

    text = PDF::Reader.new(StringIO.new(data)).pages.map(&:text).join("\n")
    assert_includes text, "Mon bail"
    assert_includes text, "dépôt de garantie"
    assert_includes text, "Un mois de loyer, Monsieur"
    assert_includes text, "le bail et Telecharger (https://x.test/f.pdf)"
    assert_includes text, "Ecriture confirmee."
    assert_not_includes text, "**"
  end
end
