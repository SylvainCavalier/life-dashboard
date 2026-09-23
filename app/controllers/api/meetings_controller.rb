module Api
  # Module Reunions. L'audio arrive par direct upload (bucket OVH) : le client envoie
  # le signed_id du blob, jamais le fichier lui-meme (une heure de reunion depasserait
  # le delai du routeur Heroku). La table `meetings` fait foi pour l'etat du traitement :
  # l'interface la sonde tant que `in_progress` est vrai.
  #
  # Enregistrement en direct : `create` avec `recording: true` ouvre une reunion sans audio
  # (statut "recording"), `chunks` recoit un morceau toutes les 30 s, `finish` lance le
  # traitement. Les morceaux passent par Rails (quelques centaines de Ko) et non par direct
  # upload : un aller-retour de moins toutes les 30 s, et le rang du morceau est controle.
  class MeetingsController < ApplicationController
    before_action :set_meeting, only: [:show, :update, :destroy, :regenerate, :chunks, :finish]

    CHUNK_TYPES = %r{\A(audio/(webm|mp4|ogg)|video/(webm|mp4))\z}

    def index
      render json: Meeting.recent.includes(:document).map { |meeting| meeting_json(meeting) }
    end

    def show
      render json: meeting_json(@meeting, full: true)
    end

    def create
      meeting = Meeting.new(meeting_params)
      meeting.held_at ||= Time.current
      return create_recording(meeting) if ActiveModel::Type::Boolean.new.cast(params[:recording])

      meeting.audio.attach(params[:audio]) if params[:audio].present?
      return render(json: { errors: ["Aucun enregistrement joint"] }, status: :unprocessable_entity) unless meeting.audio.attached?

      if meeting.save
        meeting.process!
        render json: meeting_json(meeting, full: true), status: :created
      else
        render json: { errors: meeting.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # Metadonnees et noms des intervenants. Ne relance rien : c'est `regenerate`
    # qui refait la synthese et le PDF avec les nouveaux noms.
    def update
      if @meeting.update(meeting_params)
        render json: meeting_json(@meeting, full: true)
      else
        render json: { errors: @meeting.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # Reunion terminee : nouvelle synthese et nouveau PDF (la transcription est gardee).
    # Reunion en echec : reprise la ou le traitement s'est arrete.
    def regenerate
      return render(json: { errors: ["Enregistrement en cours : le terminer d'abord"] }, status: :conflict) if @meeting.recording?
      return render(json: { errors: ["Traitement deja en cours"] }, status: :conflict) if @meeting.in_progress? && !@meeting.stuck?

      @meeting.done? ? @meeting.regenerate! : @meeting.process!
      render json: meeting_json(@meeting.reload, full: true)
    end

    # Un morceau d'enregistrement (multipart : chunk, part, seq). Idempotent : un morceau
    # renvoye apres une coupure reseau n'est pas stocke deux fois.
    def chunks
      return render(json: { errors: ["Cette reunion n'est plus en cours d'enregistrement"] }, status: :conflict) unless @meeting.recording?

      chunk = params[:chunk]
      part = params[:part].to_i
      seq = params[:seq].to_i
      content_type = chunk.respond_to?(:content_type) ? chunk.content_type.to_s.split(";").first : nil
      error = if !chunk.respond_to?(:tempfile) then "Morceau absent"
              elsif part < 1 || seq.negative? then "Numero de morceau invalide"
              elsif !CHUNK_TYPES.match?(content_type.to_s) then "Format audio non pris en charge (#{content_type.presence || 'inconnu'})"
              elsif chunk.size > Meeting::MAX_CHUNK_BYTES then "Morceau trop volumineux"
              end
      return render(json: { errors: [error] }, status: :unprocessable_entity) if error

      filename = Meeting.chunk_filename(part, seq, content_type.sub(%r{\Avideo/}, "audio/"))
      unless @meeting.audio_chunks.blobs.any? { |blob| blob.filename.to_s == filename }
        @meeting.audio_chunks.attach(io: chunk.tempfile, filename: filename, content_type: content_type)
      end
      render json: { recording: @meeting.reload.recording_stats }
    end

    # Fin de l'enregistrement en direct : transcription, synthese, PDF.
    def finish
      return render(json: { errors: ["Cette reunion n'est pas en cours d'enregistrement"] }, status: :conflict) unless @meeting.recording?
      return render(json: { errors: ["Aucun audio recu : rien a transcrire"] }, status: :unprocessable_entity) unless @meeting.audio_chunks.attached?

      @meeting.finish!
      render json: meeting_json(@meeting.reload, full: true)
    end

    # Le compte rendu PDF reste dans les documents : c'est lui l'archive.
    def destroy
      @meeting.destroy
      head :no_content
    end

    private

    def create_recording(meeting)
      meeting.status = "recording"
      meeting.title = "Réunion du #{meeting.held_at.in_time_zone('Europe/Paris').strftime('%d/%m/%Y à %H:%M')}" if meeting.title.blank?
      if meeting.save
        render json: meeting_json(meeting, full: true), status: :created
      else
        render json: { errors: meeting.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def set_meeting
      @meeting = Meeting.find(params[:id])
    end

    def meeting_params
      permitted = params.require(:meeting).permit(:title, :kind, :held_at, :participants, :context, speaker_names: {})
      permitted[:speaker_names] = permitted[:speaker_names].to_h.transform_values { |name| name.to_s.strip } if permitted.key?(:speaker_names)
      permitted
    end

    def meeting_json(meeting, full: false)
      json = {
        id: meeting.id,
        title: meeting.title,
        kind: meeting.kind,
        held_at: meeting.held_at,
        participants: meeting.participants,
        context: meeting.context,
        status: meeting.status,
        step: meeting.step,
        error: meeting.error,
        in_progress: meeting.in_progress?,
        stuck: meeting.stuck?,
        duration_seconds: meeting.duration_seconds,
        overview: meeting.summary["overview"],
        recording: meeting.recording? ? meeting.recording_stats : nil,
        document: meeting.document && {
          id: meeting.document.id,
          name: meeting.document.name,
          download_url: meeting.document.file.attached? ? download_api_document_path(meeting.document) : nil
        },
        created_at: meeting.created_at
      }
      return json unless full

      json.merge(
        summary: meeting.summary,
        summary_model: meeting.summary_model,
        speakers: meeting.speakers.map { |speaker| { id: speaker, name: meeting.speaker_names[speaker], label: meeting.speaker_label(speaker) } },
        turns: meeting.turns
      )
    end
  end
end
