# Telecharge une video via yt-dlp (VideoDownloads::YtDlpService), puis, pour le
# stockage cloud, pousse le fichier sur le bucket OVH (Active Storage) et libere
# le disque. Un echec est consigne sur l'enregistrement (status "failed" +
# error_message) sans etre releve : la table fait foi, pas GoodJob.
class VideoDownloadJob < ApplicationJob
  queue_as :default

  # Telechargement supprime entre l'enqueue et l'execution.
  discard_on ActiveRecord::RecordNotFound

  def perform(video_download_id)
    download = VideoDownload.find(video_download_id)
    # Idempotence : une re-execution GoodJob ne relance pas un telechargement.
    return unless download.pending?

    download.update!(status: "processing")

    result = VideoDownloads::YtDlpService.new(
      url: download.url,
      format: download.format,
      quality: download.quality,
      output_dir: download.local_dir
    ).call

    download.assign_attributes(
      title: result.title,
      filename: result.filename,
      file_size: result.file_size,
      thumbnail_url: result.thumbnail_url,
      description: result.description,
      duration: result.duration,
      platform: result.platform,
      canonical_url: result.canonical_url,
      uploader: result.uploader,
      uploader_handle: result.uploader_handle,
      uploader_url: result.uploader_url,
      published_at: result.published_at,
      view_count: result.view_count
    )

    if download.cloud?
      upload_to_cloud(download, result.filepath)
      FileUtils.rm_rf(download.local_dir)
    end

    download.update!(status: "completed", completed_at: Time.current, error_message: nil)
    Rails.logger.info "[VideoDownloadJob] telechargement ##{download.id} termine (#{download.filename})"
  rescue ActiveRecord::RecordNotFound
    raise
  rescue StandardError => e
    Rails.logger.error "[VideoDownloadJob] telechargement ##{video_download_id} en echec : #{e.class}: #{e.message}"
    FileUtils.rm_rf(VideoDownload.local_dir_for(video_download_id))
    VideoDownload.where(id: video_download_id).update_all(
      status: "failed",
      error_message: "#{e.class}: #{e.message}".truncate(1000),
      updated_at: Time.current
    )
  end

  private

  def upload_to_cloud(download, filepath)
    File.open(filepath, "rb") do |io|
      download.file.attach(
        io: io,
        filename: download.filename,
        content_type: download.content_type,
        key: download.storage_key,
        identify: false
      )
      # L'envoi vers le bucket a lieu a la sauvegarde : elle doit se faire tant
      # que le fichier est ouvert.
      download.save!
    end
  end
end
