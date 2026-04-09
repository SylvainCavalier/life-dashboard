require "net/http"
require "json"

module Langochat
  class SyncService
    def initialize
      @api_url = ENV.fetch("LANGOCHAT_API_URL")
      @api_key = ENV.fetch("LANGOCHAT_API_KEY")
    end

    def sync!
      data = fetch_practice_summary
      return { synced: 0, errors: ["Pas de donnees recues"] } unless data

      languages_data = data["languages"] || {}
      # Inverse map: langochat code -> language name
      code_to_name = Language::NAMES.invert
      synced = 0
      errors = []

      languages_data.each do |lang_code, lang_data|
        language_name = code_to_name[lang_code]
        next unless language_name

        language = Language.find_by(name: language_name)
        next unless language

        practice_dates = lang_data["practice_dates"] || []
        practice_dates.each do |date_str|
          date = Date.parse(date_str)
          session = language.language_sessions.find_or_initialize_by(
            practiced_on: date,
            source: "langochat"
          )
          if session.new_record? && session.save
            synced += 1
          end
        rescue Date::Error => e
          errors << "Date invalide: #{date_str} - #{e.message}"
        end
      end

      { synced: synced, errors: errors }
    end

    private

    def fetch_practice_summary
      uri = URI("#{@api_url}/api/external/practice_summary")
      uri.query = URI.encode_www_form(since: 1.year.ago.to_date.to_s)

      request = Net::HTTP::Get.new(uri)
      request["X-Api-Key"] = @api_key
      request["Accept"] = "application/json"

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https", open_timeout: 10, read_timeout: 10) do |http|
        http.request(request)
      end

      if response.is_a?(Net::HTTPSuccess)
        JSON.parse(response.body)
      else
        Rails.logger.error("[Langochat::SyncService] API error #{response.code}: #{response.body}")
        nil
      end
    rescue StandardError => e
      Rails.logger.error("[Langochat::SyncService] Connection error: #{e.message}")
      nil
    end
  end
end
