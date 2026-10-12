module Letters
  # Contenu d'une lettre : un document Tiptap (JSON ProseMirror) restreint a ce que
  # l'editeur de la page Courrier sait produire (paragraphes alignes, listes,
  # gras / italique / souligne, retours a la ligne). Service pur.
  #
  # - `sanitize` nettoie le JSON recu du navigateur (noeuds, marques et attributs
  #   inconnus ecartes) : c'est lui qu'on stocke dans `letters.body`.
  # - `blocks` l'aplatit en blocs simples que les rendus PDF et DOCX parcourent sans
  #   connaitre Tiptap : { type: "paragraph" | "list_item", align:, runs:, level:, marker: }.
  # - `from_text` / `to_text` passent du texte brut au document et inversement (Alfred,
  #   corpus RAG, rake tasks).
  module Body
    ALIGNMENTS = %w[left center right justify].freeze
    MARKS = %w[bold italic underline].freeze
    LIST_TYPES = %w[bulletList orderedList].freeze

    module_function

    def empty_doc
      { "type" => "doc", "content" => [] }
    end

    def sanitize(doc)
      doc = doc.to_unsafe_h if doc.respond_to?(:to_unsafe_h)
      doc = JSON.parse(doc) if doc.is_a?(String) && doc.present?
      return empty_doc unless doc.is_a?(Hash)

      doc = doc.deep_stringify_keys
      { "type" => "doc", "content" => Array(doc["content"]).filter_map { |node| sanitize_block(node) } }
    rescue JSON::ParserError
      empty_doc
    end

    def from_text(text)
      paragraphs = text.to_s.gsub("\r\n", "\n").strip.split(/\n{2,}/)
      content = paragraphs.map do |paragraph|
        lines = paragraph.split("\n")
        inline = lines.each_with_index.flat_map do |line, index|
          nodes = line.empty? ? [] : [{ "type" => "text", "text" => line }]
          index.zero? ? nodes : [{ "type" => "hardBreak" }] + nodes
        end
        { "type" => "paragraph", "content" => inline }
      end
      { "type" => "doc", "content" => content }
    end

    def to_text(doc)
      blocks(doc).map do |block|
        text = block[:runs].sum("") { |run| run[:text] }
        block[:type] == "list_item" ? "#{'  ' * block[:level]}#{block[:marker]} #{text}" : text
      end.join("\n\n").gsub(/\n{3,}/, "\n\n").strip
    end

    def blank?(doc)
      to_text(doc).blank?
    end

    def blocks(doc)
      doc = sanitize(doc)
      doc["content"].flat_map { |node| flatten(node, level: 0) }
    end

    # -- Aplatissement -------------------------------------------------------------

    def flatten(node, level:)
      case node["type"]
      when "paragraph"
        [{ type: "paragraph", align: node.dig("attrs", "textAlign") || "left", runs: runs(node), level: 0 }]
      when *LIST_TYPES
        ordered = node["type"] == "orderedList"
        start = ordered ? node.dig("attrs", "start").to_i.clamp(1, 10_000) : 1
        Array(node["content"]).each_with_index.flat_map do |item, index|
          list_item(item, level: level, marker: ordered ? "#{start + index}." : "•")
        end
      else
        []
      end
    end

    # Le premier paragraphe d'un element porte la puce, les suivants sont des
    # paragraphes en retrait au meme niveau, les listes imbriquees descendent d'un cran.
    def list_item(item, level:, marker:)
      first = true
      Array(item["content"]).flat_map do |child|
        if LIST_TYPES.include?(child["type"])
          flatten(child, level: level + 1)
        else
          block = { type: "list_item", align: child.dig("attrs", "textAlign") || "left", runs: runs(child),
                    level: level, marker: first ? marker : nil }
          first = false
          [block]
        end
      end
    end

    def runs(node)
      Array(node["content"]).map do |inline|
        if inline["type"] == "hardBreak"
          { text: "\n", bold: false, italic: false, underline: false }
        else
          marks = Array(inline["marks"]).map { |mark| mark["type"] }
          { text: inline["text"].to_s, bold: marks.include?("bold"), italic: marks.include?("italic"),
            underline: marks.include?("underline") }
        end
      end
    end

    # -- Nettoyage -----------------------------------------------------------------

    def sanitize_block(node)
      return nil unless node.is_a?(Hash)

      case node["type"]
      when "paragraph"
        paragraph(node["attrs"], sanitize_inline(node["content"]))
      when *LIST_TYPES
        items = Array(node["content"]).filter_map { |item| sanitize_list_item(item) }
        return nil if items.empty?

        list = { "type" => node["type"], "content" => items }
        list["attrs"] = { "start" => node.dig("attrs", "start").to_i.clamp(1, 10_000) } if node["type"] == "orderedList"
        list
      else
        # Noeud inconnu (titre colle depuis ailleurs...) : on garde son texte.
        inline = sanitize_inline(collect_inline(node))
        inline.empty? ? nil : paragraph(nil, inline)
      end
    end

    def sanitize_list_item(item)
      return nil unless item.is_a?(Hash) && item["type"] == "listItem"

      content = Array(item["content"]).filter_map { |child| sanitize_block(child) }
      content.unshift(paragraph(nil, [])) if content.empty? || content.first["type"] != "paragraph"
      { "type" => "listItem", "content" => content }
    end

    def paragraph(attrs, inline)
      node = { "type" => "paragraph" }
      align = attrs.is_a?(Hash) ? attrs["textAlign"] : nil
      node["attrs"] = { "textAlign" => align } if ALIGNMENTS.include?(align) && align != "left"
      node["content"] = inline if inline.any?
      node
    end

    def sanitize_inline(nodes)
      Array(nodes).filter_map do |inline|
        next unless inline.is_a?(Hash)

        case inline["type"]
        when "hardBreak" then { "type" => "hardBreak" }
        when "text"
          text = inline["text"].to_s
          next if text.empty?

          marks = Array(inline["marks"]).filter_map { |mark| mark["type"] if mark.is_a?(Hash) && MARKS.include?(mark["type"]) }.uniq
          node = { "type" => "text", "text" => text }
          node["marks"] = marks.map { |type| { "type" => type } } if marks.any?
          node
        end
      end
    end

    def collect_inline(node)
      Array(node["content"]).flat_map do |child|
        next [] unless child.is_a?(Hash)

        %w[text hardBreak].include?(child["type"]) ? [child] : collect_inline(child)
      end
    end
  end
end
