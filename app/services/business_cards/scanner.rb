module BusinessCards
  # Deux appels Mistral : OCR de la photo (`mistral-ocr-latest`, meme client que le
  # corpus d'Alfred), puis extraction en sortie structuree (JSON Schema strict) par un
  # modele de chat. Synchrone : les deux delais tiennent sous les 30 s du routeur Heroku.
  class Scanner
    DEFAULT_MODEL = "mistral-small-latest".freeze
    BASE_URL = "https://api.mistral.ai".freeze
    OCR_TIMEOUT = 15
    CHAT_TIMEOUT = 12

    FIELDS = %w[
      first_name last_name job_title company email phone other_phones address city website linkedin other
    ].freeze

    SCHEMA = {
      type: "object",
      properties: FIELDS.index_with { { type: "string" } },
      required: FIELDS,
      additionalProperties: false
    }.freeze

    PROMPT = <<~TEXT.freeze
      Tu reçois le texte d'une carte de visite, lu par OCR (Markdown, parfois approximatif).
      Range-le dans les champs demandés. Chaîne vide pour tout champ absent de la carte : n'invente rien.
      - first_name / last_name : prénom et nom de la personne (pas de l'entreprise), casse normale
        (« DUPONT » devient « Dupont », particules en minuscules).
      - job_title : la fonction (« Avocat associé ») ; company : l'entreprise ou l'organisme.
      - phone : un seul numéro, le portable de préférence, sinon le fixe, tel qu'écrit
        (format « 06 12 34 56 78 » pour un numéro français). other_phones : les autres, avec leur nature
        (« Fixe : 01 23 45 67 89 · Fax : ... »).
      - email : une seule adresse, en minuscules ; s'il y en a plusieurs, les autres vont dans other.
      - address : rue et code postal ; city : la ville seule.
      - website : le site ; linkedin : l'URL ou l'identifiant LinkedIn.
      - other : ce qui reste d'utile (autres réseaux, slogan exclu), en une ligne.
      Corrige les erreurs d'OCR évidentes (« 0 » lu « O » dans un numéro, « @ » manquant).
    TEXT

    def initialize(api_key: ENV["MISTRAL_API_KEY"], model: ENV.fetch("BUSINESS_CARD_MODEL", DEFAULT_MODEL),
                   ocr: Alfred::Corpus::MistralOcr.new(api_key: api_key, timeout: OCR_TIMEOUT))
      @api_key = api_key
      @model = model
      @ocr = ocr
    end

    # `file` : chemin ou IO d'une image (JPEG, PNG, WebP).
    # Renvoie { contact: attributs de Contact, text: texte lu par l'OCR }.
    def scan(file)
      raise NotConfigured, "MISTRAL_API_KEY manquante" if @api_key.blank?

      text = read(file)
      raise Error, "Aucun texte lisible sur la photo" if text.strip.length < 5

      { contact: self.class.contact_attributes(extract(text)), text: text }
    end

    # Champs extraits -> attributs d'un Contact (formulaire de la page Contacts).
    def self.contact_attributes(fields, today: Date.current)
      fields = FIELDS.index_with { |key| fields[key].to_s.strip }
      email = fields["email"].downcase
      email = "" unless email.match?(URI::MailTo::EMAIL_REGEXP)
      notes = [
        ("Site : #{fields['website']}" if fields["website"].present?),
        fields["other_phones"].presence,
        ("Email lu : #{fields['email']}" if email.blank? && fields["email"].present?),
        fields["other"].presence,
        "Carte de visite scannée le #{today.strftime('%d/%m/%Y')}"
      ].compact

      {
        first_name: fields["first_name"],
        last_name: fields["last_name"],
        occupation: [fields["job_title"], fields["company"]].compact_blank.join(", "),
        email: email,
        phone: fields["phone"],
        address: fields["address"],
        city: fields["city"],
        social_linkedin: fields["linkedin"],
        relationship_type: "connaissance",
        met_year: today.year,
        notes: notes.join("\n")
      }
    end

    private

    def read(file)
      @ocr.read_image(file)
    rescue Faraday::Error => e
      raise Error, "Mistral OCR injoignable (#{e.class.name.demodulize})"
    rescue Vips::Error
      raise Error, "Image illisible"
    rescue RuntimeError => e
      raise Error, e.message
    end

    def extract(text)
      response = connection.post("/v1/chat/completions") do |req|
        req.body = {
          model: @model,
          temperature: 0,
          messages: [{ role: "system", content: PROMPT }, { role: "user", content: text.truncate(4000) }],
          response_format: { type: "json_schema", json_schema: { name: "business_card", schema: SCHEMA, strict: true } }
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
