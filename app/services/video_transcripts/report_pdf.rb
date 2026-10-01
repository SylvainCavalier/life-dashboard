module VideoTranscripts
  # Transcription de video en PDF (Prawn) : en-tete, resume, puis transcription complete
  # par tour de parole, horodatee. Contrairement aux autres PDF de l'application (polices
  # de base, Windows-1252), celui-ci embarque DejaVu Sans (vendor/fonts/dejavu) : une
  # video en russe ou en ukrainien doit garder son alphabet cyrillique.
  class ReportPdf
    FONT_DIR = Rails.root.join("vendor/fonts/dejavu")
    COLOR_TEXT = "1F2937"
    COLOR_MUTED = "6B7280"
    COLOR_ACCENT = "111827"
    COLOR_RULE = "E5E7EB"

    def initialize(transcript)
      @transcript = transcript
    end

    def generate
      pdf = Prawn::Document.new(page_size: "A4", margin: [50, 50, 60, 50], info: { Title: clean(@transcript.title) })
      pdf.font_families.update("DejaVu" => {
        normal: FONT_DIR.join("DejaVuSans.ttf").to_s, bold: FONT_DIR.join("DejaVuSans-Bold.ttf").to_s,
        italic: FONT_DIR.join("DejaVuSans-Oblique.ttf").to_s, bold_italic: FONT_DIR.join("DejaVuSans-Bold.ttf").to_s
      })
      pdf.font "DejaVu"
      pdf.default_leading 2

      render_header(pdf)
      render_summary(pdf) if @transcript.summary.present?
      render_transcript(pdf)
      render_footer(pdf)

      pdf.render
    end

    def filename
      "transcription-#{@transcript.created_at.in_time_zone('Europe/Paris').strftime('%Y-%m-%d')}-" \
        "#{@transcript.title.parameterize.first(60).presence || @transcript.id}.pdf"
    end

    private

    def render_header(pdf)
      pdf.text "Transcription de vidéo", size: 9, color: COLOR_MUTED
      pdf.text clean(@transcript.title), size: 17, style: :bold, color: COLOR_TEXT
      pdf.move_down 2
      pdf.text clean(@transcript.source_citation), size: 9, color: COLOR_MUTED if @transcript.source_citation.present?
      details = [
        (@transcript.duration_seconds ? "Durée #{VideoTranscript.timecode(@transcript.duration_seconds)}" : nil),
        "langue : #{@transcript.language_label.downcase}",
        "transcrite le #{(@transcript.transcribed_at || @transcript.created_at).in_time_zone('Europe/Paris').strftime('%d/%m/%Y')}"
      ].compact.join(" - ")
      pdf.text details, size: 9, color: COLOR_MUTED
      names = @transcript.speakers.filter_map { |s| @transcript.speaker_names[s].presence }.uniq
      pdf.text "Intervenants : #{clean(names.join(', '))}", size: 9, color: COLOR_MUTED if names.any?
      pdf.move_down 4
      pdf.text "Transcription automatique, susceptible de contenir des erreurs ; résumé généré par IA, en français.",
               size: 8, style: :italic, color: COLOR_MUTED
      rule(pdf)
    end

    def render_summary(pdf)
      summary = @transcript.summary
      heading(pdf, "Résumé")
      paragraphs(pdf, summary["overview"])

      chapters = Array(summary["chapters"])
      if chapters.any?
        subheading(pdf, "Déroulé")
        chapters.each do |chapter|
          pdf.indent(10) do
            pdf.text "<color rgb='#{COLOR_MUTED}'>#{escape(chapter['start'])}</color>  <b>#{escape(chapter['title'])}</b>",
                     size: 10, color: COLOR_TEXT, inline_format: true
            pdf.text clean(chapter["summary"]), size: 9.5, color: COLOR_TEXT if chapter["summary"].present?
            pdf.move_down 3
          end
        end
      end

      bullets(pdf, "Points clés", summary["key_points"])
      claims = Array(summary["claims"]).map do |claim|
        who = claim["speaker"].present? ? "#{@transcript.speaker_label(claim['speaker'])} : " : ""
        "[#{claim['timecode']}] #{who}#{claim['statement']}"
      end
      bullets(pdf, "Affirmations notables", claims)
      rule(pdf)
    end

    def render_transcript(pdf)
      heading(pdf, "Transcription")
      if @transcript.transcript.blank?
        pdf.text "Aucune parole détectée dans la vidéo.", size: 10, color: COLOR_MUTED
        return
      end

      @transcript.turns.each do |turn|
        pdf.text "<b>#{escape(@transcript.speaker_label(turn['speaker']))}</b>  " \
                 "<color rgb='#{COLOR_MUTED}'>#{VideoTranscript.timecode(turn['start'])}</color>",
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

    def subheading(pdf, text)
      pdf.move_down 4
      pdf.text text, size: 10, style: :bold, color: COLOR_ACCENT
      pdf.move_down 2
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

      subheading(pdf, title)
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

    # DejaVu couvre le latin, le cyrillique et le grec, pas les emojis ni les pictogrammes :
    # on retire ce qui sort du plan multilingue de base (et les caracteres de controle).
    def clean(text)
      text.to_s.scrub("").gsub(/[^\u0009\u000A -￿]|[︀-️‍]/, "").strip
    end

    # Texte passe a inline_format : les chevrons ne doivent pas devenir des balises.
    def escape(text)
      ERB::Util.html_escape(clean(text))
    end
  end
end
