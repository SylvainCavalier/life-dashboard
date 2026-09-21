require "test_helper"

class PurgeExpiredFileTransfersJobTest < ActiveJob::TestCase
  def create_transfer(expires_at:)
    transfer = FileTransfer.new(expires_at: expires_at)
    transfer.file.attach(
      io: StringIO.new("contenu de test"),
      filename: "archive.zip",
      content_type: "application/zip"
    )
    transfer.tap(&:save!)
  end

  test "supprime les transferts expires et laisse les autres" do
    stale = create_transfer(expires_at: 1.hour.ago)
    fresh = create_transfer(expires_at: 2.days.from_now)

    PurgeExpiredFileTransfersJob.perform_now

    assert_not FileTransfer.exists?(stale.id)
    assert FileTransfer.exists?(fresh.id)
  end

  test "purge le blob du service de stockage" do
    stale = create_transfer(expires_at: 1.hour.ago)
    blob = stale.file.blob

    PurgeExpiredFileTransfersJob.perform_now

    assert_not ActiveStorage::Blob.service.exist?(blob.key)
    assert_not ActiveStorage::Blob.exists?(blob.id)
  end
end
