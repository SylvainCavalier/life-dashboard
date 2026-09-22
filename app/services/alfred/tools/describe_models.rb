module Alfred
  module Tools
    class DescribeModels < Base
      def self.definition
        {
          name: "describe_models",
          description: "Colonnes (nom, type, valeurs autorisees quand elles sont connues) d'un ou plusieurs modeles, et ce qui y est " \
                       "modifiable. A appeler avant un query_records ou un propose_write sur un modele dont on ne connait pas les champs.",
          input_schema: {
            type: "object",
            properties: { models: { type: "array", items: { type: "string", enum: DataAccess::READABLE.keys } } },
            required: ["models"]
          }
        }
      end

      def self.step_label(input) = "Structure : #{Array(input['models']).join(', ')}"

      def call(input)
        { models: Array(input["models"]).first(8).map { |name| describe(name) } }
      end

      private

      def describe(name)
        klass = DataAccess.readable_class(name)
        readable = DataAccess.readable_fields(name)
        {
          model: name,
          columns: klass.columns.select { |c| readable.include?(c.name) }.map { |c| column_info(klass, c) },
          writable: DataAccess::WRITABLE.key?(name) ? { create: DataAccess.writable_fields(name, :create), update: DataAccess.writable_fields(name, :update) } : false
        }
      end

      def column_info(klass, column)
        info = { name: column.name, type: column.type }
        values = allowed_values(klass, column.name)
        info[:values] = values if values
        info
      end

      # Valeurs autorisees lues sur les validations d'inclusion statiques.
      def allowed_values(klass, attribute)
        validator = klass.validators_on(attribute).find { |v| v.is_a?(ActiveModel::Validations::InclusionValidator) }
        values = validator&.options&.dig(:in)
        values.is_a?(Array) ? values : nil
      end
    end
  end
end
