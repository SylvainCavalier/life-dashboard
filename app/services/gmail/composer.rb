module Gmail
  # Construit le message RFC 822 (gem `mail`) que l'API Gmail envoie ou range en
  # brouillon. Texte brut uniquement, pas de pieces jointes. Le client passe
  # `mail.to_s` tel quel : l'encodage base64 URL est fait par la gem Google.
  module Composer
    module_function

    def build(from:, to:, subject:, body:, cc: [], bcc: [], in_reply_to: nil, references: nil)
      mail = Mail.new
      mail.from = from
      mail.to = Array(to)
      mail.cc = Array(cc) if cc.present?
      mail.bcc = Array(bcc) if bcc.present?
      mail.subject = subject.to_s
      mail.in_reply_to = in_reply_to if in_reply_to.present?
      mail.references = references if references.present?
      mail.body = body.to_s
      mail.content_type = "text/plain; charset=UTF-8"
      mail
    end
  end
end
