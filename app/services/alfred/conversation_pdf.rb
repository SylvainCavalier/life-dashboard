module Alfred
  # Export d'une conversation avec Alfred en PDF (Prawn), pour la garder avant de
  # la vider. Texte seul : les reponses sont en Markdown, on retire la syntaxe
  # (gras, titres, liens) sans chercher a la mettre en page. Les polices de base
  # de Prawn sont limitees a Windows-1252 : tout caractere hors de ce jeu (emoji,
  # fleches...) est retire pour ne pas faire echouer le rendu.
  class ConversationPdf
    COLOR_TEXT = "1F2937"
    COLOR_MUTED = "6B7280"
    COLOR_USER = "111827"
    COLOR_RULE = "E5E7EB"

    def initialize(conversation)
      @conversation = conversation
    end

    def generate
      # Le texte est deja ramene a Windows-1252 par `clean` : l'avertissement m17n est inutile.
      Prawn::Fonts::AFM.hide_m17n_warning = true
      pdf = Prawn::Document.new(page_size: "A4", margin: [50, 50, 60, 50])
      pdf.default_leading 2

      render_header(pdf)
      @conversation.messages.each { |message| render_message(pdf, message) }
      render_footer(pdf)

      pdf.render
    end

    def filename
      date = (@conversation.last_message_at || @conversation.created_at).strftime("%Y-%m-%d")
      "alfred-#{date}-#{@conversation.id}.pdf"
    end

    private

    def render_header(pdf)
      pdf.text "Conversation avec Alfred", size: 18, style: :bold, color: COLOR_TEXT
      pdf.text clean(@conversation.title.presence || "Sans titre"), size: 11, color: COLOR_MUTED
      pdf.text "Du #{format_date(@conversation.created_at)} au #{format_date(@conversation.last_message_at || @conversation.updated_at)}",
               size: 9, color: COLOR_MUTED
      rule(pdf)
    end

    def render_message(pdf, message)
      return if message.content.blank? && message.error.blank?

      case message.role
      when "user"
        pdf.text "Sylvain", size: 9, style: :bold, color: COLOR_USER
        pdf.text clean(message.content), size: 10, color: COLOR_USER
      when "assistant"
        pdf.text "Alfred", size: 9, style: :bold, color: COLOR_MUTED
        message.steps.each { |step| pdf.text "> #{clean(step['label'])}", size: 8, color: COLOR_MUTED, style: :italic }
        pdf.text plain_text(message.content), size: 10, color: COLOR_TEXT if message.content.present?
        pdf.text "(#{clean(message.error)})", size: 9, color: "B91C1C" if message.status == "failed"
      when "event"
        pdf.text clean(message.content), size: 9, style: :italic, color: COLOR_MUTED, align: :center
      end
      pdf.text format_time(message.created_at), size: 7, color: COLOR_MUTED
      pdf.move_down 10
    end

    def render_footer(pdf)
      rule(pdf)
      pdf.text "Exporte le #{format_date(Time.current)} depuis le life-dashboard.", size: 8, color: COLOR_MUTED
      pdf.number_pages "<page> / <total>", at: [pdf.bounds.right - 60, -30], width: 60, align: :right, size: 8, color: COLOR_MUTED
    end

    def rule(pdf)
      pdf.move_down 6
      pdf.stroke_color COLOR_RULE
      pdf.stroke_horizontal_rule
      pdf.stroke_color "000000"
      pdf.move_down 12
    end

    # Markdown -> texte lisible : titres, gras, code, liens [libelle](url) -> libelle (url).
    def plain_text(markdown)
      text = markdown.to_s.dup
      text.gsub!(/^#{'#'}{1,6}\s+/, "")
      text.gsub!(/\[([^\]]+)\]\(([^)\s]+)\)/) { |_| Regexp.last_match(2).start_with?("/") ? Regexp.last_match(1) : "#{Regexp.last_match(1)} (#{Regexp.last_match(2)})" }
      text.gsub!(/\*\*([^*]+)\*\*/, '\1')
      text.gsub!(/(^|[\s(])\*([^*\s][^*]*)\*/, '\1\2')
      text.gsub!(/`{3}[^\n]*\n?/, "")
      text.gsub!(/`([^`]+)`/, '\1')
      text.gsub!(/^\s*[-*]\s+/, "- ")
      clean(text)
    end

    def clean(text)
      text.to_s.encode("Windows-1252", invalid: :replace, undef: :replace, replace: "").encode("UTF-8").strip
    end

    def format_date(time)
      time.in_time_zone("Paris").strftime("%d/%m/%Y")
    end

    def format_time(time)
      time.in_time_zone("Paris").strftime("%d/%m/%Y %H:%M")
    end
  end
end
