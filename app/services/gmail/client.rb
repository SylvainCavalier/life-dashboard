require "google/apis/gmail_v1"

module Gmail
  # Enveloppe de l'API Gmail pour la boite de GMAIL_USER. Les erreurs de la gem
  # sont traduites en `Client::Error` ; les objets Google ne sortent pas d'ici
  # (Parser les transforme en Hash).
  class Client
    class Error < StandardError; end
    class NotFound < Error; end

    ME = "me".freeze
    MAX_RESULTS = 50

    def initialize(user: Gmail.user)
      if user.blank? || !GoogleServiceAccount.configured?
        raise Error,
              "GMAIL_USER et la cle du compte de service sont requis"
      end

      @user = user
    end

    # Test de connexion (rake gmail:check).
    def profile
      profile = call { service.get_user_profile(ME) }
      { email: profile.email_address, messages_total: profile.messages_total, threads_total: profile.threads_total }
    end

    def labels
      @labels ||= call { service.list_user_labels(ME) }.labels.to_a.map do |label|
        { id: label.id, name: label.name, type: label.type }
      end
    end

    def label_names
      labels.to_h { |label| [label[:id], label[:name]] }
    end

    # Adresses depuis lesquelles la boite peut envoyer (« Envoyer des e-mails en
    # tant que », alias verifies) ; la premiere est l'adresse principale.
    def send_as_aliases
      @send_as_aliases ||= begin
        aliases = call { service.list_user_setting_send_as(ME) }.send_as.to_a
        aliases = aliases.select { |a| a.is_default || a.verification_status == "accepted" }
        aliases.sort_by { |a| a.is_default ? 0 : 1 }.map do |a|
          { email: a.send_as_email, name: a.display_name.presence, default: a.is_default == true }
        end
      end
    end

    def find_or_create_label(name)
      existing = labels.find { |label| label[:name].casecmp?(name) }
      return existing[:id] if existing

      created = call do
        service.create_user_label(ME, Google::Apis::GmailV1::Label.new(
                                        name: name, label_list_visibility: "labelShow", message_list_visibility: "show"
                                      ))
      end
      @labels = nil
      created.id
    end

    # Fils correspondant a une recherche (syntaxe de la barre de recherche Gmail).
    def search(query, max_results: 20)
      list = call do
        service.list_user_threads(ME, q: query.presence, max_results: max_results.to_i.clamp(1, MAX_RESULTS))
      end
      threads_summary(list.threads.to_a.map(&:id))
    end

    # Resumes de fils par identifiants (un seul appel HTTP groupe).
    def threads_summary(ids)
      return [] if ids.empty?

      threads = []
      call do
        service.batch do |batch|
          ids.each do |id|
            batch.get_user_thread(ME, id, format: "metadata", metadata_headers: Parser::HEADERS) do |thread, error|
              threads << thread if thread
              Rails.logger.warn("[Gmail] fil #{id} : #{error.message}") if error
            end
          end
        end
      end
      names = label_names
      threads.sort_by { |thread| ids.index(thread.id) }.map { |thread| Parser.thread_summary(thread, names) }
    end

    def thread(id)
      Parser.thread_full(raw_thread(id), label_names)
    end

    # En-tetes du dernier message d'un fil, pour y repondre.
    def reply_headers(id)
      Parser.reply_headers(raw_thread(id, format: "metadata").messages.to_a.last)
    end

    def modify_thread(id, add: [], remove: [])
      request = Google::Apis::GmailV1::ModifyThreadRequest.new(add_label_ids: add.presence,
                                                               remove_label_ids: remove.presence)
      call { service.modify_thread(ME, id, request) }
      nil
    end

    def trash_thread(id)
      call { service.trash_user_thread(ME, id) }
      nil
    end

    def untrash_thread(id)
      call { service.untrash_user_thread(ME, id) }
      nil
    end

    # Envoie un Mail::Message ; `thread_id` le rattache a un fil existant.
    # `raw` recoit le RFC 822 brut : c'est la gem qui l'encode en base64 URL.
    def send_message(mail, thread_id: nil)
      message = Google::Apis::GmailV1::Message.new(raw: mail.to_s, thread_id: thread_id.presence)
      sent = call { service.send_user_message(ME, message) }
      { message_id: sent.id, thread_id: sent.thread_id }
    end

    def create_draft(mail, thread_id: nil)
      message = Google::Apis::GmailV1::Message.new(raw: mail.to_s, thread_id: thread_id.presence)
      draft = call { service.create_user_draft(ME, Google::Apis::GmailV1::Draft.new(message: message)) }
      { draft_id: draft.id, message_id: draft.message&.id, thread_id: draft.message&.thread_id }
    end

    private

    def raw_thread(id, format: "full")
      call { service.get_user_thread(ME, id, format: format, metadata_headers: Parser::HEADERS) }
    end

    def service
      @service ||= Google::Apis::GmailV1::GmailService.new.tap do |svc|
        svc.client_options.application_name = "Life Dashboard"
        svc.request_options.retries = 2
        svc.authorization = GoogleServiceAccount.credentials(scope: SCOPE, subject: @user)
      end
    end

    def call
      yield
    rescue Google::Apis::AuthorizationError, Signet::AuthorizationError => e
      # Signet : le jeton lui-meme est refuse (unauthorized_client), c'est le cas
      # tant que la delegation au niveau du domaine n'est pas declaree.
      raise Error, "Gmail : acces refuse (#{e.message.truncate(120)}). La delegation au niveau du domaine " \
                   "est-elle en place pour l'identifiant client #{GoogleServiceAccount.client_id} avec le scope #{SCOPE} ?"
    rescue Google::Apis::ClientError => e
      raise NotFound, "Gmail : fil ou message introuvable" if e.status_code == 404

      raise Error, "Gmail : #{e.message}"
    rescue Google::Apis::Error => e
      raise Error, "Gmail : #{e.message}"
    end
  end
end
