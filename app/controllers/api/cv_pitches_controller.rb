module Api
  class CvPitchesController < ApplicationController
    def index
      render json: CvPitch.ordered
    end

    # activate=true : la nouvelle accroche devient celle du CV.
    def create
      pitch = CvPitch.new(pitch_params)
      if pitch.save
        CvSetting.singleton.update!(active_pitch: pitch) if activate?
        render json: pitch, status: :created
      else
        render json: { errors: pitch.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def update
      pitch = CvPitch.find(params[:id])
      if pitch.update(pitch_params)
        render json: pitch
      else
        render json: { errors: pitch.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # Supprimer l'accroche active laisse simplement le CV sans accroche
    # (dependent: :nullify, doublee d'un ON DELETE SET NULL en base).
    def destroy
      CvPitch.find(params[:id]).destroy
      head :no_content
    end

    private

    def pitch_params
      params.require(:cv_pitch).permit(:title, :content, :position)
    end

    def activate?
      ActiveModel::Type::Boolean.new.cast(params[:activate])
    end
  end
end
