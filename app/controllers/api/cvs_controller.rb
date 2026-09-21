module Api
  class CvsController < ApplicationController
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
      # Le rendu serveur depend d'un Chrome headless, qui peut manquer (pas de
      # buildpack) ou se faire tuer par la limite memoire d'un petit dyno. Ce
      # n'est pas une raison pour priver l'utilisateur de son CV : on le dit au
      # client, qui bascule sur l'impression PDF du navigateur avec exactement
      # le meme HTML et la meme feuille de style.
      Rails.logger.error("CV PDF export failed: #{e.class} — #{e.message}")
      render json: {
        error: "La generation PDF cote serveur a echoue (#{e.class}).",
        fallback: "browser_print"
      }, status: :service_unavailable
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
