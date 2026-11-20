# Provider-neutral API OAuth

Big Buck uses an external OAuth/OIDC provider for API access. Rails verifies
access tokens with the maintained `jwt` gem; the CLI uses `openid-client` for
protocol handling and the native OS keychain for human credentials. Big Buck
has no authorization server, custom signing keys, or password grant.

## Provider requirements

Register an API resource and two separate clients as needed:

- A **public native client** with authorization code, mandatory S256 PKCE,
  OIDC, offline access, and refresh-token rotation/reuse detection. Register
  `http://127.0.0.1:<port>/oauth/callback`. Use the provider's native loopback
  port policy, or set `BIGBUCK_OAUTH_CALLBACK_PORT` to a registered fixed port.
  Do not give a native client a client secret. Require MFA through provider policy.
- A **confidential service client** with client credentials and
  `client_secret_basic`. Restrict its granted API scopes to the job's needs.
  Inject its secret from your deployment secret manager; rotate it there.
  Do not give a scheduled job a human refresh token.

The provider must support HTTPS discovery, HTTPS token/JWKS endpoints, signed
RS256 ID tokens for native login, and a revocation endpoint for logout. Configure
RS256 JWT API access tokens with RSA keys of at least 2048 bits, a maximum
15-minute lifetime, `typ: at+jwt`, and claims `iss`, `aud`, `sub`, `client_id`,
`iat`, `exp`, and a space-delimited `scope`. Opaque access tokens/introspection
and other signing algorithms are not supported by this implementation.

The **API audience must differ from the OAuth client ID**. Google OIDC login
ID tokens are not API access tokens. Providers that use `azp` for the authorized
client can explicitly set the claim override below. A provider using JWT access
tokens with `typ: JWT` needs the explicit type override; audience, signature,
issuer, lifetime, scopes, and local binding are still verified.

## Rails configuration

```dotenv
BIGBUCK_OAUTH_ISSUER=https://identity.example.com/
BIGBUCK_OAUTH_AUDIENCE=https://api.bigbuck.example.com
BIGBUCK_OAUTH_JWKS_URI=https://identity.example.com/.well-known/jwks.json
# Optional provider-specific overrides:
# BIGBUCK_OAUTH_CLIENT_ID_CLAIM=azp
# BIGBUCK_OAUTH_ACCESS_TOKEN_TYP=JWT
# BIGBUCK_OAUTH_MAX_TOKEN_SECONDS=600
```

Copy the issuer **exactly** from provider discovery, including trailing slash.
Use a trusted administrator-configured JWKS URL. Token-supplied `jku`, `x5u`,
email, roles, and tenant claims cannot select keys or provision an identity.
Keep HTTPS certificate verification enabled. Rails rejects key redirects,
oversized/malformed key sets, unsigned tokens, unsupported algorithms, unknown
keys, incorrect audience/type, future issuance, and expired tokens (30 seconds
of clock tolerance). Lifetime configuration may only tighten the 900-second cap.
Synchronize host clocks.

Signing keys cache for five minutes per Rails process, with an unknown-key
refresh limited to once per 30 seconds. Publish new keys before issuing tokens
with them; retain old public keys until old tokens expire. Provider key removal
can take up to the cache TTL to take effect. A failed refresh fails authentication
closed; monitor authentication errors during key rotation and provider outages.

Run `bin/rails db:migrate` before enabling OAuth configuration, then restart all
API processes. Any partial issuer/audience/JWKS configuration also disables
personal/integration compatibility tokens. Supply all three settings together.

## Explicit tenant identity provisioning

A provider identity grants no Big Buck access until an administrator creates a
local binding. Use an existing owner web session (or a controlled Rails console)
to bootstrap the first binding. Never auto-link by email. Obtain `sub` and the
client ID from the provider's administrative identity record, not unverified
user-submitted token contents.

An administrator with `integration.manage` can call:

```http
POST /v1/oauth_identities
Content-Type: application/json
Authorization: Bearer <existing owner session or authorized OAuth access token>

{
  "oauth_identity": {
    "name": "Tim CLI",
    "subject": "provider-subject",
    "client_id": "native-client-id",
    "kind": "human",
    "membership_id": "existing-membership-uuid",
    "scopes": ["people:read", "jobs:read"]
  }
}
```

For a service identity use `kind: service`, the service token's provider subject
and client ID, and omit `membership_id`. Client credentials have no user or role;
the explicit local service scopes are their permission ceiling. Human access is
intersected with the current active membership's role. All access is intersected
with token scopes and binding scopes. Scope names are defined in
`app/services/scopes.rb`; `credentials:manage` grants identity administration.
Agents cannot administer these bindings.

