# frozen_string_literal: true

module V1
  class CommunicationsController < ApplicationController
    include PersonScoped

    before_action :require_tenant!

    rescue_from ArgumentError do |error|
      render_problem(status: :unprocessable_entity, code: "invalid_classification", title: error.message)
    end

    # Reclassify an inbound message (a recruiter or an agent correcting the first-pass label).
    def update
      with_idempotency do
        communication = Communication.find(params[:id])
        visible_person!(communication.person_id)
        raise ArgumentError, "inbound_only" unless communication.direction == "inbound"

        label = params.require(:communication).require(:classification)
        raise ArgumentError, "unknown_classification" unless ReplyClassifier::OVERRIDABLE.include?(label)

        ReplyClassifier.apply!(communication, label)
        render json: communication.as_json(only: %i[id person_id direction subject classification created_at])
      end
    end

    private

    def require_tenant!
      raise Current::TenantRequired, "X-Organization-Id required" if Current.organization_id.blank?
    end
  end
end
