# Interactive Lab and Developer Docs

- [x] 1. Sandbox isolation, persona sessions, reset coordination, demo policy
- [x] 2. Four-card entry, role picker, lab shell and UI handoff
- [x] 3. Live API, CLI and MCP explorers
- [x] 4. Shared Explore / Compare / Connect stories and inspector
- [x] 5. Public developer docs and contract references
- [x] 6. Backend / TypeScript / live Playwright verification and polish

V1 is a proof of concept with four shared tenants, hourly resets and no model dependency.
V2 adds a conversational agent. Use pnpm and the existing Remix 3 architecture.

## Hardened API OAuth (November 5, 2026)

Use an external OAuth/OIDC issuer and maintained protocol libraries. Big Buck is
an API resource server and CLI client; it does not implement its own authorization
server. Provider selection/configuration remains explicit. Google login tokens
are not accepted as API credentials unless issued for the configured API audience.

- [x] 7. Configure issuer/audience and validate signed, expiring API access tokens against trusted keys; bind issuer+subject+client to explicitly provisioned tenant identities, intersect OAuth scopes with local permissions, and support immediate local revocation.
- [x] 8. Add CLI browser login with authorization code + S256 PKCE, state/nonce validation, loopback callback, short-lived access tokens, refresh rotation, OS keychain storage, and logout/revocation using maintained OAuth/OIDC libraries.
- [x] 9. Add unattended client-credentials access with dedicated scoped service identities; obtain tokens from the issuer, never reuse a human refresh token for scheduled automation.
- [x] 10. Document provider registrations, identity binding, scope/audience configuration, migration/compatibility, and operational setup; add meaningful negative authorization/expiry/revocation/CLI-flow tests and run affected checks.

Compatibility API tokens remain explicit opt-in tooling credentials. Existing web
sessions stay on the Rails identity boundary. The separate Google browser-login
hardening and other code-quality audit findings remain tracked in
the code-quality review; this work does not claim to remediate
all of them. Managed-provider credentials and registrations are required for a
live production sign-in verification.


Verification (November 5): full Rails suite 299 tests / 5,058 assertions passed;
final affected Rails regression checks 30 tests / 281 assertions passed; CLI 13,
SDK 6, and MCP 8 tests passed. TypeScript builds/checks, changed-file Ruby lint,
tenant conventions, and migration/structure consistency passed. The CLI npm
advisory audit reported no known vulnerabilities. Local test schema metadata was
aligned with the existing committed posting migration before the full suite.

Setup and rollout instructions: `OAUTH.md`. Actual provider registrations,
production issuer/audience/JWKS configuration, refresh/key rotation policy, and
live provider/OS-keychain verification remain deployment tasks. Existing CI Ruby
runtime mismatch and the other audit findings remain separate follow-up work.

## Remaining security audit remediation

- [x] Shared REST/GraphQL candidate, job and compensation visibility boundaries.
- [x] Derived-data erasure and durable file cleanup with pending verification/retry.
- [x] Patched dependencies, supported Ruby runtime and CI security/quality checks.
- [x] Browser-bound one-time Google OAuth with PKCE and verified OIDC claims.
- [x] Private Active Storage quarantine and real fail-closed scanner integration.
- [x] Encrypted per-endpoint webhook keys, rotation and timestamp signing.
- [x] Operational log allowlist, request bounds, demo isolation and secure cookies.
- [x] Atomic principal-bound idempotency and composite tenant foreign keys.
- [x] Final regression verification and PR #62; merge follows passing GitHub checks.
- [ ] Live production controls and backup restore drill (deployment configuration required).

Operational requirements and known limits are documented in SECURITY.md.

Final local verification: the affected erasure/upload/concurrency and legacy
boundary tests pass (21 tests, 151 assertions). Ruby lint, Brakeman, all four
JavaScript advisory audits, tenant conventions and clean migration/schema
comparison pass. Remix 51, CLI 13, SDK 6 and MCP 8 tests pass, with TypeScript
checks/builds and GraphQL generation/document validation. The full local run
identified three old expectations; the updated focused run covers all three.
The complete GitHub CI suite is the final merge gate.

## Local security controls

- [x] 1. Separate local MySQL runtime, migration and maintenance users; prove audit and schema privileges cannot be bypassed.
- [x] 2. Real ClamAV/EICAR, unavailable definitions, timeout and storage-cleanup failure verification.
- [x] 3. Signed local snapshots and erasure ledgers; offline restore/replay/readiness drill in isolated databases and storage.
- [x] 4. Local setup/rollout documentation, configuration checks and CI verification coverage.

Local privilege, real ClamAV and offline recovery drills pass; focused regressions pass.
Full Rails and GitHub CI/Security checks remain the final merge gate for this change.
