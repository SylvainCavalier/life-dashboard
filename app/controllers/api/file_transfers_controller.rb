class Api::FileTransfersController < ApplicationController
  # GET /api/file_transfers
  def index
    transfers = FileTransfer.with_attached_file.recent_first
    render json: transfers.map { |transfer| transfer_json(transfer) }
  end

  # POST /api/file_transfers
  # Attend un signed_id issu du direct upload Active Storage (ou un fichier multipart)
  def create
    transfer = FileTransfer.new(label: params[:label])
    transfer.expires_at = expiry_from_params
    transfer.file.attach(params[:file]) if params[:file].present?

    if transfer.save
      render json: transfer_json(transfer), status: :created
    else
      render json: { errors: transfer.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /api/file_transfers/:id
  def destroy
    transfer = FileTransfer.find(params[:id])
    transfer.destroy
    head :no_content
  end

  private

  def expiry_from_params
    days = params[:retention_days].presence&.to_i
    return FileTransfer::DEFAULT_RETENTION.from_now if days.nil? || days <= 0

    days.clamp(1, 30).days.from_now
  end

  def transfer_json(transfer)
    {
      id: transfer.id,
      token: transfer.token,
      label: transfer.label,
      share_url: "#{request.base_url}#{transfer_path(transfer.token)}",
      file_name: transfer.file.attached? ? transfer.file.filename.to_s : nil,
      file_size: transfer.file.attached? ? transfer.file.byte_size : nil,
      content_type: transfer.file.attached? ? transfer.file.content_type : nil,
      expires_at: transfer.expires_at,
      expired: transfer.expired?,
      download_count: transfer.download_count,
      last_downloaded_at: transfer.last_downloaded_at,
      created_at: transfer.created_at
    }
  end
end
