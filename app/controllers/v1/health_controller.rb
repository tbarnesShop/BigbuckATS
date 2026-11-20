# frozen_string_literal: true

module V1
  class HealthController < ApplicationController
    def show
      render json: { status: "ok", service: "bigbuck-api" }
    end
  end
end
