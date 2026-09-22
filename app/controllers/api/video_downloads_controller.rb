module Api
  # Module Downloader : telechargement de videos / pistes audio via yt-dlp.
  class VideoDownloadsController < ApplicationController
    # Renseigne ActiveStorage::Current.url_options : necessaire pour generer l'URL
    # du fichier avec le service Disk (tests) ; sans effet avec le service S3.
    include ActiveStorage::SetCurrent

    before_action :set_download, only: [:show, :destroy, :file]

    # GET /api/video_downloads?status=&video_folder_id=
    def index
      downloads = VideoDownload.recent.with_attached_file
      downloads = downloads.where(status: params[:status]) if params[:status].present?
      downloads = downloads.where(video_folder_id: params[:video_folder_id]) if params[:video_folder_id].present?
      render json: downloads.map { |download| download_json(download) }
    end

    # GET /api/video_downloads/availability
    # Disponibilite des binaires : l'interface previent quand le module ne peut
    # pas fonctionner sur cet hote (yt-dlp / ffmpeg absents).
    def availability
      missing = VideoDownloads::YtDlpService.missing_binaries
      render json: { available: missing.empty?, missing_binaries: missing }
    end

    # GET /api/video_downloads/:id
    def show
      render json: download_json(@download)
    end

    # POST /api/video_downloads
    def create
      download = VideoDownload.enqueue!(download_params)
      render json: download_json(download), status: :created
    rescue ActiveRecord::RecordInvalid => e
      render json: { errors: e.record.errors.full_messages }, status: :unprocessable_content
    end

    # DELETE /api/video_downloads/:id
    # Le fichier local part avec l'enregistrement (callback du modele), le blob
    # OVH est purge par Active Storage.
    def destroy
      @download.destroy
      head :no_content
    end

    # GET /api/video_downloads/:id/file?disposition=inline
    # Local : le fichier est renvoye depuis le disque. Cloud : redirection vers
    # une URL pre-signee de courte duree. `inline` sert au lecteur integre.
    def file
      return render json: { error: "Fichier indisponible" }, status: :gone unless @download.file_available?

      disposition = params[:disposition] == "inline" ? "inline" : "attachment"
      if @download.local?
        send_file @download.local_filepath, filename: @download.filename,
                                            type: @download.content_type, disposition: disposition
      else
        redirect_to @download.file.url(expires_in: 15.minutes, disposition: disposition,
                                       filename: @download.file.filename),
                    allow_other_host: true
      end
    end

    private

    def set_download
      @download = VideoDownload.find(params[:id])
    end

    def download_params
      params.require(:video_download).permit(:url, :format, :quality, :storage, :video_folder_id,
                                             :clip_start, :clip_end)
    end

    def download_json(download)
      available = download.file_available?
      {
        id: download.id,
        url: download.url,
        format: download.format,
        quality: download.quality,
        storage: download.storage,
        status: download.status,
        title: download.title,
        filename: download.filename,
        file_size: download.file_size,
        thumbnail_url: download.thumbnail_url,
        description: download.description,
        duration: download.duration,
        clip_start: download.clip_start,
        clip_end: download.clip_end,
        clip_label: download.clip_label,
        platform: download.platform,
        canonical_url: download.canonical_url,
        uploader: download.uploader,
        uploader_handle: download.uploader_handle,
        uploader_url: download.uploader_url,
        published_at: download.published_at,
        view_count: download.view_count,
        citation: download.citation,
        video_folder_id: download.video_folder_id,
        error_message: download.error_message,
        completed_at: download.completed_at,
        created_at: download.created_at,
        file_available: available,
        file_url: available ? file_api_video_download_path(download) : nil
      }
    end
  end
end
