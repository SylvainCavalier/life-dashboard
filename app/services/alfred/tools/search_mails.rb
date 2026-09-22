module Alfred
  module Tools
    # Recherche dans la boite Gmail de Sylvain (syntaxe de la barre de recherche).
    class SearchMails < Base
      def self.definition
        {
          name: "search_mails",
          description: "Recherche dans la boite Gmail de Monsieur et renvoie les fils (thread_id, sujet, expediteur, date, " \
                       "extrait, non lu, libelles), du plus recent au plus ancien. `query` suit la syntaxe Gmail : " \
                       "from:, to:, subject:, is:unread, is:starred, newer_than:7d, older_than:1m, after:2026/09/01, " \
                       "label:nom, has:attachment, in:inbox, in:sent, in:anywhere, mots libres, OR, -exclusion. " \
                       "Sans query : la boite de reception. Un extrait ne suffit pas pour resumer ou repondre : " \
                       "lire le fil avec read_mail_thread.",
          input_schema: {
            type: "object",
            properties: {
              query: { type: "string", description: "Requete Gmail. Vide = boite de reception." },
              max_results: { type: "integer", description: "1 a 50, 20 par defaut." }
            }
          }
        }
      end

      def self.step_label(input) = "Gmail : #{input['query'].presence || 'boite de reception'}"

      def call(input)
        ensure_gmail!

        query = input["query"].to_s.strip.presence || "in:inbox"
        threads = Gmail.client.search(query, max_results: input.fetch("max_results", 20))
        { query: query, count: threads.size, threads: threads }
      end
    end
  end
end
