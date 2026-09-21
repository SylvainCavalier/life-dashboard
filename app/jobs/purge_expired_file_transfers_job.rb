# Supprime les transferts dont la date d'expiration est passee.
# Le destroy du record purge aussi le blob Active Storage sur le bucket OVH,
# ce qui evite les fichiers fantomes.
class PurgeExpiredFileTransfersJob < ApplicationJob
  queue_as :default

  def perform
    purged = 0

    FileTransfer.expired.includes(file_attachment: :blob).find_each do |transfer|
      # Purge synchrone du blob : on veut la certitude que l'objet a quitte le bucket
      # avant de perdre la reference en base.
      transfer.file.purge if transfer.file.attached?
      transfer.destroy
      purged += 1
    rescue StandardError => e
      Rails.logger.error "[PurgeExpiredFileTransfersJob] transfert ##{transfer.id} non purge : #{e.message}"
    end

    Rails.logger.info "[PurgeExpiredFileTransfersJob] #{purged} transfert(s) expire(s) supprime(s)" if purged.positive?
  end
end
