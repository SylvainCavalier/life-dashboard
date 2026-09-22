module Alfred
  module Corpus
    # Transforme un enregistrement en texte lisible (« champ : valeur »), la forme
    # sous laquelle il est decoupe puis vectorise. Service pur, sans ecriture.
    class RecordRenderer
      MAX_CHILDREN = 60

      def initialize(record, config: Corpus.config_for(record))
        @record = record
        @config = config
      end

      def label
        @config[:label].call(@record).to_s.squish.presence || "#{@config[:title]} ##{@record.id}"
      end

      def source_date
        column = @config[:date] or return nil
        @record.public_send(column)&.to_date
      end

      def text
        lines = ["#{@config[:title]} : #{label}"]
        lines.concat(attribute_lines(@record, except: Array(@config[:except])))
        (@config[:children] || {}).each do |association, columns|
          lines.concat(children_lines(association, columns))
        end
        lines.join("\n")
      end

      private

      def attribute_lines(record, except: [], only: nil)
        klass = record.class
        skipped = Corpus::IGNORED_COLUMNS + except + klass.encrypted_attributes.to_a.map(&:to_s)
        columns = (only || klass.column_names) - skipped
        columns.filter_map do |column|
          value = format_value(record.public_send(column))
          "#{klass.human_attribute_name(column)} : #{value}" if value
        end
      end

      def children_lines(association, columns)
        children = Array(@record.public_send(association)).first(MAX_CHILDREN)
        return [] if children.empty?

        title = children.first.class.model_name.human(count: 2)
        ["#{title} :"] + children.map do |child|
          "- " + attribute_lines(child, only: columns).join(" ; ")
        end
      end

      def format_value(value)
        case value
        when nil, "" then nil
        when true then "oui"
        when false then "non"
        when Date then value.strftime("%d/%m/%Y")
        when Time, DateTime, ActiveSupport::TimeWithZone then value.in_time_zone("Paris").strftime("%d/%m/%Y %H:%M")
        when BigDecimal then value.to_s("F")
        when Hash, Array then value.empty? ? nil : value.to_json.truncate(4000)
        else value.to_s.strip.presence
        end
      end
    end
  end
end
