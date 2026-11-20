# frozen_string_literal: true

module V1
  class PeopleController < ApplicationController
    before_action :require_tenant!

    rescue_from ArgumentError do |error|
      render_problem(status: :unprocessable_entity, code: "invalid_people", title: error.message)
    end

    def index
      limit = [ [ (params[:limit] || 100).to_i, 1 ].max, 500 ].min
      page = [ params[:page].to_i, 1 ].max
      people = PersonSearch.call(viewer: current_membership, filters: search_filters, limit: limit, offset: (page - 1) * limit)
      owners = User.where(id: people.filter_map(&:owner_user_id).uniq).index_by(&:id)
      total = PersonSearch.count(viewer: current_membership, filters: search_filters)
      render json: { data: people.map { |p| serialize(p, owners) }, filters: search_filters,
                     meta: { "page" => page, "per_page" => limit, "total" => total } }
    end

    def create
      with_idempotency do
        result = PersonMatcher.find_or_create(
          display_name: person_params[:display_name],
          email: person_params[:email],
          phone: person_params[:phone],
          viewer: current_membership,
          source: person_params[:source].presence || (Current.actor_type == "agent" ? "agent" : "sourced"),
          source_detail: person_params[:source_detail]
        )

        unless result.attached
          ChangeWriter.call(
            record: result.person,
            action: "person.created",
            event_type: "person.created",
            payload: { "display_name" => result.person.display_name },
            changes: { "display_name" => [ nil, result.person.display_name ] }
          )
        end

        crm_attrs = person_params.to_h.slice(*CRM_FIELDS)
        if person_params[:owner_user_id].present? || person_params.key?(:do_not_contact) || crm_attrs.any?
          attrs = crm_attrs.symbolize_keys
          ensure_manual_engagement!(attrs[:engagement_status])
          attrs[:owner_user_id] = person_params[:owner_user_id] if person_params[:owner_user_id].present?
          if person_params.key?(:do_not_contact)
            attrs[:do_not_contact] = ActiveModel::Type::Boolean.new.cast(person_params[:do_not_contact])
            attrs[:do_not_contact_reason] = person_params[:do_not_contact_reason]
          end
          result.person.update!(attrs) if attrs.any?
        end

        render json: serialize(result.person.reload).merge(
          "attached" => result.attached,
          "held_duplicate" => result.held_duplicate
        ), status: result.attached ? :ok : :created
      end
    end

    def show
      person = Person.find(params[:id])
      unless PersonVisibility.visible?(person, viewer: current_membership)
        raise ActiveRecord::RecordNotFound
      end

      render json: serialize(person)
    end

    def update
      with_idempotency do
        person = visible_person!
        if (params.require(:person).keys - %w[display_name email phone affiliation]).any?
          require_permission!("person.update")
        end
        attrs = {}
        attrs[:owner_user_id] = params[:person][:owner_user_id] if params.dig(:person, :owner_user_id)
        if params[:person]&.key?(:do_not_contact)
          attrs[:do_not_contact] = ActiveModel::Type::Boolean.new.cast(params[:person][:do_not_contact])
          attrs[:do_not_contact_reason] = params[:person][:do_not_contact_reason]
        end
        attrs[:lifecycle_stage] = params[:person][:lifecycle_stage] if params.dig(:person, :lifecycle_stage).present?
        CRM_FIELDS.each { |field| attrs[field.to_sym] = params[:person][field].presence if params[:person]&.key?(field) }
        ensure_manual_engagement!(attrs[:engagement_status])
        edits = params.require(:person).permit(:display_name, :email, :phone, affiliation: %i[id company_id title]).to_h
        PersonDetailsUpdater.call(person: person, attributes: attrs.merge(edits))
        render json: serialize(person.reload)
      end
    end

    def bulk
      with_idempotency do
        result = PeopleBulkAction.call(
          viewer: current_membership,
          action: params.require(:bulk_action),
          person_ids: Array(params[:person_ids]),
          params: params.permit(:sequence_id, :mailbox_id, :project_id, :reason, :tag_id, :tag_name).to_h
        )
        render json: result
      end
    end

    def list_communications
      person = visible_person!
      rows = Communication.where(person_id: person.id).order(created_at: :desc).limit(50)
      render json: {
        data: rows.map { |row|
          row.as_json(only: %i[id person_id direction channel subject body status message_type created_at])
        }
      }
    end

    def timeline
      person = visible_person!
      events = TimelineEvent.where(person_id: person.id).order(occurred_at: :desc).limit(100)
      render json: {
        data: events.map { |e|
          e.as_json(only: %i[id person_id event_type payload occurred_at created_at])
        }
      }
    end

    # The merged stream the person page renders: emails, notes, tasks, tags, stage moves.
    def feed
      person = visible_person!
      render json: { data: PersonFeed.call(person: person) }
    end

    # Renders a template (or the typed subject/body) for this person so the composer can show
    # exactly what will go out. Nothing is sent.
    def preview_message
      person = visible_person!
      subject, body = compose_message(person)
      render json: { subject: subject, body: body, tokens: MessageTokens::NAMES }
    rescue MessageRenderer::MissingToken => error
      render_problem(status: :unprocessable_entity, code: "unknown_token", title: "Unknown merge field: #{error.message}")
    rescue ArgumentError => error
      render_problem(status: :unprocessable_entity, code: "invalid_communication", title: error.message)
    end

    def create_communication
      with_idempotency do
        person = visible_person!
        mailbox = resolve_mailbox!
        subject, body = compose_message(person, mailbox: mailbox)
        communication = MessageSender.send_now!(
          mailbox: mailbox,
          person: person,
          subject: subject,
          body: body,
          message_type: params[:message_type].presence || "outreach",
          thread_id: params[:thread_id].presence,
          in_reply_to: params[:in_reply_to].presence
        )
        render json: communication.as_json(
          only: %i[id person_id mailbox_id direction channel subject body status message_type created_at]
        ), status: :created
      end
    rescue MessageRenderer::MissingToken => error
      render_problem(status: :unprocessable_entity, code: "unknown_token", title: "Unknown merge field: #{error.message}")
    rescue ConsentGate::Blocked => error
      render_problem(status: :forbidden, code: "consent_blocked", title: error.message)
    rescue ArgumentError => error
      render_problem(status: :unprocessable_entity, code: "invalid_communication", title: error.message)
    end

    def erase
      with_idempotency do
        person = visible_person!
        PersonEraser.call(person: person, mode: params[:mode].presence || "delete")
        verification = PersonEraser.verify(person)
        render json: { "id" => person.id, "erased" => verification.empty?, "cleanup_pending" => verification.include?("file_cleanup_pending"), "verify" => verification }
      end
    rescue PersonEraser::Held => error
      render_problem(status: :forbidden, code: "legal_hold", title: error.message)
    rescue PersonEraser::Error, ArgumentError => error
      render_problem(status: :unprocessable_entity, code: "erase_failed", title: error.message)
    end

    CRM_FIELDS = %w[headline current_title current_company_id city time_zone engagement_status].freeze

    private

    # Subject and body for a one-off email: from a template when template_key is given (merge fields
    # filled in for this person), otherwise exactly what was typed. Typed text may use merge fields too.
    def compose_message(person, mailbox: nil)
      subject = params[:subject].to_s
      body = params[:body].to_s
      if params[:template_key].present?
        template = MessageTemplate.active.find_by!(key: params[:template_key])
        subject = subject.presence || template.subject
        body = body.presence || template.body
      end
      raise ArgumentError, "subject and body are required" if subject.blank? || body.blank?

      sender = mailbox&.user || User.find_by(id: Current.actor_id)
      tokens = MessageTokens.for(person: person, sender: sender, sender_email: mailbox&.email)
      [ MessageRenderer.render(subject, tokens, escape: false), MessageRenderer.render(body, tokens, escape: false) ]
    end

    def ensure_manual_engagement!(value)
      return if value.blank? || Person::MANUAL_ENGAGEMENT.include?(value)

      raise ArgumentError, "engagement_status must be one of #{Person::MANUAL_ENGAGEMENT.join(', ')}"
    end

    def search_filters
      params.permit(
        :q, :lifecycle_stage, :visibility, :do_not_contact, :owner_user_id, :project_id, :sort,
        :tag, :not_tag, :source, :engagement_status, :location, :title, :company, :not_contacted_days,
        :contacted_within_days, :has_email, custom: {}
      ).to_h
    end

    def visible_person!
      person = Person.find(params[:id])
      unless PersonVisibility.visible?(person, viewer: current_membership)
        raise ActiveRecord::RecordNotFound
      end
      person
    end

    def resolve_mailbox!
      if params[:mailbox_id].present?
        Mailbox.find(params[:mailbox_id])
      else
        Mailbox.where(status: "connected").order(:created_at).first || demo_mailbox!
      end
    end

    def demo_mailbox!
      raise ArgumentError, "mailbox_required" unless Rails.configuration.x.demo_sign_in

      Mailbox.create!(
        kind: "shared",
        email: "recruiting@#{Organization.find(Current.organization_id).slug}.test",
        status: "connected",
        secret_ref: "sm://auto"
      )
    end

    def require_tenant!
      raise Current::TenantRequired, "X-Organization-Id required" if Current.organization_id.blank?
    end

    def current_membership
      return @current_membership if defined?(@current_membership)

      @current_membership =
        if current_principal
          PrincipalViewer.new(current_principal)
        elsif Current.actor_id.present?
          Membership.find_by(user_id: Current.actor_id, status: "active")
        end
    end

    def person_params
      params.require(:person).permit(
        :display_name, :email, :phone, :owner_user_id, :do_not_contact, :do_not_contact_reason, :lifecycle_stage,
        :source, :source_detail, *CRM_FIELDS
      )
    end

    def serialize(person, owners = nil)
      owner = if owners
                owners[person.owner_user_id]
      elsif person.owner_user_id.present?
                User.find_by(id: person.owner_user_id)
      end
      person.as_json(
        only: %i[
          id organization_id display_name primary_email primary_phone lifecycle_stage visibility
          do_not_contact do_not_contact_reason owner_user_id version created_at updated_at
          headline current_title current_company_id city time_zone source source_detail sourced_by_user_id sourced_at
          last_contacted_at last_replied_at last_activity_at engagement_status
        ]
      ).merge("owner" => owner&.as_json(only: %i[id name email]))
    end
  end
end
