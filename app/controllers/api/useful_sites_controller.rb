module Api
  class UsefulSitesController < ApplicationController
    protect_from_forgery with: :null_session

    def index
      @useful_sites = UsefulSite.ordered
      render json: @useful_sites
    end

    def create
      @useful_site = UsefulSite.new(useful_site_params)
      if @useful_site.save
        render json: @useful_site, status: :created
      else
        render json: { errors: @useful_site.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def update
      @useful_site = UsefulSite.find(params[:id])
      if @useful_site.update(useful_site_params)
        render json: @useful_site
      else
        render json: { errors: @useful_site.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def destroy
      @useful_site = UsefulSite.find(params[:id])
      @useful_site.destroy
      head :no_content
    end

    def fetch_meta
      require "net/http"
      require "nokogiri"

      url = params[:url]
      return render(json: { description: "" }) if url.blank?

      uri = URI.parse(url)
      return render(json: { description: "" }) unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)

      response = Net::HTTP.get_response(uri)
      doc = Nokogiri::HTML(response.body)

      description = doc.at('meta[name="description"]')&.[]("content") ||
                    doc.at('meta[property="og:description"]')&.[]("content") ||
                    ""

      render json: { description: description.truncate(300) }
    rescue StandardError
      render json: { description: "" }
    end

    private

    def useful_site_params
      params.require(:useful_site).permit(:name, :url, :description, :category)
    end
  end
end
