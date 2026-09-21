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
class FileTransfer < ApplicationRecord
  has_one_attached :file

  # Duree de vie par defaut d'un transfert avant purge automatique
  DEFAULT_RETENTION = 3.days

  before_validation :assign_token, on: :create
  before_validation :assign_default_expiry, on: :create

  validates :token, presence: true, uniqueness: true
  validates :expires_at, presence: true
  validates :file, presence: true

  scope :active, -> { where(expires_at: Time.current..) }
  scope :expired, -> { where(expires_at: ...Time.current) }
  scope :recent_first, -> { order(created_at: :desc) }

  def expired?
    expires_at <= Time.current
  end

  def remaining_seconds
    [ (expires_at - Time.current).to_i, 0 ].max
  end

  # URL S3 pre-signee, valable le temps du telechargement uniquement
  def download_url(expires_in: 15.minutes)
    return nil unless file.attached?

    file.url(expires_in: expires_in, disposition: "attachment", filename: file.filename)
  end

  def register_download!
    increment!(:download_count)
    update_column(:last_downloaded_at, Time.current)
  end

  private

  def assign_token
    self.token ||= loop do
      candidate = SecureRandom.urlsafe_base64(18)
      break candidate unless self.class.exists?(token: candidate)
    end
  end

  def assign_default_expiry
    self.expires_at ||= DEFAULT_RETENTION.from_now
  end
end
