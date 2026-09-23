module Meetings
  # Compte rendu de reunion en PDF (Prawn) : en-tete, synthese, puis transcription
  # complete par tour de parole. Memes contraintes que Alfred::ConversationPdf : les
  # polices de base de Prawn sont limitees a Windows-1252 (les accents francais y
  # sont), tout caractere hors de ce jeu est retire.
  class ReportPdf
    COLOR_TEXT = "1F2937"
    COLOR_MUTED = "6B7280"
    COLOR_ACCENT = "111827"
    COLOR_RULE = "E5E7EB"

    def initialize(meeting)
      @meeting = meeting
    end

    def generate
      Prawn::Fonts::AFM.hide_m17n_warning = true
      pdf = Prawn::Document.new(page_size: "A4", margin: [50, 50, 60, 50], info: { Title: clean(@meeting.title) })
      pdf.default_leading 2

      render_header(pdf)
      render_summary(pdf) if @meeting.summary.present?
      render_transcript(pdf)
      render_footer(pdf)

      pdf.render
    end

    def filename
      "reunion-#{@meeting.held_at.in_time_zone('Europe/Paris').strftime('%Y-%m-%d')}-#{@meeting.title.parameterize.first(60)}.pdf"
    end

    private

    def render_header(pdf)
      pdf.text "Compte rendu de réunion", size: 9, color: COLOR_MUTED
      pdf.text clean(@meeting.title), size: 18, style: :bold, color: COLOR_TEXT
      details = [
        @meeting.held_at.in_time_zone("Europe/Paris").strftime("%d/%m/%Y à %H:%M"),
        @meeting.kind_label,
        (@meeting.duration_seconds ? "durée #{Meeting.timecode(@meeting.duration_seconds)}" : nil)
      ].compact.join(" - ")
      pdf.text details, size: 10, color: COLOR_MUTED
      names = (@meeting.participant_list + @meeting.speakers.filter_map { |s| @meeting.speaker_names[s].presence }).uniq
      pdf.text "Participants : #{clean(names.join(', '))}", size: 10, color: COLOR_MUTED if names.any?
      pdf.move_down 4
      pdf.text "Enregistrement réalisé avec l'accord des participants ; transcription automatique, susceptible " \
               "de contenir des erreurs.", size: 8, style: :italic, color: COLOR_MUTED
      rule(pdf)
    end

    def render_summary(pdf)
      summary = @meeting.summary
      heading(pdf, "Synthèse")
      paragraphs(pdf, summary["overview"])
      bullets(pdf, "Points clés", summary["key_points"])
      bullets(pdf, "Décisions", summary["decisions"])
      actions = Array(summary["action_items"]).map do |item|
        extras = [item["owner"].presence, (item["due_date"].present? ? "pour le #{format_due(item['due_date'])}" : nil)].compact
        extras.any? ? "#{item['description']} (#{extras.join(', ')})" : item["description"]
      end
      bullets(pdf, "Actions à mener", actions)
      bullets(pdf, "Questions ouvertes", summary["open_questions"])
      rule(pdf)
    end

    def render_transcript(pdf)
      heading(pdf, "Transcription")
      if @meeting.transcript.blank?
        pdf.text "Aucune parole détectée dans l'enregistrement.", size: 10, color: COLOR_MUTED
        return
      end

      @meeting.turns.each do |turn|
        pdf.text "<b>#{escape(@meeting.speaker_label(turn['speaker']))}</b>  <color rgb='#{COLOR_MUTED}'>#{Meeting.timecode(turn['start'])}</color>",
                 size: 9, color: COLOR_ACCENT, inline_format: true
        pdf.text clean(turn["text"]), size: 10, color: COLOR_TEXT
        pdf.move_down 6
      end
    end

    def render_footer(pdf)
      pdf.number_pages "<page> / <total>", at: [pdf.bounds.right - 60, -30], width: 60, align: :right, size: 8, color: COLOR_MUTED
    end

    def heading(pdf, text)
      pdf.text text, size: 13, style: :bold, color: COLOR_TEXT
      pdf.move_down 6
    end

    def paragraphs(pdf, text)
      return if text.blank?

      text.to_s.split(/\n{2,}/).each do |paragraph|
        pdf.text clean(paragraph), size: 10, color: COLOR_TEXT
        pdf.move_down 6
      end
    end

    def bullets(pdf, title, items)
      items = Array(items).compact_blank
      return if items.empty?

      pdf.move_down 4
      pdf.text title, size: 10, style: :bold, color: COLOR_ACCENT
      items.each do |item|
        pdf.indent(10) { pdf.text "- #{clean(item)}", size: 10, color: COLOR_TEXT }
      end
      pdf.move_down 4
    end

    def rule(pdf)
      pdf.move_down 6
      pdf.stroke_color COLOR_RULE
      pdf.stroke_horizontal_rule
      pdf.stroke_color "000000"
      pdf.move_down 12
    end

    def format_due(value)
      Date.iso8601(value).strftime("%d/%m/%Y")
    rescue ArgumentError
      value
    end

    def clean(text)
      text.to_s.encode("Windows-1252", invalid: :replace, undef: :replace, replace: "").encode("UTF-8").strip
    end

    # Texte passe a inline_format : les chevrons d'un nom ne doivent pas devenir des balises.
    def escape(text)
      ERB::Util.html_escape(clean(text))
    end
  end
end
