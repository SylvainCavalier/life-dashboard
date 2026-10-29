module InsuranceImports
  # Contrat d'assurance -> brouillon de fiche (contrat, garanties, biens assures).
  # Texte : Alfred::Corpus::TextExtractor (pdf-reader, OCR Mistral pour un scan ou une
  # photo), puis un appel de chat Mistral en JSON Schema strict. Les valeurs sont ensuite
  # verifiees en Ruby (`normalize`) : dates, montants et listes fermees ne passent que
  # s'ils sont valides, le reste devient vide. Service pur : c'est le job qui ecrit.
  class Extractor
    DEFAULT_MODEL = "mistral-medium-latest".freeze
    BASE_URL = "https://api.mistral.ai".freeze
    CHAT_TIMEOUT = 180
    # Environ 30 000 tokens : un contrat et ses conditions generales tiennent en entier.
    MAX_CHARS = 120_000
    MIN_CHARS = 50

    TEXT_FIELDS = %w[
      name insurer policy_number start_date end_date renewal_date premium conditions
      claims_phone advisor_name advisor_phone advisor_email website_url document_name
    ].freeze

    SCHEMA = {
      type: "object",
      properties: TEXT_FIELDS.index_with { { type: "string" } }.merge(
        "insurance_type" => { type: "string", enum: Insurance::TYPES },
        "premium_frequency" => { type: "string", enum: Insurance::PREMIUM_FREQUENCIES },
        "document_category" => { type: "string", enum: Document::CATEGORIES["insurance"] },
        "coverages" => {
          type: "array",
          items: {
            type: "object",
            properties: {
              "name" => { type: "string" }, "included" => { type: "boolean" }, "ceiling" => { type: "string" },
              "deductible" => { type: "string" }, "conditions" => { type: "string" }
            },
            required: %w[name included ceiling deductible conditions],
            additionalProperties: false
          }
        },
        "items" => {
          type: "array",
          items: {
            type: "object",
            properties: {
              "name" => { type: "string" }, "kind" => { type: "string", enum: InsuredItem::KINDS },
              "description" => { type: "string" }, "value" => { type: "string" }
            },
            required: %w[name kind description value],
            additionalProperties: false
          }
        }
      ),
      required: TEXT_FIELDS + %w[insurance_type premium_frequency document_category coverages items],
      additionalProperties: false
    }.freeze

    PROMPT = <<~TEXT.freeze
      Tu reçois le texte d'un document d'assurance (conditions particulières, conditions générales, attestation, avis d'échéance...), extrait d'un PDF ou lu par OCR, parfois approximatif. L'assuré est Sylvain. Remplis la fiche du contrat pour son tableau de bord.
      Règle absolue : n'invente rien. Chaîne vide pour tout champ que le document ne donne pas ; liste vide s'il ne détaille aucune garantie ou aucun bien.
      - name : nom court et parlant du contrat (« Multirisque habitation - Appartement de Créteil », « Assurance auto Peugeot 208 »).
      - insurance_type : le type de contrat ; insurer : la compagnie (et le courtier entre parenthèses s'il y en a un) ; policy_number : le numéro de contrat ou de sociétaire.
      - Dates au format AAAA-MM-JJ : start_date = prise d'effet, end_date = fin seulement si le contrat a une durée ferme (vide en tacite reconduction), renewal_date = échéance principale (date anniversaire ; « échéance au 1er mars » sans année : prends l'année de prise d'effet ou celle du document).
      - premium : montant TTC de la cotisation pour une période, chiffres seuls avec un point décimal (« 254.80 ») ; premium_frequency : la période de ce montant (yearly si c'est une prime annuelle, même payée en plusieurs fois, sauf si seul le montant mensuel figure).
      - coverages : une entrée par garantie. included = true si elle est souscrite, false si le document la dit non souscrite ou exclue. ceiling = plafond d'indemnisation tel qu'écrit, deductible = franchise telle qu'écrite, conditions = les conditions et exclusions propres à cette garantie, résumées fidèlement en une à trois phrases, avec les chiffres et délais exacts. Noms usuels en français (« Dégâts des eaux », « Vol et vandalisme », « Bris de glace »...).
      - items : ce qui est assuré. Logement avec son adresse complète dans description (surface, nombre de pièces, résidence principale ou non) ; véhicule avec modèle et immatriculation ; personnes assurées ; animal ; objets de valeur déclarés. value = valeur déclarée ou capital assuré, chiffres seuls.
      - conditions : ce qui vaut pour tout le contrat, en quelques lignes : délai de déclaration d'un sinistre, conditions de résiliation, obligations de l'assuré (serrures, alarme, inoccupation), exclusions générales importantes.
      - claims_phone : numéro pour déclarer un sinistre ou joindre l'assistance ; advisor_* : conseiller ou agence ; website_url : espace client.
      - document_category : la nature du document fourni ; document_name : un nom pour le ranger (« Conditions particulières habitation 2026 »).
    TEXT

    def initialize(api_key: ENV["MISTRAL_API_KEY"], model: ENV.fetch("INSURANCE_IMPORT_MODEL", DEFAULT_MODEL),
                   text_extractor: Alfred::Corpus::TextExtractor.new(ocr: Alfred::Corpus::MistralOcr.new(api_key: api_key)))
      @api_key = api_key
      @model = model
      @text_extractor = text_extractor
    end

    # `blob` : ActiveStorage::Blob du contrat. Renvoie { draft:, extractor: }.
    def call(blob)
      raise NotConfigured, "MISTRAL_API_KEY manquante" if @api_key.blank?

      text, extractor = read(blob)
      raise Error, "Aucun texte lisible dans le document" if text.to_s.strip.length < MIN_CHARS

      { draft: self.class.normalize(extract(text.truncate(MAX_CHARS))), extractor: extractor }
    end

    # Champs bruts du modele -> brouillon { insurance:, coverages:, items:, document: }
    # dont chaque valeur passe les validations des modeles.
    def self.normalize(fields, properties: Property.all.to_a, vehicles: Vehicle.all.to_a)
      fields = fields.to_h.stringify_keys
      str = ->(key) { fields[key].to_s.strip }
      type = str.("insurance_type").presence_in(Insurance::TYPES) || "autre"
      insurance = {
        name: str.("name").presence || [Insurance::TYPE_LABELS[type], str.("insurer")].compact_blank.join(" - "),
        insurance_type: type,
        status: "active",
        insurer: str.("insurer"),
        policy_number: str.("policy_number"),
        start_date: parse_date(str.("start_date")),
        end_date: parse_date(str.("end_date")),
        renewal_date: parse_date(str.("renewal_date")),
        premium: parse_amount(str.("premium")),
        premium_frequency: str.("premium_frequency").presence_in(Insurance::PREMIUM_FREQUENCIES) || "yearly",
        conditions: str.("conditions"),
        claims_phone: str.("claims_phone"),
        advisor_name: str.("advisor_name"),
        advisor_phone: str.("advisor_phone"),
        advisor_email: str.("advisor_email").downcase.then { |email| email.match?(URI::MailTo::EMAIL_REGEXP) ? email : "" },
        website_url: normalize_url(str.("website_url"))
      }
      insurance[:end_date] = nil if insurance[:start_date] && insurance[:end_date] && insurance[:end_date] < insurance[:start_date]

      coverages = Array(fields["coverages"]).filter_map do |coverage|
        coverage = coverage.to_h.stringify_keys
        name = coverage["name"].to_s.strip
        next if name.blank?

        { name: name, included: coverage["included"] != false,
          ceiling: coverage["ceiling"].to_s.strip, deductible: coverage["deductible"].to_s.strip,
          conditions: coverage["conditions"].to_s.strip }
      end

      items = Array(fields["items"]).filter_map do |item|
        item = item.to_h.stringify_keys
        name = item["name"].to_s.strip
        next if name.blank?

        kind = item["kind"].to_s.presence_in(InsuredItem::KINDS) || "autre"
        description = item["description"].to_s.strip
        { name: name, kind: kind, description: description, value: parse_amount(item["value"].to_s),
          property_id: (guess_property(properties, "#{name} #{description}") if kind == "logement"),
          vehicle_id: (guess_vehicle(vehicles, "#{name} #{description}") if kind == "vehicule") }
      end

      document = {
        name: str.("document_name").presence || insurance[:name],
        category: str.("document_category").presence_in(Document::CATEGORIES["insurance"]) || "other"
      }

      { insurance: insurance, coverages: coverages, items: items, document: document }
    end

    def self.parse_date(value)
      return nil if value.blank?

      Date.iso8601(value)
    rescue Date::Error
      Date.strptime(value, "%d/%m/%Y") rescue nil # rubocop:disable Style/RescueModifier
    end

    # « 1 234,56 € », « 254.80 », « 1.234,56 » -> BigDecimal ; nil si illisible.
    def self.parse_amount(value)
      digits = value.to_s.gsub(/[^\d,.]/, "")
      return nil if digits.blank?

      digits = digits.delete(".") if digits.include?(",") && digits.include?(".")
      BigDecimal(digits.tr(",", "."))
    rescue ArgumentError
      nil
    end

    def self.normalize_url(value)
      return "" if value.blank?

      url = value.match?(%r{\Ahttps?://}i) ? value : "https://#{value}"
      url.match?(URI::DEFAULT_PARSER.make_regexp(%w[http https])) && url.exclude?(" ") ? url : ""
    end

    # Bien de la page Immobilier designe par le texte (code postal ou ville) ; a defaut,
    # le seul bien enregistre. Sylvain corrige a la relecture si besoin.
    def self.guess_property(properties, text)
      return nil if properties.empty?

      folded = I18n.transliterate(text.to_s).downcase
      matches = properties.select do |property|
        (property.postal_code.present? && folded.include?(property.postal_code.to_s)) ||
          (property.city.present? && folded.include?(I18n.transliterate(property.city).downcase))
      end
      return matches.first.id if matches.size == 1

      properties.first.id if properties.size == 1
    end

    # Vehicule de la page Vehicules dont l'immatriculation figure dans le texte (tirets et
    # espaces ignores) ; a defaut, le seul vehicule enregistre.
    def self.guess_vehicle(vehicles, text)
      return nil if vehicles.empty?

      plate = ->(value) { value.to_s.upcase.gsub(/[^A-Z0-9]/, "") }
      folded = plate.(text)
      matches = vehicles.select { |vehicle| vehicle.registration_number.present? && folded.include?(plate.(vehicle.registration_number)) }
      return matches.first.id if matches.size == 1

      vehicles.first.id if vehicles.size == 1
    end

    private

    def read(blob)
      @text_extractor.call(blob)
    rescue Faraday::Error => e
      raise Error, "Mistral OCR injoignable (#{e.class.name.demodulize})"
    rescue RuntimeError => e
      raise Error, e.message
    end

    def extract(text)
      response = connection.post("/v1/chat/completions") do |req|
        req.body = {
          model: @model,
          temperature: 0,
          messages: [{ role: "system", content: PROMPT }, { role: "user", content: text }],
          response_format: { type: "json_schema", json_schema: { name: "insurance_contract", schema: SCHEMA, strict: true } }
        }
      end
      raise Error, "Mistral #{response.status} : #{response.body.to_s.truncate(300)}" unless response.success?

      JSON.parse(response.body.dig("choices", 0, "message", "content").to_s)
    rescue Faraday::Error => e
      raise Error, "Mistral injoignable (#{e.class.name.demodulize})"
    rescue JSON::ParserError
      raise Error, "Reponse de Mistral illisible"
    end

    def connection
      @connection ||= Faraday.new(url: BASE_URL) do |f|
        f.request :json
        f.response :json
        f.headers["Authorization"] = "Bearer #{@api_key}"
        f.options.timeout = CHAT_TIMEOUT
      end
    end
  end
end
