# frozen_string_literal: true

# Creates credentials. The plaintext token is returned once and never stored.
class CredentialIssuer
  Issued = Struct.new(:credential, :token, keyword_init: true)

  PREFIX = {
    "personal" => "bb_live_",
    "integration" => "bb_live_",
    "agent" => "bb_live_",
    "session" => "bb_sess_",
    "handoff" => "bb_hand_"
  }.freeze

  SESSION_TTL = 12.hours
  DEMO_SESSION_TTL = 2.hours
  HANDOFF_TTL = 2.minutes

  def self.call(...)
    new(...).call
  end

  def initialize(kind:, name:, user: nil, agent: nil, scopes: [], expires_at: nil, created_by: nil, audit: true)
    @kind = kind.to_s
    @name = name
    @user = user
    @agent = agent
    @scopes = scopes
    @expires_at = expires_at
    @created_by = created_by
    @audit = audit
  end

  def call
    token = "#{PREFIX.fetch(@kind)}#{SecureRandom.alphanumeric(40)}"
    credential = ApiCredential.new(
      kind: @kind, name: @name, user_id: @user&.id, agent_id: @agent&.id,
      scopes: @scopes, expires_at: @expires_at, created_by_user_id: @created_by&.id,
      token_prefix: token[0, 12], token_digest: ApiCredential.digest(token),
      api_version: ApiCredential::CURRENT_API_VERSION
    )

    if @audit
      ChangeWriter.call(
        record: credential,
        action: "#{@kind == 'session' ? 'session' : 'api_credential'}.created",
        event_type: nil,
        changes: {
          "kind" => [ nil, @kind ], "name" => [ nil, @name ], "scopes" => [ nil, credential.scopes ],
          "user_id" => [ nil, @user&.id ], "agent_id" => [ nil, @agent&.id ], "expires_at" => [ nil, @expires_at ]
        }
      )
    else
      credential.save!
    end

    Issued.new(credential: credential, token: token)
  end

  # Exchanges a one-time handoff code for a session. Single use.
  def self.redeem_handoff!(code)
    return nil unless code.to_s.match?(ApiCredential::TOKEN_PATTERN)

    ApiCredential.transaction do
      handoff = ApiCredential.unscoped.lock.find_by(token_digest: ApiCredential.digest(code), kind: "handoff")
      next nil unless handoff&.usable?

      Current.organization_id = handoff.organization_id
      handoff.update_columns(status: "used", revoked_at: Time.current, version: handoff.version + 1, updated_at: Time.current)
      user = User.find(handoff.user_id)
      Current.actor_id = user.id
      Current.actor_type = "user"
      call(kind: "session", name: "Google sign-in", user: user, expires_at: SESSION_TTL.from_now, created_by: user)
    end
  end
end
