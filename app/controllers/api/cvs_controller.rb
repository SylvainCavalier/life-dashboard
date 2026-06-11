module Api
  class CvsController < ApplicationController
    protect_from_forgery with: :null_session

    # Fields from PersonalProfile exposed to the CV (safe, non-sensitive)
    PROFILE_FIELDS = %i[
      first_name last_name birth_date email phone mobile_phone
      address_line1 address_line2 city postal_code state country
      occupation nationality professional_email professional_phone
    ].freeze

    def data
      setting = CvSetting.singleton
      render json: {
        profile:     profile_payload,
        experiences: CvExperience.ordered,
        formations:  CvFormation.ordered,
        skills:      CvSkill.ordered,
        interests:   CvInterest.ordered,
        settings:    setting.slice(:default_template, :default_color, :pitch).merge(
          photo_data_url: setting.photo_data_url
        )
      }
    end

    def export_pdf
      html = params.require(:html)
      pdf = Grover.new(
        html,
        format: "A4",
        margin: { top: "0", bottom: "0", left: "0", right: "0" },
        print_background: true,
        prefer_css_page_size: true,
        emulate_media: "print"
      ).to_pdf

      send_data pdf,
        filename: "cv-#{Date.current.iso8601}.pdf",
        type: "application/pdf",
        disposition: "attachment"
    rescue => e
      Rails.logger.error("CV PDF export failed: #{e.class} — #{e.message}")
      render json: { error: "PDF generation failed: #{e.message}" }, status: :internal_server_error
    end

    private

    def profile_payload
      profile = PersonalProfile.first
      return {} unless profile

      payload = profile.slice(*PROFILE_FIELDS.map(&:to_s))
      payload["full_name"] = profile.full_name
      payload["full_address"] = profile.full_address
      payload["age"] = age_for(profile.birth_date)
      payload
    end

    def age_for(birth_date)
      return nil unless birth_date
      today = Date.current
      age = today.year - birth_date.year
      age -= 1 if today < birth_date + age.years
      age
    end
  end
end
