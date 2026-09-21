# == Schema Information
#
# Table name: file_transfers
#
#  id                 :bigint           not null, primary key
#  download_count     :integer          default(0), not null
#  expires_at         :datetime         not null
#  label              :string
#  last_downloaded_at :datetime
#  token              :string           not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
# Indexes
#
#  index_file_transfers_on_expires_at  (expires_at)
#  index_file_transfers_on_token       (token) UNIQUE
#
require "test_helper"

class FileTransferTest < ActiveSupport::TestCase
  def build_transfer(attributes = {})
    transfer = FileTransfer.new(attributes)
    transfer.file.attach(
      io: StringIO.new("contenu de test"),
      filename: "rapport.txt",
      content_type: "text/plain"
    )
    transfer
  end

  test "genere un token et une expiration par defaut a la creation" do
    transfer = build_transfer
    assert transfer.save

    assert transfer.token.present?
    assert_in_delta FileTransfer::DEFAULT_RETENTION.from_now, transfer.expires_at, 5.seconds
  end

  test "les tokens sont uniques d'un transfert a l'autre" do
    assert_not_equal build_transfer.tap(&:save!).token, build_transfer.tap(&:save!).token
  end

  test "un fichier est obligatoire" do
    transfer = FileTransfer.new
    assert_not transfer.valid?
    assert_includes transfer.errors.full_messages.join, "File"
  end

  test "expired? suit la date d'expiration" do
    assert_not build_transfer(expires_at: 1.hour.from_now).expired?
    assert build_transfer(expires_at: 1.second.ago).expired?
  end

  test "les scopes active et expired partitionnent les transferts" do
    valid = build_transfer(expires_at: 2.days.from_now).tap(&:save!)
    stale = build_transfer(expires_at: 1.hour.ago).tap(&:save!)

    assert_includes FileTransfer.active, valid
    assert_not_includes FileTransfer.active, stale
    assert_includes FileTransfer.expired, stale
    assert_not_includes FileTransfer.expired, valid
  end

  test "register_download! incremente le compteur et horodate" do
    transfer = build_transfer.tap(&:save!)

    transfer.register_download!
    transfer.reload

    assert_equal 1, transfer.download_count
    assert_not_nil transfer.last_downloaded_at
  end
end
