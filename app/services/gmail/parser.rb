module Gmail
  # Lecture des objets Google::Apis::GmailV1 : en-tetes, corps en texte, pieces
  # jointes. Fonctions pures, sans appel reseau.
  module Parser
    HEADERS = %w[From To Cc Subject Date Message-ID References In-Reply-To].freeze
    # Un fil complet part au modele : chaque message est borne.
    MAX_BODY = 6_000
    SYSTEM_LABELS = %w[INBOX UNREAD STARRED IMPORTANT SENT DRAFT TRASH SPAM CHAT
                       CATEGORY_PERSONAL CATEGORY_SOCIAL CATEGORY_PROMOTIONS CATEGORY_UPDATES CATEGORY_FORUMS].freeze

    module_function

    # Resume d'un fil (format metadata : en-tetes et extrait, pas de corps).
    def thread_summary(thread, label_names = {})
      messages = thread.messages.to_a
      last = messages.last
      labels = messages.flat_map { |m| m.label_ids.to_a }.uniq
      {
        thread_id: thread.id,
        subject: header(messages.first, "Subject").presence || "(sans objet)",
        from: header(last, "From"),
        participants: messages.map { |m| header(m, "From") }.compact.uniq.first(5),
        date: date(last),
        message_count: messages.size,
        unread: labels.include?("UNREAD"),
        in_inbox: labels.include?("INBOX"),
        starred: labels.include?("STARRED"),
        labels: (labels - SYSTEM_LABELS).map { |id| label_names.fetch(id, id) },
        snippet: last&.snippet.to_s.truncate(200)
      }
    end

    # Fil complet (format full) : chaque message avec son texte.
    def thread_full(thread, label_names = {})
      messages = thread.messages.to_a
      {
        thread_id: thread.id,
        subject: header(messages.first, "Subject").presence || "(sans objet)",
        messages: messages.map { |message| message_full(message, label_names) }
      }
    end

    def message_full(message, label_names = {})
      labels = message.label_ids.to_a
      {
        message_id: message.id,
        from: header(message, "From"),
        to: header(message, "To"),
        cc: header(message, "Cc"),
        date: date(message),
        subject: header(message, "Subject"),
        unread: labels.include?("UNREAD"),
        labels: (labels - SYSTEM_LABELS).map { |id| label_names.fetch(id, id) },
        body: body_text(message.payload).truncate(MAX_BODY),
        attachments: attachments(message.payload)
      }
    end

    # En-tetes utiles pour repondre dans le fil (Message-ID et References du dernier message).
    def reply_headers(message)
      message_id = header(message, "Message-ID")
      references = [header(message, "References"), message_id].compact_blank.join(" ")
      { in_reply_to: message_id, references: references.presence }
    end

    def header(message, name)
      headers = message&.payload&.headers or return nil
      headers.find { |h| h.name.casecmp?(name) }&.value
    end

    def date(message)
      return nil if message&.internal_date.blank?

      Time.zone.at(message.internal_date.to_i / 1000).iso8601
    end

    # text/plain de preference, sinon le HTML depouille de ses balises.
    def body_text(payload)
      plain = find_part(payload, "text/plain")
      return decode(plain.body.data) if plain

      html = find_part(payload, "text/html")
      return strip_html(decode(html.body.data)) if html

      ""
    end

    def find_part(part, mime_type)
      return nil if part.nil?
      return part if part.mime_type == mime_type && part.body&.data.present?

      part.parts.to_a.each do |child|
        found = find_part(child, mime_type)
        return found if found
      end
      nil
    end

    def attachments(part, found = [])
      return found if part.nil?

      found << { filename: part.filename, mime_type: part.mime_type, size: part.body&.size } if part.filename.present?
      part.parts.to_a.each { |child| attachments(child, found) }
      found
    end

    # La gem decode deja le base64 URL de `body.data` (propriete declaree :base64) :
    # ici on ne fait que fixer l'encodage.
    def decode(data)
      data.to_s.dup.force_encoding("UTF-8").scrub
    end

    # Les fins de bloc deviennent des sauts de ligne, sinon Nokogiri colle les paragraphes.
    def strip_html(html)
      doc = Nokogiri::HTML(html.gsub(%r{<br\s*/?>|</(p|div|tr|li|h[1-6]|blockquote|table)>}i, "\n"))
      doc.css("style, script, head").remove
      doc.text.gsub(/[ \t ]+/, " ").gsub(/ *\n */, "\n").gsub(/\n{3,}/, "\n\n").strip
    end
  end
end
