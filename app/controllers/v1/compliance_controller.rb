# frozen_string_literal: true

module V1
  # Data-subject requests, consents, access exports and legal holds.
  class ComplianceController < ApplicationController
    before_action :require_tenant!

    rescue_from ComplianceDesk::Error do |error|
      status = error.code == "legal_hold" ? :forbidden : :unprocessable_entity
      render_problem(status: status, code: error.code, title: error.message)
    end

    # GET /v1/data_requests?status=open
    def data_requests
      scope = DataRequest.order(:due_at)
      scope = scope.where(status: params[:status]) if params[:status].present?
      render json: { data: scope.limit(200).map { |r| serialize_request(r) } }
    end

    # POST /v1/data_requests { kind, person_id?, requester_email, received_at?, due_at? }
    def create_data_request
      with_idempotency do
        person = params[:person_id].present? ? visible_person!(params[:person_id]) : nil
        request = ComplianceDesk.open_request!(
          kind: params.require(:kind), person: person, requester_email: params.require(:requester_email),
          received_at: params[:received_at].presence && Time.iso8601(params[:received_at]),
          due_at: params[:due_at].presence && Time.iso8601(params[:due_at])
        )
        render json: serialize_request(request), status: :created
      end
    end

    # POST /v1/data_requests/:id/complete { outcome_note?, erase_mode? }
    def complete_data_request
      data_request = DataRequest.find(params[:id])
      require_permission!(ComplianceDesk.fulfil_permission(data_request))
      request, result = ComplianceDesk.complete_request!(
        data_request, outcome_note: params[:outcome_note], erase_mode: params[:erase_mode].presence || "delete"
      )
      render json: serialize_request(request).merge("result" => result)
    end

    # POST /v1/data_requests/:id/reject { outcome_note }
    def reject_data_request
      request = ComplianceDesk.reject_request!(DataRequest.find(params[:id]), outcome_note: params.require(:outcome_note))
      render json: serialize_request(request)
    end

    # GET /v1/people/:id/access_packet
    def access_packet
      person = visible_person!(params[:id])
      ChangeWriter.call(record: person, action: "person.access_exported", event_type: nil, changes: { "export" => [ nil, "access_packet" ] })
      render json: AccessPacket.build(person: person)
    end

    # GET /v1/people/:id/consents
    def consents
      person = visible_person!(params[:id])
      rows = Consent.where(person_id: person.id).includes(:consent_purpose).order(captured_at: :desc)
      render json: { data: rows.map { |c| serialize_consent(c) } }
    end

    # POST /v1/people/:id/consents { purpose_key, status, expires_at? }
    def record_consent
      person = visible_person!(params[:id])
      consent = ComplianceDesk.record_consent!(
        person: person, purpose_key: params.require(:purpose_key), status: params.require(:status),
        captured_via: Current.source_surface || "api", expires_at: params[:expires_at].presence && Time.iso8601(params[:expires_at])
      )
      render json: serialize_consent(consent), status: :created
    end

    # GET /v1/legal_holds?active=true
    def legal_holds
      scope = LegalHold.order(placed_at: :desc)
      scope = scope.active if ActiveModel::Type::Boolean.new.cast(params[:active])
      render json: { data: scope.limit(200).map { |h| serialize_hold(h) } }
    end

    # POST /v1/legal_holds { subject_type, subject_id, reason }
    def create_legal_hold
      hold = ComplianceDesk.place_hold!(subject_type: params.require(:subject_type), subject_id: params.require(:subject_id),
                                        reason: params.require(:reason))
      render json: serialize_hold(hold), status: :created
    end

    # POST /v1/legal_holds/:id/release
    def release_legal_hold
      render json: serialize_hold(ComplianceDesk.release_hold!(LegalHold.find(params[:id])))
    end

    private

    def require_tenant!
      raise Current::TenantRequired, "X-Organization-Id required" if Current.organization_id.blank?
    end

    def visible_person!(id)
      person = Person.find(id)
      viewer = current_principal ? PrincipalViewer.new(current_principal) : Membership.find_by(user_id: Current.actor_id, status: "active")
      raise ActiveRecord::RecordNotFound unless current_principal.nil? && viewer.nil? || PersonVisibility.visible?(person, viewer: viewer)

      person
    end

    def serialize_request(request)
      request.as_json(only: %i[id kind person_id requester_email received_at due_at status completed_at assigned_user_id outcome_note created_at])
    end

    def serialize_consent(consent)
      {
        "id" => consent.id, "purpose" => consent.consent_purpose&.key, "status" => consent.status,
        "lawful_basis" => consent.lawful_basis, "captured_via" => consent.captured_via,
        "captured_at" => consent.captured_at, "expires_at" => consent.expires_at, "granted" => consent.granted?
      }
    end

    def serialize_hold(hold)
      hold.as_json(only: %i[id subject_type subject_id reason placed_by_user_id placed_at released_by_user_id released_at])
          .merge("active" => hold.active?)
    end
  end
end
