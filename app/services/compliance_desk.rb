# frozen_string_literal: true

# Compliance operations exposed through REST and GraphQL: data-subject
# requests, consent records and legal holds. Every change goes through
# ChangeWriter, so each one is audited and emitted as an event.
class ComplianceDesk
  class Error < StandardError
    attr_reader :code

    def initialize(code, message = code)
      @code = code
      super(message)
    end
  end

  DEFAULT_DUE_DAYS = 30

  class << self
    # Fulfilling an access request exports data; an erasure erases it.
    def fulfil_permission(request)
      { "access" => "person.export", "erasure" => "person.erase" }.fetch(request.kind, "compliance.manage")
    end

    def open_request!(kind:, requester_email:, person: nil, received_at: nil, due_at: nil)
      received_at ||= Time.current
      policy = person ? CompliancePolicyMatcher.call(person: person).max_by(&:priority) : nil
      request = DataRequest.new(
        kind: kind.to_s, person: person, requester_email: requester_email, received_at: received_at,
        due_at: due_at || (received_at + due_days(policy).days), status: "open",
        assigned_user_id: Current.actor_id, compliance_policy_id: policy&.id
      )
      ChangeWriter.call(record: request, action: "data_request.opened", event_type: "data_request.opened",
                        payload: { "kind" => request.kind, "person_id" => person&.id, "due_at" => request.due_at })
      request
    end

    # Fulfils a request. access -> the access packet; erasure -> PersonEraser
    # (legal holds refuse); correction -> marked done after the edit was made.
    def complete_request!(request, outcome_note: nil, erase_mode: "delete")
      raise Error.new("not_open", "Request is #{request.status}") unless request.status == "open"

      result =
        case request.kind
        when "access"
          raise Error.new("person_required", "Link the request to a person first") unless request.person

          AccessPacket.build(person: request.person)
        when "erasure"
          raise Error.new("person_required", "Link the request to a person first") unless request.person

          PersonEraser.call(person: request.person, mode: erase_mode) unless request.person.reload.erased?
          verification = PersonEraser.verify(request.person)
          raise Error.new("cleanup_pending", "Storage cleanup must finish before completing this request") if verification.any?
          { "erased" => true, "verify" => verification }
        else
          {}
        end
      close!(request, "completed", outcome_note)
      [ request, result ]
    rescue PersonEraser::Held
      raise Error.new("legal_hold", "This person is under a legal hold")
    end

    def reject_request!(request, outcome_note:)
      raise Error.new("not_open", "Request is #{request.status}") unless request.status == "open"

      close!(request, "rejected", outcome_note)
      request
    end

    # Consents are append-only: a withdrawal is a new row, never an edit.
    def record_consent!(person:, purpose_key:, status:, captured_via: "api", expires_at: nil)
      purpose = ConsentPurpose.find_by(key: purpose_key)
      raise Error.new("unknown_purpose", "No consent purpose #{purpose_key}") unless purpose
      raise Error.new("invalid_status", "status must be granted or withdrawn") unless %w[granted withdrawn].include?(status.to_s)

      consent = Consent.new(
        person: person, consent_purpose: purpose, lawful_basis: purpose.lawful_basis, status: status.to_s,
        captured_via: captured_via, captured_at: Time.current, expires_at: expires_at,
        evidence_json: { "actor_type" => Current.actor_type, "surface" => Current.source_surface }.compact,
        created_at: Time.current
      )
      ChangeWriter.call(record: consent, action: "consent.#{status}", event_type: "consent.#{status}",
                        payload: { "person_id" => person.id, "purpose" => purpose.key })
      consent
    end

    def place_hold!(subject_type:, subject_id:, reason:)
      raise Error.new("user_required", "A legal hold is placed by a person") if Current.actor_id.blank?

      model = { "person" => Person, "application" => Application, "job" => Job }[subject_type.to_s]
      raise Error.new("invalid_subject", "subject_type must be person, application or job") unless model

      hold = LegalHold.new(subject_type: subject_type.to_s, subject_id: model.find(subject_id).id, reason: reason,
                           placed_by_user_id: Current.actor_id, placed_at: Time.current)
      ChangeWriter.call(record: hold, action: "legal_hold.placed", event_type: "legal_hold.placed",
                        payload: { "subject_type" => hold.subject_type, "subject_id" => hold.subject_id })
      hold
    end

    def release_hold!(hold)
      raise Error.new("already_released", "Hold already released") unless hold.active?
      raise Error.new("user_required", "A legal hold is released by a person") if Current.actor_id.blank?

      hold.assign_attributes(released_by_user_id: Current.actor_id, released_at: Time.current)
      ChangeWriter.call(record: hold, action: "legal_hold.released", event_type: "legal_hold.released",
                        payload: { "subject_type" => hold.subject_type, "subject_id" => hold.subject_id })
      hold
    end

    private

    def close!(request, status, outcome_note)
      request.assign_attributes(status: status, completed_at: Time.current, outcome_note: outcome_note)
      ChangeWriter.call(record: request, action: "data_request.#{status}", event_type: "data_request.#{status}",
                        payload: { "kind" => request.kind, "person_id" => request.person_id })
    end

    def due_days(policy)
      raw = policy&.requirements.to_h.dig("dataRequests", "respondWithin")
      return DEFAULT_DUE_DAYS if raw.blank?
      return raw.to_i if raw.is_a?(Integer)

      match = raw.to_s.match(/\A(\d+)\s*d\z/i)
      match ? match[1].to_i : DEFAULT_DUE_DAYS
    end
  end
end
