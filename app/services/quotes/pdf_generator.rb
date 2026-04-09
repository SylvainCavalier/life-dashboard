module Quotes
  class PdfGenerator
    FONT_SIZE_NORMAL = 9
    FONT_SIZE_SMALL = 8
    FONT_SIZE_TITLE = 18
    FONT_SIZE_SECTION = 11
    COLOR_PRIMARY = "2D3748"
    COLOR_ACCENT = "4F46E5"
    COLOR_LIGHT = "F7FAFC"
    COLOR_MUTED = "718096"

    def initialize(quote)
      @quote = quote
      @company = quote.company
    end

    def generate
      pdf = Prawn::Document.new(page_size: "A4", margin: [40, 40, 50, 40])

      render_header(pdf)
      render_parties(pdf)
      render_subject(pdf)
      render_items_table(pdf)
      render_totals(pdf)
      render_conditions(pdf)
      render_footer(pdf)

      pdf.render
    end

    private

    def render_header(pdf)
      # Company name as title
      pdf.font_size(FONT_SIZE_TITLE) do
        pdf.text @company.name, color: COLOR_PRIMARY, style: :bold
      end
      if @company.legal_form.present?
        pdf.text @company.legal_form.upcase, size: FONT_SIZE_SMALL, color: COLOR_MUTED
      end
      pdf.move_down 5

      # Quote number and dates - right aligned
      pdf.float do
        pdf.bounding_box([pdf.bounds.width - 200, pdf.cursor + 50], width: 200) do
          pdf.text "DEVIS", size: 16, style: :bold, color: COLOR_ACCENT, align: :right
          pdf.text @quote.number, size: FONT_SIZE_SECTION, color: COLOR_PRIMARY, align: :right
          pdf.move_down 5
          pdf.text "Date : #{format_date(@quote.issue_date)}", size: FONT_SIZE_SMALL, align: :right
          if @quote.validity_date
            pdf.text "Valide jusqu'au : #{format_date(@quote.validity_date)}", size: FONT_SIZE_SMALL, align: :right
          end
          if @quote.status != "pending"
            pdf.move_down 5
            status_text = @quote.status == "accepted" ? "ACCEPTE" : "REFUSE"
            pdf.text status_text, size: FONT_SIZE_SECTION, style: :bold,
                     color: @quote.status == "accepted" ? "16A34A" : "DC2626", align: :right
          end
        end
      end

      pdf.move_down 30
    end

    def render_parties(pdf)
      # Two columns: emetteur (left) and client (right)
      y_position = pdf.cursor

      # Emetteur
      pdf.bounding_box([0, y_position], width: 240) do
        pdf.text "EMETTEUR", size: FONT_SIZE_SMALL, style: :bold, color: COLOR_ACCENT
        pdf.move_down 4
        pdf.text @company.name, size: FONT_SIZE_NORMAL, style: :bold
        address_lines = build_address(@company)
        address_lines.each { |line| pdf.text line, size: FONT_SIZE_SMALL }
        pdf.text @company.email, size: FONT_SIZE_SMALL if @company.email.present?
        pdf.text @company.phone, size: FONT_SIZE_SMALL if @company.phone.present?
        pdf.move_down 3
        pdf.text "SIRET : #{@company.siret}", size: FONT_SIZE_SMALL if @company.siret.present?
        pdf.text "TVA : #{@company.vat_number}", size: FONT_SIZE_SMALL if @company.vat_number.present?
      end

      # Client
      pdf.bounding_box([280, y_position], width: 240) do
        pdf.text "CLIENT", size: FONT_SIZE_SMALL, style: :bold, color: COLOR_ACCENT
        pdf.move_down 4
        pdf.text @quote.client_name, size: FONT_SIZE_NORMAL, style: :bold
        client_address_lines = build_client_address
        client_address_lines.each { |line| pdf.text line, size: FONT_SIZE_SMALL }
        pdf.text @quote.client_email, size: FONT_SIZE_SMALL if @quote.client_email.present?
        pdf.text @quote.client_phone, size: FONT_SIZE_SMALL if @quote.client_phone.present?
        pdf.move_down 3
        pdf.text "SIRET : #{@quote.client_siret}", size: FONT_SIZE_SMALL if @quote.client_siret.present?
        pdf.text "TVA : #{@quote.client_vat_number}", size: FONT_SIZE_SMALL if @quote.client_vat_number.present?
      end

      pdf.move_down 30
    end

    def render_subject(pdf)
      if @quote.subject.present?
        pdf.text "Objet : #{@quote.subject}", size: FONT_SIZE_NORMAL, style: :bold, color: COLOR_PRIMARY
        pdf.move_down 15
      end
    end

    def render_items_table(pdf)
      has_discounts = @quote.quote_items.any? { |i| i.discount_type.present? && i.discount_type != "none" }

      if has_discounts
        header = ["Description", "Qte", "Unite", "Prix unit. HT", "Remise", "Total HT"]
        rows = @quote.quote_items.order(:position).map do |item|
          [
            item.description,
            format_number(item.quantity),
            item.unit || "unite",
            format_currency(item.unit_price),
            format_discount(item),
            format_currency(item.total_ht)
          ]
        end
      else
        header = ["Description", "Qte", "Unite", "Prix unit. HT", "Total HT"]
        rows = @quote.quote_items.order(:position).map do |item|
          [
            item.description,
            format_number(item.quantity),
            item.unit || "unite",
            format_currency(item.unit_price),
            format_currency(item.total_ht)
          ]
        end
      end

      table_data = [header] + rows
      col_count = header.length

      pdf.table(table_data, width: pdf.bounds.width, cell_style: { size: FONT_SIZE_SMALL, padding: [6, 8] }) do |t|
        t.row(0).font_style = :bold
        t.row(0).background_color = COLOR_ACCENT
        t.row(0).text_color = "FFFFFF"

        (1..rows.length).each do |i|
          t.row(i).background_color = i.even? ? COLOR_LIGHT : "FFFFFF"
        end

        if has_discounts
          t.column(0).width = pdf.bounds.width * 0.32
          t.column(1).width = pdf.bounds.width * 0.08
          t.column(2).width = pdf.bounds.width * 0.10
          t.column(3).width = pdf.bounds.width * 0.17
          t.column(4).width = pdf.bounds.width * 0.15
          t.column(5).width = pdf.bounds.width * 0.18
        else
          t.column(0).width = pdf.bounds.width * 0.40
          t.column(1).width = pdf.bounds.width * 0.10
          t.column(2).width = pdf.bounds.width * 0.12
          t.column(3).width = pdf.bounds.width * 0.19
          t.column(4).width = pdf.bounds.width * 0.19
        end

        t.column(1).align = :center
        t.column(2).align = :center
        (3...col_count).each { |c| t.column(c).align = :right }
      end

      pdf.move_down 15
    end

    def render_totals(pdf)
      totals_x = pdf.bounds.width - 200

      pdf.bounding_box([totals_x, pdf.cursor], width: 200) do
        row_total(pdf, "Total HT", format_currency(@quote.total_ht))
        if tva_exempt?
          row_total(pdf, "TVA", "Exoneree")
        else
          row_total(pdf, "TVA (#{format_number(@quote.tva_rate)}%)", format_currency(@quote.total_tva))
        end
        pdf.stroke_horizontal_rule
        pdf.move_down 5
        row_total(pdf, "Total TTC", format_currency(@quote.total_ttc), bold: true, size: FONT_SIZE_SECTION)
      end

      if tva_exempt?
        pdf.move_down 5
        pdf.text "TVA non applicable, art. 293 B du CGI", size: FONT_SIZE_SMALL, style: :italic, color: COLOR_MUTED
      end

      pdf.move_down 20
    end

    def render_conditions(pdf)
      if @quote.conditions.present?
        pdf.text "Conditions", size: FONT_SIZE_SMALL, style: :bold, color: COLOR_PRIMARY
        pdf.move_down 3
        pdf.text @quote.conditions, size: FONT_SIZE_SMALL, color: COLOR_MUTED
        pdf.move_down 10
      end

      if @quote.notes.present?
        pdf.text "Notes", size: FONT_SIZE_SMALL, style: :bold, color: COLOR_PRIMARY
        pdf.move_down 3
        pdf.text @quote.notes, size: FONT_SIZE_SMALL, color: COLOR_MUTED
        pdf.move_down 10
      end

      # Signature / acceptance line
      pdf.move_down 20
      pdf.text "Bon pour accord", size: FONT_SIZE_NORMAL, style: :bold, color: COLOR_PRIMARY
      pdf.move_down 5
      pdf.text "Date et signature du client :", size: FONT_SIZE_SMALL, color: COLOR_MUTED
      pdf.move_down 40
      pdf.stroke_horizontal_rule
    end

    def render_footer(pdf)
      pdf.repeat(:all) do
        pdf.bounding_box([0, 25], width: pdf.bounds.width, height: 20) do
          parts = [@company.name]
          parts << @company.legal_form.upcase if @company.legal_form.present?
          parts << "Capital #{format_currency(@company.capital)}" if @company.capital.present? && @company.capital.positive?
          parts << "RCS #{@company.rcs}" if @company.rcs.present?
          parts << "SIRET: #{@company.siret}" if @company.siret.present?
          parts << "TVA: #{@company.vat_number}" if @company.vat_number.present?
          pdf.text parts.join(" | "), size: 7, color: COLOR_MUTED, align: :center
        end
      end
    end

    # Helpers

    def row_total(pdf, label, value, bold: false, size: FONT_SIZE_NORMAL)
      pdf.text_box label, at: [0, pdf.cursor], width: 120, size: size,
                   style: bold ? :bold : :normal, color: COLOR_PRIMARY
      pdf.text_box value, at: [120, pdf.cursor], width: 80, size: size,
                   style: bold ? :bold : :normal, align: :right, color: COLOR_PRIMARY
      pdf.move_down size + 4
    end

    def build_address(company)
      lines = []
      lines << company.address_line1 if company.address_line1.present?
      lines << company.address_line2 if company.address_line2.present?
      city_line = [company.postal_code, company.city].compact_blank.join(" ")
      lines << city_line if city_line.present?
      lines << company.country if company.country.present? && company.country != "France"
      lines
    end

    def build_client_address
      lines = []
      lines << @quote.client_address_line1 if @quote.client_address_line1.present?
      lines << @quote.client_address_line2 if @quote.client_address_line2.present?
      city_line = [@quote.client_postal_code, @quote.client_city].compact_blank.join(" ")
      lines << city_line if city_line.present?
      lines << @quote.client_country if @quote.client_country.present? && @quote.client_country != "France"
      lines
    end

    def format_discount(item)
      return "-" if item.discount_type.blank? || item.discount_type == "none"

      case item.discount_type
      when "percent"
        "-#{format_number(item.discount_value)}%"
      when "amount"
        "-#{format_currency(item.discount_value)}"
      else
        "-"
      end
    end

    def tva_exempt?
      @quote.tva_rate.nil? || @quote.tva_rate.zero?
    end

    def format_date(date)
      return "" unless date
      I18n.l(date, format: :long)
    rescue I18n::MissingTranslationData
      date.strftime("%d/%m/%Y")
    end

    def format_currency(amount)
      return "0,00 EUR" unless amount
      "%.2f EUR" % amount
    end

    def format_number(num)
      return "0" unless num
      num == num.to_i ? num.to_i.to_s : ("%.2f" % num)
    end
  end
end
