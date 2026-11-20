# frozen_string_literal: true

module V1
  class MailboxesController < ApplicationController
    before_action :require_tenant!

    rescue_from ArgumentError do |error|
      render_problem(status: :unprocessable_entity, code: "invalid_mailbox", title: error.message)
    end

    rescue_from GoogleSignIn::DomainNotVerified do |error|
      render_problem(status: :unprocessable_entity, code: "unverified_domain",
                     title: "Domain #{error.message} is not verified for this organization")
    end

    def index
      rows = Mailbox.order(:created_at).limit(100)
      render json: { data: rows.map { |m| serialize(m) } }
    end

    def create
      with_idempotency do
        email = mailbox_params.require(:email)
        provider = mailbox_params[:provider].presence || "gmail"
        raise ArgumentError, "unknown_mail_provider" unless Mailbox::PROVIDERS.include?(provider)

        # A Test mailbox keeps mail inside Bigbuck: no domain check, no grant.
        if provider == "sandbox"
          mailbox = Mailbox.create!(kind: mailbox_params[:kind].presence || "personal", email: email,
            user_id: mailbox_params[:user_id], provider: "sandbox", status: "connected", secret_ref: "sandbox://mailbox")
          return render json: serialize(mailbox), status: :created
        end

        secret = mailbox_params[:secret_ref].presence
        demo = Rails.configuration.x.demo_sign_in

        # Production: the domain must be verified and the mailbox stays pending
        # until a real grant (secret_ref) exists. Demo keeps the stub mailbox.
        GoogleSignIn.allow?(email: email) unless demo
        granted = demo || (secret.present? && secret != "sm://demo")

        mailbox = Mailbox.create!(
          kind: mailbox_params[:kind].presence || "shared",
          email: email,
          user_id: mailbox_params[:user_id],
          status: granted ? "connected" : "pending",
          secret_ref: secret || (demo ? "sm://demo" : "sm://pending")
        )
        render json: serialize(mailbox), status: :created
      end
    end

    # Daily sending cap, and pause / resume / disconnect. Only a connected mailbox sends.
    def update
      mailbox = Mailbox.find(params[:id])
      attrs = params.require(:mailbox).permit(:daily_cap, :status)
      changes = {}
      if attrs.key?(:daily_cap)
        cap = Integer(attrs[:daily_cap], exception: false)
        raise ArgumentError, "daily_cap must be between 1 and 10000" unless cap&.between?(1, 10_000)
        changes[:daily_cap] = cap
      end
      if attrs.key?(:status)
        status = attrs[:status].to_s
        raise ArgumentError, "unknown_status" unless %w[connected paused disconnected].include?(status)
        raise ArgumentError, "reconnect_requires_grant" if status == "connected" && mailbox.status == "pending"
        changes[:status] = status
      end
      before = mailbox.attributes.slice(*changes.keys.map(&:to_s))
      mailbox.update!(changes)
      ChangeWriter.call(record: mailbox, action: "mailbox.updated", event_type: "mailbox.updated",
        payload: changes.transform_keys(&:to_s), changes: before.to_h { |key, value| [ key, [ value, mailbox[key] ] ] })
      render json: serialize(mailbox)
    end

    def inbound
      with_idempotency do
        mailbox = Mailbox.find(params[:id])
        person_email = inbound_params.require(:from)
        communication = InboundIngestor.call(
          mailbox: mailbox,
          from: person_email,
          rfc822_message_id: inbound_params[:rfc822_message_id],
          in_reply_to: inbound_params[:in_reply_to],
          kind: inbound_params[:kind].presence || "reply",
          subject: inbound_params[:subject].presence || "Re:",
          body: inbound_params[:body].presence || "",
          thread_id: inbound_params[:thread_id],
          provider_message_id: inbound_params[:provider_message_id].presence || "in-#{SecureRandom.hex(6)}"
        )
        raise ArgumentError, "person_not_found_for_from" if communication.nil?

        render json: {
          "id" => communication.id,
          "person_id" => communication.person_id,
          "direction" => communication.direction,
          "thread_id" => communication.thread_id
        }, status: :created
      end
    end

    # The Test inbox: everything the mailbox sent and received, newest first.
    def messages
      mailbox = Mailbox.find(params[:id])
      raise ArgumentError, "not_a_sandbox_mailbox" unless mailbox.sandbox?

      rows = SandboxMessage.where(mailbox_id: mailbox.id).order(delivered_at: :desc, created_at: :desc).limit(200)
      answered = rows.select { |m| m.direction == "inbound" }.map(&:in_reply_to).compact.to_set
      render json: {
        data: rows.map do |m|
          m.as_json(only: %i[id direction rfc822_message_id in_reply_to thread_id from_address to_address subject delivered_at])
           .merge("answered" => answered.include?(m.rfc822_message_id))
        end
      }
    end

    # Answers a sent message as the candidate would: kind is reply, bounce or auto_reply.
    def simulate
      mailbox = Mailbox.find(params[:id])
      message = SandboxMessage.where(mailbox_id: mailbox.id).find(params.require(:message_id))
      inbound = SandboxInbox.answer!(message: message, kind: params[:kind].presence || "reply", body: params[:body])
      render json: inbound.as_json(only: %i[id direction rfc822_message_id in_reply_to thread_id from_address to_address subject delivered_at]),
             status: :created
    end

    private

    def require_tenant!
      raise Current::TenantRequired, "X-Organization-Id required" if Current.organization_id.blank?
    end

    def mailbox_params
      params.require(:mailbox).permit(:kind, :email, :user_id, :secret_ref, :provider)
    end

    def inbound_params
      params.permit(:from, :subject, :body, :thread_id, :provider_message_id, :rfc822_message_id, :in_reply_to, :kind)
    end

    def serialize(mailbox)
      mailbox.as_json(only: %i[id organization_id kind email user_id status provider daily_cap last_sync_status last_synced_at created_at]).merge(
        "sent_today" => mailbox.daily_send_on == Time.zone.today ? mailbox.daily_send_count : 0
      )
    end
  end
end
