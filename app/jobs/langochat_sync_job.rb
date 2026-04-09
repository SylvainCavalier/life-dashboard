class LangochatSyncJob < ApplicationJob
  queue_as :default

  def perform
    result = Langochat::SyncService.new.sync!
    Rails.logger.info("[LangochatSyncJob] Synchronisation terminee: #{result[:synced]} session(s) ajoutee(s)")
    if result[:errors].any?
      Rails.logger.warn("[LangochatSyncJob] Erreurs: #{result[:errors].join(', ')}")
    end
  end
end
