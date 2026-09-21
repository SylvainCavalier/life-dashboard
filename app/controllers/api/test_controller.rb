module Api
  class TestController < ApplicationController
    def index
      render json: {
        ok: true,
        message: 'Test endpoint works',
        time: Time.current
      }
    end
  end
end


