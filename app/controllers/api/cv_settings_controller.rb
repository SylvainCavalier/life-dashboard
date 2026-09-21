module Api
  class CvSettingsController < ApplicationController
    def show
      render json: setting_payload(CvSetting.singleton)
    end

    def update
      setting = CvSetting.singleton
      if setting.update(setting_params)
        render json: setting_payload(setting)
      else
        render json: { errors: setting.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def destroy_photo
      setting = CvSetting.singleton
      setting.photo.purge if setting.photo.attached?
      render json: setting_payload(setting)
    end

    private

    def setting_params
      params.fetch(:cv_setting, params).permit(:default_template, :default_color, :pitch, :photo)
    end

    def setting_payload(setting)
      setting.slice(:default_template, :default_color, :pitch).merge(
        photo_data_url: setting.photo_data_url
      )
    end
  end
end
