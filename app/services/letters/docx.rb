require "zip"

module Letters
  # Lettre en DOCX (WordprocessingML ecrit a la main puis zippe avec rubyzip), pour
  # la retoucher dans Word ou LibreOffice. Mise en page en flux, sans cadres
  # positionnes : en mode compact, expediteur et destinataire sont les deux colonnes
  # d'un tableau sans bordure ; en enveloppe a fenetre, le destinataire est decale a
  # droite et descendu jusqu'a la fenetre selon le nombre de lignes de l'expediteur. Police Arial,
  # presente partout (DejaVu, celle du PDF, est rarement installee).
  class Docx
    include Layout

    TWIPS_PER_MM = 56.6929
    EMU_PER_MM = 36_000
    MM_PER_POINT = 0.3528
    LINE_MM = FONT_SIZE * LINE_HEIGHT * MM_PER_POINT # hauteur d'une ligne de texte, en mm
    PNG_SIGNATURE = "\x89PNG\r\n\x1A\n".b

    NAMESPACES = 'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" ' \
                 'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" ' \
                 'xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" ' \
                 'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" ' \
                 'xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture"'

    def initialize(letter)
      @letter = letter
      @signature = png(letter.signature_data)
    end

    def generate
      buffer = Zip::OutputStream.write_buffer(StringIO.new) do |zip|
        files.each do |name, content|
          zip.put_next_entry(name)
          zip.write(content)
        end
      end
      buffer.string
    end

    private

    def files
      files = {
        "[Content_Types].xml" => content_types,
        "_rels/.rels" => root_rels,
        "word/_rels/document.xml.rels" => document_rels,
        "word/styles.xml" => styles,
        "word/document.xml" => document
      }
      files["word/footer1.xml"] = footer if footer?
      files["word/media/signature.png"] = @signature[:data] if @signature
      files
    end

    # -- Corps -----------------------------------------------------------------------

    def document
      <<~XML
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:document #{NAMESPACES}><w:body>#{addresses}#{heading}#{body}#{signature}#{section}</w:body></w:document>
      XML
    end

    def addresses
      return window_addresses if @letter.window_envelope

      @date_spacing = 0
      return "" if @letter.sender.blank? && @letter.recipient.blank?

      @date_spacing = BLOCK_GAP
      left = twips(RECIPIENT_LEFT - MARGIN_SIDE)
      right = twips(CONTENT_WIDTH) - left
      cell = lambda do |text, width|
        content = text.present? ? text_runs(text) : ""
        %(<w:tc><w:tcPr><w:tcW w:w="#{width}" w:type="dxa"/></w:tcPr>#{paragraph(content, spacing_after: 0)}</w:tc>)
      end
      <<~XML.squish
        <w:tbl><w:tblPr><w:tblW w:w="#{left + right}" w:type="dxa"/><w:tblLayout w:type="fixed"/>
          <w:tblCellMar><w:left w:w="0" w:type="dxa"/><w:right w:w="0" w:type="dxa"/></w:tblCellMar></w:tblPr>
          <w:tblGrid><w:gridCol w:w="#{left}"/><w:gridCol w:w="#{right}"/></w:tblGrid>
          <w:tr>#{cell.call(@letter.sender, left)}#{cell.call(@letter.recipient, right)}</w:tr></w:tbl>
      XML
    end

    def window_addresses
      xml = +""
      used_mm = 0.0
      if @letter.sender.present?
        xml << paragraph(text_runs(@letter.sender), spacing_after: 0)
        used_mm += lines(@letter.sender) * LINE_MM
      end
      if @letter.recipient.present?
        before = [WINDOW_RECIPIENT_TOP - MARGIN_TOP - used_mm, BLOCK_GAP].max
        xml << paragraph(text_runs(@letter.recipient), indent: RECIPIENT_LEFT - MARGIN_SIDE, spacing_before: before, spacing_after: 0)
        used_mm += before + (lines(@letter.recipient) * LINE_MM)
      end
      @date_spacing = [WINDOW_DATE_TOP - MARGIN_TOP - used_mm, used_mm.zero? ? 0 : BLOCK_GAP].max
      xml
    end

    def heading
      xml = +""
      if @letter.place_and_date.present?
        xml << paragraph(text_runs(@letter.place_and_date), align: "right", spacing_before: @date_spacing, spacing_after: 0)
      end
      rows = []
      rows << run(@letter.mention, bold: true) if @letter.mention.present?
      rows << run("Réf. : #{@letter.reference}") if @letter.reference.present?
      rows << run("Objet : #{@letter.subject}", bold: true) if @letter.subject.present?
      rows.each_with_index do |runs, index|
        xml << paragraph(runs, spacing_before: index.zero? ? BLOCK_GAP : 0, spacing_after: index == rows.size - 1 ? BLOCK_GAP : 0)
      end
      xml
    end

    def body
      Body.blocks(@letter.body).map do |block|
        runs = block[:runs].map { |r| run(r[:text], bold: r[:bold], italic: r[:italic], underline: r[:underline]) }.join
        if block[:type] == "list_item"
          indent = (block[:level] + 1) * LIST_INDENT
          marker = block[:marker] ? "#{run(block[:marker])}<w:r><w:tab/></w:r>" : ""
          paragraph(marker + runs, align: block[:align], indent: indent, hanging: block[:marker] ? LIST_INDENT : 0,
                                   spacing_after: LIST_ITEM_SPACING * MM_PER_POINT)
        else
          paragraph(runs, align: block[:align])
        end
      end.join
    end

    def signature
      return "" if @signature.nil? && @letter.signatory.blank?

      indent = SIGNATURE_LEFT - MARGIN_SIDE
      xml = +""
      xml << paragraph(image_run, indent: indent, spacing_before: BLOCK_GAP, spacing_after: 2, keep_next: true) if @signature
      if @letter.signatory.present?
        xml << paragraph(text_runs(@letter.signatory), indent: indent, spacing_before: @signature ? 0 : BLOCK_GAP, spacing_after: 0)
      end
      xml
    end

    def section
      footer_ref = footer? ? '<w:footerReference w:type="default" r:id="rIdFooter"/>' : ""
      <<~XML.squish
        <w:sectPr>#{footer_ref}
          <w:pgSz w:w="#{twips(PAGE_WIDTH)}" w:h="#{twips(PAGE_HEIGHT)}"/>
          <w:pgMar w:top="#{twips(MARGIN_TOP)}" w:right="#{twips(MARGIN_SIDE)}" w:bottom="#{twips(MARGIN_BOTTOM)}"
                   w:left="#{twips(MARGIN_SIDE)}" w:header="#{twips(8)}" w:footer="#{twips(8)}" w:gutter="0"/>
        </w:sectPr>
      XML
    end

    def footer
      <<~XML
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:ftr #{NAMESPACES}><w:p><w:pPr><w:pBdr><w:top w:val="single" w:sz="4" w:space="4" w:color="D1D5DB"/></w:pBdr>
        <w:spacing w:after="0" w:line="240" w:lineRule="auto"/><w:jc w:val="center"/></w:pPr>#{text_runs(@letter.footer, size: SMALL_FONT_SIZE, color: '6B7280')}</w:p></w:ftr>
      XML
    end

    def footer? = @letter.footer.present?

    # -- Briques XML ---------------------------------------------------------------------

    def paragraph(runs, align: "left", indent: 0, hanging: 0, spacing_before: nil, spacing_after: nil, keep_next: false)
      props = +""
      props << "<w:keepNext/>" if keep_next
      if spacing_before || spacing_after
        attrs = []
        attrs << %(w:before="#{(spacing_before.to_f * TWIPS_PER_MM).round}") if spacing_before
        attrs << %(w:after="#{(spacing_after.to_f * TWIPS_PER_MM).round}") if spacing_after
        props << "<w:spacing #{attrs.join(' ')}/>"
      end
      props << %(<w:ind w:left="#{twips(indent)}" w:hanging="#{twips(hanging)}"/>) if indent.positive?
      jc = { "center" => "center", "right" => "right", "justify" => "both" }[align]
      props << %(<w:jc w:val="#{jc}"/>) if jc
      "<w:p>#{props.present? ? "<w:pPr>#{props}</w:pPr>" : ''}#{runs}</w:p>"
    end

    # Texte multiligne : un seul paragraphe, des sauts de ligne entre les lignes.
    def text_runs(text, **options)
      run(clean(text).strip, **options)
    end

    def run(text, bold: false, italic: false, underline: false, size: nil, color: nil)
      props = +""
      props << "<w:b/>" if bold
      props << "<w:i/>" if italic
      props << '<w:u w:val="single"/>' if underline
      props << %(<w:color w:val="#{color}"/>) if color
      props << %(<w:sz w:val="#{(size * 2).round}"/>) if size
      content = clean(text).split("\n", -1).map { |part| %(<w:t xml:space="preserve">#{xml_escape(part)}</w:t>) }.join("<w:br/>")
      "<w:r>#{props.present? ? "<w:rPr>#{props}</w:rPr>" : ''}#{content}</w:r>"
    end

    def image_run
      width, height = fit(@signature[:width], @signature[:height])
      cx = (width * EMU_PER_MM).round
      cy = (height * EMU_PER_MM).round
      <<~XML.squish
        <w:r><w:drawing><wp:inline distT="0" distB="0" distL="0" distR="0">
          <wp:extent cx="#{cx}" cy="#{cy}"/><wp:docPr id="1" name="Signature"/>
          <a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">
            <pic:pic><pic:nvPicPr><pic:cNvPr id="1" name="signature.png"/><pic:cNvPicPr/></pic:nvPicPr>
              <pic:blipFill><a:blip r:embed="rIdSignature"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill>
              <pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="#{cx}" cy="#{cy}"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr>
            </pic:pic>
          </a:graphicData></a:graphic>
        </wp:inline></w:drawing></w:r>
      XML
    end

    # -- Paquet --------------------------------------------------------------------------

    def content_types
      overrides = +'<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
      overrides << '<Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>'
      overrides << '<Override PartName="/word/footer1.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.footer+xml"/>' if footer?
      <<~XML
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
        <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
        <Default Extension="xml" ContentType="application/xml"/><Default Extension="png" ContentType="image/png"/>#{overrides}</Types>
      XML
    end

    def root_rels
      <<~XML
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>
      XML
    end

    def document_rels
      rels = +'<Relationship Id="rIdStyles" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
      rels << '<Relationship Id="rIdFooter" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer" Target="footer1.xml"/>' if footer?
      rels << '<Relationship Id="rIdSignature" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/signature.png"/>' if @signature
      <<~XML
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">#{rels}</Relationships>
      XML
    end

    def styles
      <<~XML
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:styles #{NAMESPACES}><w:docDefaults>
        <w:rPrDefault><w:rPr><w:rFonts w:ascii="Arial" w:hAnsi="Arial" w:eastAsia="Arial" w:cs="Arial"/>
        <w:color w:val="111827"/><w:sz w:val="#{FONT_SIZE * 2}"/><w:szCs w:val="#{FONT_SIZE * 2}"/><w:lang w:val="fr-FR"/></w:rPr></w:rPrDefault>
        <w:pPrDefault><w:pPr><w:spacing w:before="0" w:after="#{PARAGRAPH_SPACING * 20}" w:line="#{(LINE_HEIGHT * 240).round}" w:lineRule="auto"/></w:pPr></w:pPrDefault>
        </w:docDefaults><w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/></w:style></w:styles>
      XML
    end

    # -- Outils ----------------------------------------------------------------------

    def png(data)
      return nil if data.blank? || !data.b.start_with?(PNG_SIGNATURE)

      width, height = data.b[16, 8].unpack("NN")
      return nil unless width.to_i.positive? && height.to_i.positive?

      { data: data, width: width, height: height }
    end

    def fit(width, height)
      scale = [SIGNATURE_MAX_WIDTH.to_f / width, SIGNATURE_MAX_HEIGHT.to_f / height].min
      [width * scale, height * scale]
    end

    def lines(text) = clean(text).strip.count("\n") + 1
    def twips(mm) = (mm * TWIPS_PER_MM).round

    # Caracteres interdits en XML 1.0 (controles) retires.
    def clean(text)
      text.to_s.scrub("").gsub("\r\n", "\n").gsub(/[^\u0009\u000A\u000D -퟿-�\u{10000}-\u{10FFFF}]/, "")
    end

    def xml_escape(text)
      text.encode(xml: :text)
    end
  end
end
