require "test_helper"

class Gmail::ParserTest < ActiveSupport::TestCase
  Api = Google::Apis::GmailV1

  def part(mime, data: nil, filename: nil, parts: nil)
    # `data` tel que la gem le livre : deja decode du base64 URL.
    body = Api::MessagePartBody.new(data: data, size: data&.bytesize || 1234)
    Api::MessagePart.new(mime_type: mime, filename: filename, body: body, parts: parts)
  end

  # Pas `message` : Minitest a deja une methode de ce nom.
  def gmail_message(id:, headers:, payload:, labels: [], date: Time.utc(2026, 9, 22, 8), snippet: "extrait")
    Api::Message.new(
      id: id, label_ids: labels, snippet: snippet, internal_date: date.to_i * 1000,
      payload: payload.tap { |p| p.headers = headers.map { |name, value| Api::MessagePartHeader.new(name: name, value: value) } }
    )
  end

  test "le texte brut est prefere, sinon le HTML est depouille" do
    plain_and_html = part("multipart/alternative", parts: [part("text/plain", data: "Bonjour en clair"),
                                                           part("text/html", data: "<p>Bonjour <b>HTML</b></p>")])
    assert_equal "Bonjour en clair", Gmail::Parser.body_text(plain_and_html)

    html_only = part("multipart/mixed", parts: [part("text/html", data: "<html><head><style>p{}</style></head>" \
                                                                        "<body><p>Bonjour</p><p>Cordialement</p></body></html>")])
    assert_equal "Bonjour\nCordialement", Gmail::Parser.body_text(html_only)
  end

  test "les pieces jointes sont listees, meme imbriquees" do
    payload = part("multipart/mixed", parts: [
                     part("multipart/alternative", parts: [part("text/plain", data: "Ci-joint")]),
                     part("application/pdf", filename: "contrat.pdf")
                   ])

    attachments = Gmail::Parser.attachments(payload)

    assert_equal [{ filename: "contrat.pdf", mime_type: "application/pdf", size: 1234 }], attachments
  end

  test "un fil est resume avec ses en-tetes, son etat et ses libelles nommes" do
    first = gmail_message(id: "m1", headers: { "From" => "alice@example.com", "Subject" => "Devis" },
                          payload: part("text/plain", data: "x"), labels: %w[INBOX Label_7])
    last = gmail_message(id: "m2", headers: { "From" => "bob@example.com", "Subject" => "Re: Devis" },
                         payload: part("text/plain", data: "y"), labels: %w[INBOX UNREAD], date: Time.utc(2026, 9, 23, 9),
                         snippet: "Voici le devis")
    thread = Api::Thread.new(id: "t1", messages: [first, last])

    summary = Gmail::Parser.thread_summary(thread, { "Label_7" => "Clients" })

    assert_equal "t1", summary[:thread_id]
    assert_equal "Devis", summary[:subject]
    assert_equal "bob@example.com", summary[:from]
    assert_equal %w[alice@example.com bob@example.com], summary[:participants]
    assert summary[:unread]
    assert summary[:in_inbox]
    assert_equal ["Clients"], summary[:labels]
    assert_equal 2, summary[:message_count]
    assert_equal "Voici le devis", summary[:snippet]
    assert_equal Time.utc(2026, 9, 23, 9), Time.zone.parse(summary[:date])
  end

  test "les en-tetes de reponse enchainent References et Message-ID" do
    last = gmail_message(id: "m2", headers: { "Message-ID" => "<b@x>", "References" => "<a@x>" },
                         payload: part("text/plain", data: "y"))

    assert_equal({ in_reply_to: "<b@x>", references: "<a@x> <b@x>" }, Gmail::Parser.reply_headers(last))
  end

  test "un fil complet borne le corps de chaque message" do
    long = gmail_message(id: "m1", headers: { "From" => "a@x", "Subject" => "Long" },
                         payload: part("text/plain", data: "a" * 10_000))
    full = Gmail::Parser.thread_full(Api::Thread.new(id: "t", messages: [long]))

    assert_equal Gmail::Parser::MAX_BODY, full[:messages].first[:body].length
    assert_equal "Long", full[:subject]
  end
end
