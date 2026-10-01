module Api
  # Outil Videos (page Outils). La video arrive par direct upload (bucket OVH) : le client
  # envoie le signed_id du blob, jamais le fichier lui-meme. Ou bien elle vient du
  # Downloader (`video_download_id`). La table `video_transcripts` fait foi pour l'etat
  # du traitement : l'interface la sonde tant que `in_progress` est vrai.
  class VideoTranscriptsController < ApplicationController
    before_action :set_transcript, only: [:show, :update, :destroy, :regenerate, :pdf, :save_to_documents]

    def index
      render json: VideoTranscript.recent.includes(:document).map { |transcript| transcript_json(transcript) }
    end

    # Ce que l'interface doit savoir avant de proposer l'outil.
    def availability
      render json: {
        transcription: Transcription.enabled?,
        summary: ENV["ANTHROPIC_API_KEY"].present?,
        audio_extraction: VideoTranscripts::AudioExtractor.available?,
        max_bytes: VideoTranscript::MAX_VIDEO_BYTES,
        languages: VideoTranscript::LANGUAGES.map { |code, label| { code: code, label: label } }
      }
    end

    # Telechargements du Downloader dont le fichier est encore recuperable.
    def sources
      downloads = VideoDownload.recent.where(status: "completed").with_attached_file.limit(200).select(&:file_available?)
      render json: downloads.map { |download|
        download.slice(:id, :title, :format, :storage, :platform, :uploader, :duration, :created_at).merge(clip_label: download.clip_label)
      }
    end

    def show
      render json: transcript_json(@transcript, full: true)
    end

    def create
      transcript = build_transcript
      return render(json: { errors: ["Aucune video jointe"] }, status: :unprocessable_entity) unless transcript

      if transcript.save
        transcript.process!
        render json: transcript_json(transcript, full: true), status: :created
      else
        render json: { errors: transcript.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # Titre et noms des intervenants. Ne relance rien : c'est `regenerate` qui refait le
    # resume ; le PDF, lui, est genere a la demande et prend les noms tout de suite
    # (celui deja range dans les documents est remplace).
    def update
      if @transcript.update(transcript_params)
        if @transcript.document && @transcript.transcribed? && (@transcript.saved_change_to_speaker_names? || @transcript.saved_change_to_title?)
          @transcript.save_to_documents!
        end
        render json: transcript_json(@transcript, full: true)
      else
        render json: { errors: @transcript.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # Transcription terminee : nouveau resume. En echec : reprise la ou elle s'est arretee.
    def regenerate
      return render(json: { errors: ["Traitement deja en cours"] }, status: :conflict) if @transcript.in_progress? && !@transcript.stuck?

      @transcript.done? ? @transcript.regenerate! : @transcript.process!
      render json: transcript_json(@transcript.reload, full: true)
    end

    def pdf
      return render(json: { errors: ["Transcription pas encore terminee"] }, status: :conflict) unless @transcript.transcribed?

      report = VideoTranscripts::ReportPdf.new(@transcript)
      send_data report.generate, filename: report.filename, type: "application/pdf", disposition: "attachment"
    end

    # Range le PDF dans les documents (ou met a jour celui deja range).
    def save_to_documents
      return render(json: { errors: ["Transcription pas encore terminee"] }, status: :conflict) unless @transcript.transcribed?

      @transcript.save_to_documents!
      render json: transcript_json(@transcript.reload, full: true)
    end

    # Le PDF range dans les documents y reste ; une video importee non encore transcrite
    # part avec l'enregistrement (Active Storage).
    def destroy
      @transcript.destroy
      head :no_content
    end

    private

    def set_transcript
      @transcript = VideoTranscript.find(params[:id])
    end

    def build_transcript
      language = params.dig(:video_transcript, :language).presence || "auto"
      if params[:video_download_id].present?
        transcript = VideoTranscript.build_from_download(VideoDownload.find(params[:video_download_id]), language: language)
        transcript.title = params.dig(:video_transcript, :title) if params.dig(:video_transcript, :title).present?
        transcript
      elsif params[:video].present?
        transcript = VideoTranscript.new(transcript_params.merge(language: language))
        transcript.video.attach(params[:video])
        transcript
      end
    end

    def transcript_params
      permitted = params.require(:video_transcript).permit(:title, speaker_names: {})
      permitted[:speaker_names] = permitted[:speaker_names].to_h.transform_values { |name| name.to_s.strip } if permitted.key?(:speaker_names)
      permitted
    end

    def transcript_json(transcript, full: false)
      json = {
        id: transcript.id,
        title: transcript.title,
        language: transcript.language,
        language_label: transcript.language_label,
        source: transcript.source_label,
        source_citation: transcript.source_citation,
        video_download_id: transcript.video_download_id,
        status: transcript.status,
        step: transcript.step,
        error: transcript.error,
        in_progress: transcript.in_progress?,
        stuck: transcript.stuck?,
        transcribed: transcript.transcribed?,
        duration_seconds: transcript.duration_seconds,
        overview: transcript.summary["overview"],
        document: transcript.document && {
          id: transcript.document.id,
          name: transcript.document.name,
          download_url: transcript.document.file.attached? ? download_api_document_path(transcript.document) : nil
        },
        pdf_url: transcript.transcribed? ? pdf_api_video_transcript_path(transcript) : nil,
        created_at: transcript.created_at
      }
      return json unless full

      json.merge(
        summary: transcript.summary,
        summary_model: transcript.summary_model,
        speakers: transcript.speakers.map { |speaker| { id: speaker, name: transcript.speaker_names[speaker], label: transcript.speaker_label(speaker) } },
        turns: transcript.turns
      )
    end
  end
end
