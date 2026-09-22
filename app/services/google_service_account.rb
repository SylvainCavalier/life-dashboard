require "googleauth"

# Le compte de service Google Cloud de l'application, partage par l'agenda
# (GoogleCalendar : l'agenda lui est partage) et par la gestion des mails
# d'Alfred (Gmail : delegation au niveau du domaine Workspace, le compte de
# service agit « en tant que » GMAIL_USER).
#
# La cle JSON vit dans GOOGLE_SERVICE_ACCOUNT_CREDENTIALS ; GOOGLE_CALENDAR_CREDENTIALS
# (nom historique, la premiere integration etait l'agenda) reste accepte.
module GoogleServiceAccount
  module_function

  def credentials_json
    ENV["GOOGLE_SERVICE_ACCOUNT_CREDENTIALS"].presence || ENV["GOOGLE_CALENDAR_CREDENTIALS"].presence
  end

  def configured?
    credentials_json.present?
  end

  def key
    JSON.parse(credentials_json.to_s)
  rescue JSON::ParserError
    {}
  end

  # Adresse a laquelle partager un agenda.
  def client_email
    key["client_email"]
  end

  # Identifiant a declarer dans la delegation au niveau du domaine (Workspace).
  def client_id
    key["client_id"]
  end

  # `subject` : utilisateur Workspace a incarner (delegation au niveau du domaine).
  def credentials(scope:, subject: nil, json: credentials_json)
    raise ArgumentError, "cle du compte de service absente" if json.blank?

    creds = Google::Auth::ServiceAccountCredentials.make_creds(json_key_io: StringIO.new(json), scope: scope)
    creds.sub = subject if subject.present?
    creds
  end
end
