module Alfred
  module Tools
    # Lecture structuree, en lecture seule, bornee par DataAccess::READABLE.
    class QueryRecords < Base
      DEFAULT_LIMIT = 25
      MAX_LIMIT = 100
      MAX_VALUE_CHARS = 3000
      OPERATORS = %w[eq ne gt gte lt lte in nin ilike is_null].freeze

      def self.definition
        {
          name: "query_records",
          description: "Interroge la base du dashboard (lecture seule) : filtrer, trier, compter, lister. " \
                       "`where` associe un champ a une valeur (egalite) ou a un objet d'operateurs : " \
                       "eq, ne, gt, gte, lt, lte, in, nin, ilike (motif SQL avec %), is_null (booleen). " \
                       "Exemple : {\"model\":\"Event\",\"where\":{\"start_time\":{\"gte\":\"2026-10-01\",\"lt\":\"2026-11-01\"}},\"order\":[[\"start_time\",\"asc\"]]}. " \
                       "Les mots de passe (PasswordEntry) ne sont jamais accessibles.",
          input_schema: {
            type: "object",
            properties: {
              model: { type: "string", enum: DataAccess::READABLE.keys },
              where: { type: "object", description: "Filtres, combines par ET." },
              order: { type: "array", description: "Liste de [champ, \"asc\"|\"desc\"].", items: { type: "array", items: { type: "string" } } },
              fields: { type: "array", items: { type: "string" }, description: "Champs a renvoyer (defaut : tous)." },
              limit: { type: "integer", description: "Defaut 25, max 100." },
              count_only: { type: "boolean", description: "Ne renvoyer que le nombre de lignes." }
            },
            required: ["model"]
          }
        }
      end

      def self.step_label(input) = "Consultation : #{input['model']}"

      def call(input)
        name = input["model"].to_s
        klass = DataAccess.readable_class(name)
        allowed = DataAccess.readable_fields(name)

        relation = apply_where(klass.all, klass, allowed, input["where"] || {})
        total = relation.count
        return { model: name, count: total } if input["count_only"]

        relation = apply_order(relation, allowed, input["order"] || [])
        fields = input["fields"].present? ? Array(input["fields"]).map(&:to_s) & allowed : allowed
        fields = (["id"] + fields).uniq
        limit = (input["limit"] || DEFAULT_LIMIT).to_i.clamp(1, MAX_LIMIT)

        records = relation.limit(limit).map { |record| truncate_values(DataAccess.serialize(record, fields)) }
        { model: name, total: total, returned: records.size, records: records }
      end

      private

      def apply_where(relation, klass, allowed, where)
        raise ArgumentError, "`where` doit etre un objet" unless where.is_a?(Hash)

        where.each do |field, condition|
          field = field.to_s
          raise ArgumentError, "Champ '#{field}' inconnu ou interdit sur #{klass.name}" unless allowed.include?(field)

          column = klass.arel_table[field]
          conditions = condition.is_a?(Hash) ? condition : { "eq" => condition }
          conditions.each { |operator, value| relation = relation.where(predicate(column, operator.to_s, value)) }
        end
        relation
      end

      def predicate(column, operator, value)
        case operator
        when "eq" then value.nil? ? column.eq(nil) : column.eq(value)
        when "ne" then column.not_eq(value)
        when "gt" then column.gt(value)
        when "gte" then column.gteq(value)
        when "lt" then column.lt(value)
        when "lte" then column.lteq(value)
        when "in" then column.in(Array(value))
        when "nin" then column.not_in(Array(value))
        when "ilike" then column.matches(value.to_s, nil, false)
        when "is_null" then value ? column.eq(nil) : column.not_eq(nil)
        else raise ArgumentError, "Operateur inconnu '#{operator}' (autorises : #{OPERATORS.join(', ')})"
        end
      end

      def apply_order(relation, allowed, order)
        Array(order).each do |item|
          field, direction = Array(item)
          raise ArgumentError, "Tri impossible sur '#{field}'" unless allowed.include?(field.to_s)

          relation = relation.order(field.to_s => (direction.to_s.downcase == "desc" ? :desc : :asc))
        end
        relation
      end

      def truncate_values(attributes)
        attributes.transform_values do |value|
          text = value.is_a?(Hash) || value.is_a?(Array) ? value.to_json : value
          text.is_a?(String) && text.length > MAX_VALUE_CHARS ? "#{text.first(MAX_VALUE_CHARS)}... [tronque]" : value
        end
      end
    end
  end
end
