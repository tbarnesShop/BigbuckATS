# frozen_string_literal: true

module IdempotentRequest
  extend ActiveSupport::Concern
  private

  def with_idempotency
    raw = request.headers["Idempotency-Key"].presence
    return yield if raw.blank? || !request.request_method.in?(%w[POST PUT PATCH])
    raise IdempotencyStore::Conflict, "key_too_long" if raw.bytesize > 255
    principal = Current.principal
    actor = [ Current.actor_type, Current.actor_id, Current.agent_id, Current.credential_id,
      principal.respond_to?(:permissions) ? principal.permissions.to_a.sort : [] ]
    key = Digest::SHA256.hexdigest([ raw, actor ].to_json)
    fingerprint = Digest::SHA256.hexdigest([ request.request_method, request.path, request.query_string, canonical_request(request.request_parameters) ].to_json)
    Organization.find(Current.organization_id).with_lock do
      existing = IdempotencyKey.find_by(key: key)
      if existing
        raise IdempotencyStore::Conflict, "request_changed" unless existing.request_fingerprint == fingerprint
        raise IdempotencyStore::Conflict, "response_no_longer_available" unless replay_visible?(existing.response_body)
        return render json: existing.response_body, status: existing.response_status
      end
      yield
      if response.successful?
        body = JSON.parse(response.body.presence || "{}")
        # One-time credentials must never become replayable plaintext caches.
        body = { "_replay_unavailable" => true } if body.to_json.match?(/"(?:token|signing_secret|secret)"\s*:/)
        IdempotencyKey.create!(key: key, request_path: request.path, request_method: request.request_method,
          request_fingerprint: fingerprint, response_status: response.status, response_body: body)
      else
        raise ActiveRecord::Rollback
      end
    end
  rescue IdempotencyStore::Conflict => error
    render_problem(status: :conflict, code: "idempotency_conflict", title: error.message)
  end

  def canonical_request(value)
    case value
    when Hash then value.sort.to_h.transform_values { |child| canonical_request(child) }
    when Array then value.map { |child| canonical_request(child) }
    when ActionDispatch::Http::UploadedFile
      { filename: value.original_filename, content_type: value.content_type, size: value.size,
        checksum: Digest::SHA256.file(value.tempfile.path).hexdigest }
    else value
    end
  end

  def replay_visible?(body)
    return false unless body.is_a?(Hash) && !body["_replay_unavailable"]
    scope = case controller_name
    when "documents"
      return ResourceVisibility.people.exists?(id: params[:person_id]) && Document.exists?(id: body["id"], person_id: params[:person_id])
    when "people" then ResourceVisibility.people
    when "applications" then ResourceVisibility.applications
    when "jobs" then ResourceVisibility.jobs
    when "projects" then ResourceVisibility.projects
    when "project_members" then ResourceVisibility.members
    when "referrals" then ResourceVisibility.referrals
    when "offers" then ResourceVisibility.offers
    end
    return true unless scope
    id = params[:id].presence || body["id"]
    id.present? && scope.exists?(id: id)
  end
end
