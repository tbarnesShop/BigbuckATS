# frozen_string_literal: true

module V1
  class OffersController < ApplicationController
    before_action :require_tenant!, except: %i[public_show public_accept public_decline]

    rescue_from ArgumentError do |error|
      render_problem(status: :unprocessable_entity, code: "invalid_offer", title: error.message)
    end

    def index
      listed = OfferIndex.call(application_id: params[:application_id], status: params[:status].presence)
      render json: {
        data: listed[:rows].map { |offer| serialize(offer) },
        counts: listed[:counts]
      }
    rescue ArgumentError => error
      render_problem(status: :unprocessable_entity, code: "invalid_filter", title: error.message)
    end

    def show
      render json: serialize(ResourceVisibility.offers.includes(:application, :current_version).find(params[:id]))
    end

    def submit
      with_idempotency do
        offer = ResourceVisibility.offers.find(params[:id])
        OfferSubmitter.submit!(offer: offer)
        render json: serialize(offer.reload)
      end
    end

    def approve
      with_idempotency do
        offer = ResourceVisibility.offers.find(params[:id])
        approval = Approval.where(entity_id: offer.id, status: "pending").order(:created_at).first
        raise ArgumentError, "no_pending_approval" unless approval

        override = ActiveModel::Type::Boolean.new.cast(params[:override])
        # Overriding another approver's step is an owner's call, recorded as an override on the approval.
        if override && !actor_owner?
          raise Authenticator::Forbidden.new("override_requires_owner", "Only an organization owner can approve on someone else's behalf.")
        end
        OfferApprover.approve!(
          approval: approval,
          actor_id: Current.actor_id,
          override: override
        )
        render json: serialize(offer.reload)
      end
    end

    CHECKLIST_STATES = {
      "references" => %w[not_started in_progress complete waived],
      "verbal" => %w[not_started made accepted]
    }.freeze

    # Steps a recruiter tracks around the letter: reference checks and the verbal offer.
    def update_checklist
      offer = ResourceVisibility.offers.find(params[:id])
      item = params.require(:item).to_s
      state = params.require(:state).to_s
      raise ArgumentError, "unknown_checklist_item" unless CHECKLIST_STATES.key?(item)
      raise ArgumentError, "invalid_checklist_state" unless CHECKLIST_STATES[item].include?(state)
      note = params[:note].to_s.strip.first(2000).presence
      Offer.transaction do
        offer.lock!
        checklist = (offer.checklist || {}).deep_dup
        previous = checklist.dig(item, "state")
        checklist[item] = { "state" => state, "note" => note, "updated_at" => Time.current.iso8601,
                            "updated_by_user_id" => Current.actor_id }.compact
        offer.update!(checklist: checklist, version: offer.version + 1)
        ChangeWriter.call(record: offer, action: "offer.checklist_updated", event_type: "offer.updated",
          payload: { "item" => item, "state" => state }, changes: { "checklist.#{item}" => [ previous, state ] })
      end
      render json: serialize(offer.reload)
    end

    # The candidate answered outside the signed link (phone, email, in person); a recruiter records it.
    def record_response
      with_idempotency do
        offer = ResourceVisibility.offers.find(params[:id])
        result = OfferAcceptance.record!(
          offer: offer,
          response: params.require(:response).to_s,
          actor_id: Current.actor_id,
          note: params[:note].presence
        )
        render json: { "id" => offer.id, "status" => result.offer.status, "hired" => result.hired }, status: :created
      end
    end

    def send_letter
      with_idempotency do
        offer = ResourceVisibility.offers.find(params[:id])
        template = if params[:template_key].present?
                     OfferTemplate.find_by!(key: params[:template_key])
        else
                     OfferTemplate.order(:created_at).first ||
                       OfferTemplate.create!(
                         key: "default",
                         name: "Default",
                         body: "Dear {{ candidate.display_name }}, we are pleased to offer you the {{ job.title }} role."
                       )
        end
        to_email = params[:to_email].presence || offer.application.person.primary_email
        raise ArgumentError, "to_email_required" if to_email.blank?

        sent = OfferSender.call(offer: offer, template: template, to_email: to_email)
        render json: serialize(offer.reload).merge(
          "send" => {
            "token" => sent.token,
            "signature_request_id" => sent.signature_request.id,
            "to_email" => to_email
          }
        )
      end
    end

    # A fresh candidate link for an offer already sent: same letter, same expiry, same open request.
    def resend
      with_idempotency do
        offer = ResourceVisibility.offers.find(params[:id])
        raise ArgumentError, "not_sent" unless offer.status == "sent"

        request_row = SignatureRequest.where(offer_version: offer.current_version).order(created_at: :desc).first
        raise ArgumentError, "link_not_usable" unless request_row&.usable?

        ChangeWriter.call(
          record: offer, action: "offer.resent", event_type: "offer.resent",
          payload: { "signature_request_id" => request_row.id, "to" => request_row.sent_to_email }, changes: {}
        )
        render json: serialize(offer.reload).merge(
          "send" => {
            "token" => SignatureRequestToken.issue(request_row),
            "signature_request_id" => request_row.id,
            "to_email" => request_row.sent_to_email
          }
        )
      end
    end

    def rescind
      with_idempotency do
        offer = ResourceVisibility.offers.find(params[:id])
        reason = params.require(:reason_key)
        OfferRescinder.call(offer: offer, reason_key: reason)
        render json: serialize(offer.reload)
      end
    end

    def public_show
      request_row = SignatureRequestToken.verify(params[:token])
      Current.organization_id = request_row.organization_id
      version = request_row.offer_version
      letter = version.offer_documents.find_by(kind: "letter")
      org = Organization.find(request_row.organization_id)
      render json: {
        "status" => version.offer.status,
        "expires_at" => request_row.expires_at,
        "letter_html" => letter&.body_html,
        "usable" => request_row.usable?,
        "demo" => DemoSandbox.for_organization(org.id).present?,
        "can_accept" => !DemoSandbox.for_organization(org.id) || Rails.configuration.x.demo_candidate_writes,
        "can_decline" => !DemoSandbox.for_organization(org.id) || Rails.configuration.x.demo_candidate_writes,
        "organization" => { "name" => org.name, "slug" => org.slug }
      }
    end

    def public_accept
      block_demo_public_write!(SignatureRequestToken.verify(params[:token]).organization_id, action: "accept")
      result = OfferAcceptance.accept!(
        token: params[:token],
        ip_address: request.remote_ip,
        user_agent: request.user_agent,
        typed_name: params[:typed_name]
      )
      render json: { "status" => result.offer.status, "hired" => result.hired }
    end

    def public_decline
      block_demo_public_write!(SignatureRequestToken.verify(params[:token]).organization_id, action: "decline")
      result = OfferAcceptance.decline!(
        token: params[:token],
        reason_key: params[:reason_key],
        ip_address: request.remote_ip,
        user_agent: request.user_agent
      )
      render json: { "status" => result.offer.status, "hired" => false }
    end

    private

    def require_tenant!
      raise Current::TenantRequired, "X-Organization-Id required" if Current.organization_id.blank?
    end

    def serialize(offer)
      pending = Approval.where(entity_id: offer.id, status: "pending").order(:created_at).map { |a|
        a.as_json(only: %i[id status approver_user_id step_position created_at])
      }
      offer.as_json(only: %i[id organization_id application_id status current_version_id version created_at updated_at])
         .merge(
           "fields" => OfferFieldPolicy.for_current(offer.current_version&.fields),
           # Terms exist but this role may not see compensation (offer.view_compensation).
           "terms_hidden" => offer.current_version&.fields.present? && OfferFieldPolicy.for_current(offer.current_version.fields).empty?,
           "application" => offer.application&.as_json(only: %i[id job_id person_id status current_stage_key]),
           "pending_approvals" => pending,
           "approvals" => approval_history(offer),
           "checklist" => offer.checklist || {},
           "can_override" => pending.any? && actor_owner? && pending.none? { |a| a["approver_user_id"] == Current.actor_id }
         )
    end

    def approval_history(offer)
      return [] unless offer.current_version_id
      rows = Approval.where(entity_id: offer.id, entity_version_id: offer.current_version_id).order(:step_position, :created_at).to_a
      names = User.where(id: rows.flat_map { |a| [ a.approver_user_id, a.approved_by_user_id ] }.compact.uniq).pluck(:id, :name).to_h
      rows.map do |a|
        a.as_json(only: %i[id status step_position approved_at is_override reason]).merge(
          "approver_name" => names[a.approver_user_id], "approved_by_name" => names[a.approved_by_user_id]
        )
      end
    end

    def actor_owner?
      return false if Current.actor_id.blank? || Current.agent_id.present?
      @actor_owner ||= Membership.includes(:role).find_by(user_id: Current.actor_id, status: "active")&.role&.key == "owner"
    end
  end
end