The exact `(issuer, subject, client_id)` tuple belongs to one organization.
Membership foreign keys enforce the same organization. Cross-organization
headers and provider claims cannot override this binding. A client needing
multiple tenant contexts must use distinct provisioned subjects or clients.

`GET /v1/oauth_identities` lists bindings for the authenticated organization.
`POST /v1/oauth_identities/<id>/revoke` disables one immediately, including already
issued tokens, and records an audit entry. There is no API reactivation operation.
These are sensitive administrative actions; use minimum scopes for ordinary CLI
and service identities.

## Human CLI login

Build the SDK first, install the CLI, then build it (see `cli/README.md`).

```bash
export BIGBUCK_API_URL=https://api.bigbuck.example.com
export BIGBUCK_OAUTH_ISSUER=https://identity.example.com/
export BIGBUCK_OAUTH_CLIENT_ID=native-client-id
export BIGBUCK_OAUTH_AUDIENCE=https://api.bigbuck.example.com
export BIGBUCK_OAUTH_SCOPES='people:read jobs:read'
# Optional RFC 8707 resource parameter if the provider requires it:
# export BIGBUCK_OAUTH_RESOURCE=https://api.bigbuck.example.com
# export BIGBUCK_OAUTH_CALLBACK_PORT=49152
bigbuck auth login
bigbuck auth status
bigbuck person list
bigbuck auth logout
```

`BIGBUCK_OAUTH_AUDIENCE` adds the provider's audience parameter;
`BIGBUCK_OAUTH_RESOURCE` adds the standard resource parameter. Set whichever the
provider requires to issue an API-audience token. Default scopes are
`people:read jobs:read`; login also requests `openid offline_access`.
HTTP APIs are permitted only on literal loopback development addresses.

Login validates state, nonce, PKCE, signed ID tokens, and API acceptance before
saving credentials. Tokens stay in macOS Keychain, Windows Credential Manager,
or Linux Secret Service through `@napi-rs/keyring`. Linux needs an available
Secret Service; there is no plaintext or in-memory credential-store fallback.
The CLI stores no ID token. The keychain account binds issuer, client, API URL,
audience/resource, scopes, and callback settings; use the same settings to log out.

Refresh occurs when less than a minute remains, with rotation persisted before
the token is returned. Concurrent CLI processes serialize refresh and logout
using `proper-lockfile`; only an empty marker is written to
`$XDG_STATE_HOME/bigbuck` (default `~/.local/state/bigbuck`). A revoked refresh
grant clears the local session and requires login again. These flows need Node
20.19+ (the repository uses Node 24) and native keychain support.

Logout requests provider revocation and always removes local credentials.
Self-contained JWT access tokens can remain valid until expiry after provider
revocation. For immediate Big Buck shutdown, revoke the local binding; for
full provider shutdown, revoke the provider grant/client as well. A logout
revocation failure is reported explicitly so an administrator can finish it.

## Scheduled jobs and SDK consumers

Use the same API/issuer/audience settings with a dedicated confidential client:

```dotenv
BIGBUCK_OAUTH_CLIENT_ID=import-service-client
BIGBUCK_OAUTH_CLIENT_SECRET=<injected secret>
BIGBUCK_OAUTH_SCOPES=people:read imports:write
```

The CLI obtains client-credentials tokens, caches them until renewal within the
command, and never opens a browser or keychain. No secret command-line flag is
provided. `auth status` verifies the resulting service identity; human login and
logout commands are unavailable in service mode.

SDK consumers can pass `tokenProvider: async () => accessToken` to
`BigBuckClient` or `BigBuckClient.fromEnv`. It is called for every request so the
consumer can renew credentials. Empty results fail before sending a request.
Bearer requests reject redirects. The SDK does not itself own OAuth sessions.

## Compatibility and rollout

When Rails OAuth is enabled, personal and integration API tokens are rejected
by default, and the generic credential endpoint stops issuing them. An explicit,
temporary `BIGBUCK_ALLOW_LEGACY_API_TOKENS=1` allows migration. Existing Rails web
sessions and agent credentials retain their current behavior. This change does
not replace browser sign-in or remediate all authorization gaps in the audit.

Before production rollout, configure a provider test tenant, provision one human
and one service binding, verify CLI login/status/API access/logout, verify revoked
and wrong-audience access, and verify provider refresh rotation and signing-key
rollover. Test native keychain behavior on each supported OS. These live-provider
and OS checks require actual registrations and are not implied by local tests.

Local automated tests cover signed JWT verification, tenant/scope/role ceilings,
revocation, provisioning, unsafe JWKS/cache behavior, PKCE/nonce/signature checks,
refresh, logout, machine credentials, lock serialization, and SDK token renewal.
See `SECURITY.md` for the separate security/quality
findings and `implementation.plan.md` for implementation status.
