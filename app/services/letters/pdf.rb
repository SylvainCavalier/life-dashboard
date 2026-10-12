require "prawn/measurement_extensions"

module Letters
  # Lettre en PDF (Prawn), selon Letters::Layout. Embarque DejaVu Sans
  # (vendor/fonts/dejavu) comme VideoTranscripts::ReportPdf : accents, guillemets,
  # tirets et symboles courants passent sans la limite Windows-1252 des polices de base.
  class Pdf
    include Layout

    FONT_DIR = Rails.root.join("vendor/fonts/dejavu")
    COLOR_TEXT = "111827"
    COLOR_MUTED = "6B7280"
    COLOR_RULE = "D1D5DB"

    def initialize(letter)
      @letter = letter
    end

    def generate
      pdf = Prawn::Document.new(
        page_size: "A4",
        margin: [MARGIN_TOP.mm, MARGIN_SIDE.mm, MARGIN_BOTTOM.mm, MARGIN_SIDE.mm],
        info: { Title: clean(@letter.label), Author: clean(@letter.signatory.presence || "") }
      )
      setup_font(pdf)

      render_addresses(pdf)
      render_heading(pdf)
      render_body(pdf)
      render_signature(pdf)
      render_footer(pdf)

      pdf.render
    end

    private

    def setup_font(pdf)
      pdf.font_families.update("DejaVu" => {
        normal: FONT_DIR.join("DejaVuSans.ttf").to_s, bold: FONT_DIR.join("DejaVuSans-Bold.ttf").to_s,
        italic: FONT_DIR.join("DejaVuSans-Oblique.ttf").to_s, bold_italic: FONT_DIR.join("DejaVuSans-Bold.ttf").to_s
      })
      pdf.font "DejaVu"
      pdf.font_size FONT_SIZE
      pdf.fill_color COLOR_TEXT
      pdf.default_leading leading(FONT_SIZE)
    end

    # Expediteur en haut a gauche, destinataire dans la fenetre de l'enveloppe ;
    # le texte reprend sous le plus bas des deux, jamais au-dessus de DATE_TOP.
    def render_addresses(pdf)
      top = pdf.bounds.top
      sender_bottom = address_box(pdf, @letter.sender, x: 0, y: top, width: SENDER_WIDTH.mm)
      recipient_bottom = address_box(pdf, @letter.recipient, x: (RECIPIENT_LEFT - MARGIN_SIDE).mm,
                                                             y: top - (RECIPIENT_TOP - MARGIN_TOP).mm, width: RECIPIENT_WIDTH.mm)
      lowest = [sender_bottom, recipient_bottom, top - (DATE_TOP - MARGIN_TOP).mm].min
      pdf.move_cursor_to lowest
    end

    def address_box(pdf, text, x:, y:, width:)
      return y if text.blank?

      bottom = y
      pdf.bounding_box([x, y], width: width) do
        pdf.text clean(text)
        bottom = y - pdf.bounds.height
      end
      bottom - 8.mm
    end

    def render_heading(pdf)
      pdf.text clean(@letter.place_and_date), align: :right if @letter.place_and_date.present?
      pdf.move_down 8.mm

      pdf.text clean(@letter.mention), style: :bold if @letter.mention.present?
      pdf.text "Réf. : #{clean(@letter.reference)}" if @letter.reference.present?
      if @letter.subject.present?
        pdf.text "<b>Objet : #{escape(@letter.subject)}</b>", inline_format: true
      end
      pdf.move_down 8.mm if @letter.mention.present? || @letter.reference.present? || @letter.subject.present?
    end

    def render_body(pdf)
      Body.blocks(@letter.body).each do |block|
        html = block[:runs].map { |run| run_html(run) }.join
        if block[:type] == "list_item"
          list_item(pdf, block, html)
        elsif html.strip.empty?
          pdf.move_down line_height(FONT_SIZE)
        else
          pdf.text html, inline_format: true, align: align(block[:align])
        end
        pdf.move_down block[:type] == "list_item" ? LIST_ITEM_SPACING : PARAGRAPH_SPACING
      end
    end

    def list_item(pdf, block, html)
      pdf.indent((block[:level] * LIST_INDENT).mm) do
        pdf.float { pdf.text block[:marker] } if block[:marker]
        pdf.indent(LIST_INDENT.mm) { pdf.text html.presence || " ", inline_format: true, align: align(block[:align]) }
      end
    end

    # Bloc insecable : image de la signature puis nom du signataire, decales a droite.
    def render_signature(pdf)
      image = @letter.signature_data
      return if image.blank? && @letter.signatory.blank?

      needed = 10.mm + (image ? SIGNATURE_MAX_HEIGHT.mm : 0) + line_height(FONT_SIZE) + 2.mm
      pdf.start_new_page if pdf.cursor < needed
      pdf.move_down 8.mm

      pdf.indent((SIGNATURE_LEFT - MARGIN_SIDE).mm) do
        if image
          begin
            pdf.image StringIO.new(image), fit: [SIGNATURE_MAX_WIDTH.mm, SIGNATURE_MAX_HEIGHT.mm]
          rescue StandardError => e
            Rails.logger.warn("Letters::Pdf: signature ignoree (#{e.class})")
          end
          pdf.move_down 2.mm
        end
        pdf.text clean(@letter.signatory) if @letter.signatory.present?
      end
    end

    def render_footer(pdf)
      footer = clean(@letter.footer)
      pdf.repeat(:all) do
        next if footer.blank?

        pdf.bounding_box([0, -4.mm], width: pdf.bounds.width, height: 14.mm) do
          pdf.stroke_color COLOR_RULE
          pdf.stroke_horizontal_rule
          pdf.move_down 2.mm
          pdf.text footer, size: SMALL_FONT_SIZE, color: COLOR_MUTED, align: :center, leading: 1
        end
      end
      return if pdf.page_count < 2

      pdf.number_pages "<page> / <total>", at: [pdf.bounds.right - 30.mm, -19.mm], width: 30.mm, align: :right,
                                           size: SMALL_FONT_SIZE, color: COLOR_MUTED
    end

    def run_html(run)
      html = escape(run[:text], strip: false)
      html = "<u>#{html}</u>" if run[:underline]
      html = "<i>#{html}</i>" if run[:italic]
      html = "<b>#{html}</b>" if run[:bold]
      html
    end

    def align(value)
      { "center" => :center, "right" => :right, "justify" => :justify }.fetch(value, :left)
    end

    def leading(size) = size * (LINE_HEIGHT - 1.15)
    def line_height(size) = size * LINE_HEIGHT

    # DejaVu couvre le latin, le cyrillique et le grec, pas les emojis ni les pictogrammes :
    # on retire ce qui sort du plan multilingue de base (et les caracteres de controle).
    def clean(text, strip: true)
      text = text.to_s.scrub("").gsub("\r\n", "\n").gsub(/[^\u0009\u000A -￿]|[︀-️‍]/, "")
      strip ? text.strip : text
    end

    # Texte passe a inline_format : les chevrons ne doivent pas devenir des balises.
    # Pas d'ERB::Util.html_escape : Prawn ne decode que &amp; &lt; &gt;, une apostrophe
    # deviendrait « &#39; » dans le PDF.
    def escape(text, strip: true)
      clean(text, strip: strip).gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")
    end
  end
end
