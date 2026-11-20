# 16 — Security Research & Hardening Plan

## Goal

Define the security posture Big Buck should adopt before implementation so the platform can be built with enterprise-grade controls from day one.

This is a research/planning document only. Nothing below is implemented yet.

## Executive summary

Big Buck’s product direction creates a high-trust security problem:

- multi-tenant ATS data
- candidate personal data and tenant-scoped retention/consent
- immutable audit requirements
- AI/agent actions with human-impacting consequences
- regulatory exposure across GDPR, CCPA/CPRA, PIPEDA, and LGPD
- likely enterprise customers who will expect SOC 2-aligned controls

The right baseline is **defense in depth** with strong tenancy boundaries, explicit authorization, full auditability, least privilege, and operational readiness for incident response and compliance evidence.

## Security themes already present in the business plan

These are good foundations already captured in the product docs:

- immutable, append-only audit logging
- organization-scoped multi-tenancy
- RBAC with explicit roles, permissions, and field-level controls
- data residency strategy across regulated regions
- AI transparency and no silent high-impact actions
- scoped API tokens and signed webhook payloads

## Gaps still not addressed

The following security areas still need explicit design work:

1. threat model
2. vulnerability surface analysis / attack surface inventory
3. secrets management specification
4. incident response and breach handling plan
5. encryption-at-rest and in-transit policy
6. SOC 2 and compliance roadmap
7. network security / zero-trust architecture
8. dependency and supply chain security policy
9. secure SDLC and release signing
10. backup, restore, and disaster recovery security controls

## Security objectives

Big Buck should be designed to meet these objectives:

- prevent cross-tenant data leakage
- prevent unauthorized access to candidate records
- preserve an immutable audit trail for security-relevant events
- make all AI and agent actions attributable and reviewable
- minimize blast radius if a token, service, or dependency is compromised
- support regulatory requests for access, deletion, and export
- produce audit evidence that maps cleanly to SOC 2-style controls

## Threat model

### Primary assets

- candidate identity and profile data
- candidate data-processing consent records (per tenant)
- job and application records
- internal notes, evaluations, and interview artifacts
- tenant configuration and integrations
- API tokens, webhook secrets, and service credentials
- audit logs and immutable event history
- AI prompts, outputs, and tool execution traces

### Primary adversaries

- external attackers targeting PII and hiring data
- malicious or over-privileged tenant users
- compromised API clients or integrations
- supply-chain compromise via packages or build pipeline
- insider misuse by operators or admins
- abusive automation scraping candidate data
- prompt injection / tool abuse against AI workflows

### High-value attack paths

- tenant-to-tenant data exfiltration
- broken object-level authorization on candidate/application records
- token theft from browser, CI, or server logs
- webhook forgery or replay
- privilege escalation through role misconfiguration
- insecure file upload or document parsing
- prompt injection leading to unauthorized actions
- leaked secrets in environment variables or build artifacts
- dependency compromise in JavaScript or transitive packages

## Attack surface inventory

### Internet-facing surfaces

- recruiter and candidate web app
- REST API
- auth callback endpoints
- public job board pages
- webhook receivers
- file upload and download endpoints
- CLI authentication and device/browser login flows

### Internal surfaces

- worker jobs
- background queues
- scheduled tasks
- admin tooling
- observability and log pipelines
- AI/agent tool execution layer

### High-risk data flows

- candidate submission and profile sharing
- resume/document upload and parsing
- tenant integrations via OAuth or API tokens
- signed webhook delivery to customer systems
- AI-generated recommendations and actions

## Baseline security architecture

### 1) Identity and access management

- OIDC for human auth
- short-lived sessions where possible
- MFA required for privileged users
- org-aware RBAC enforced at the service layer, not only in the UI
- explicit permission checks on every read/write path
- field-level authorization for sensitive attributes
- separate admin/operator roles from tenant roles
- support for enterprise SSO and SCIM as a later phase

### 2) Multi-tenancy and isolation

- every tenant-scoped entity must carry tenant ownership metadata
- authorization must be verified server-side on every request
- no tenant isolation through frontend filtering alone
- use scoped database access patterns and defensive query helpers
- avoid shared mutable state across tenant contexts
- separate internal admin workflows from tenant traffic where possible

### 3) Encryption

Minimum policy:

- TLS 1.2+ in transit everywhere
- HSTS for all browser-facing surfaces
- encrypted storage at rest for database, object storage, backups, and logs where supported
- application-level encryption for especially sensitive fields if needed
- secret material never stored in plaintext in source control
- client-side encryption is not required for v1, but may be evaluated for sensitive attachments

### 4) Secrets management

Recommended policy:

- use GCP Secret Manager for runtime secrets
- no secrets in git, container images, or CI logs
- separate secrets by environment and service
- rotate API keys, webhook secrets, and signing keys on a schedule
- prefer short-lived tokens and workload identity over long-lived service accounts
- define break-glass access for incident response only

### 5) Audit logging

- append-only audit log for all security-relevant mutations and access events
- include actor, tenant, object type/id, action, timestamp, source IP, and request correlation ID
- record consent grants, revocations, exports, deletions, auth events, permission changes, integration changes, and agent actions
- protect audit logs from alteration by normal app roles
- exportable to a SIEM or compliance archive

### 6) Network security / zero trust

- public ingress only to approved edge services
- private service-to-service traffic by default
- no direct database exposure to the public internet
- least-privilege service accounts for each workload
- egress controls for external integrations and model providers
- consider a zero-trust posture for internal admin and support tooling

### 7) Supply chain security

- lock dependency versions
- commit lockfiles
- review critical JavaScript dependencies before adoption
- use automated vulnerability scanning in CI
- generate SBOMs for releases if enterprise sales require it
- sign release artifacts and container images
- prefer reproducible builds where feasible
- define a process for emergency dependency patching

### 8) Safe AI / agent controls

Because the platform includes hiring agents, the AI layer needs explicit constraints:

- no silent high-impact actions
- draft-only by default for offers, rejections, and external messages
- all tool calls logged with inputs/outputs
- human approval gates for sensitive actions
- prompt injection defenses for uploaded documents and external content
- strict tool allowlists per agent role
- separate read-only analysis from write-capable actions

## Secure SDLC expectations

Big Buck should adopt a secure development lifecycle before launch:

- code review required for security-sensitive changes
- branch protection and mandatory checks
- static analysis and dependency scanning in CI
- secret scanning on commits and pull requests
- infrastructure-as-code review for cloud resources
- security test cases for authorization, tenancy boundaries
- regression tests for audit logging and deletion semantics
- pre-release checklist for credentials, permissions, and exposed endpoints

## Incident response plan

A formal incident response plan is required before enterprise onboarding.

### Required components

- severity levels and escalation criteria
- on-call ownership and contact paths
- detection and triage procedures
- containment and eradication steps
- customer communication templates
- evidence preservation and forensic logging
- post-incident review process
- breach notification timelines by jurisdiction

### Security events to plan for

- compromised tenant account
- stolen API token or webhook secret
- cross-tenant data exposure
- malicious integration or webhook abuse
- data deletion failure
- supply-chain compromise
- AI tool abuse or unauthorized action

## Compliance roadmap

### Near-term target

Aim for **SOC 2-ready controls**, even before formal certification.

### Recommended roadmap

1. define security policies and control owners
2. implement logging, access control, and change management evidence
3. establish vendor and dependency review processes
4. document backup/restore and incident response procedures
5. perform internal security review and tabletop exercises
6. commission a penetration test before production launch
7. prepare for SOC 2 Type I once operations stabilize
8. pursue SOC 2 Type II after controls have operated long enough to generate evidence

### Other privacy/compliance considerations

- GDPR lawful basis and erasure handling
- CCPA/CPRA access and deletion requests
- PIPEDA consent and retention obligations
- LGPD data subject rights and transfer controls

## Pen-test and vulnerability validation plan

Before launch, run a focused assessment on:

- authentication and session management
- tenant isolation and object-level authorization
- file upload and document parsing
- webhook verification and replay resistance
- API token scopes and revocation
- admin and support tooling
- AI tool execution and prompt injection paths

Recommended validation approach:

- automated DAST against staging
- manual authorization testing
- penetration test by an external assessor before enterprise rollout
- recurring retest after major releases

## Backup, restore, and resilience

Security is incomplete without recoverability.

Required controls:

- encrypted backups
- tested restore procedures
- point-in-time recovery for Cloud SQL for MySQL
- retention policies aligned to legal and business needs
- separate access controls for backup data
- disaster recovery runbooks for regional failure

## Prioritized implementation order

### Phase 0 — before code

- threat model workshop
- data classification and trust boundary map
- secrets management policy
- encryption policy
- incident response draft
- dependency policy
- logging and audit requirements

### Phase 1 — foundation

- OIDC + MFA
- org-aware RBAC
- append-only audit log
- encrypted storage and TLS everywhere
- tenant isolation tests
- secure upload pipeline

### Phase 2 — pre-launch hardening

- supply-chain scanning in CI
- release signing
- external pen test
- tabletop incident response exercise
- backup/restore validation
- SOC 2 control mapping

### Phase 3 — scale and enterprise readiness

- SIEM/export integrations
- formal vendor risk review
- SCIM and enterprise SSO
- dedicated region / residency controls
- recurring penetration tests and control audits

## Open questions

1. Should candidate PII fields use field-level encryption for especially sensitive data?
2. What is the exact retention policy for audit logs versus operational logs?
3. ~~Do we need separate tenancy boundaries at the database schema level or is service-layer enforcement sufficient for v1?~~ Decided 2026-10-25: shared schema. MySQL has no row-level security, so isolation is `organization_id` on every tenant row, a default tenant scope that fails closed, composite `(organization_id, id)` foreign keys, and cross-tenant tests each milestone. See [`build-plan.md`](./build-plan.md#mysql-principles).
4. Which actions require mandatory human approval in the agent layer?
5. What customer security artifacts will be needed for sales: SOC 2 report, pen test summary, subprocessor list, DPA, and security whitepaper?

## Recommendation

Before implementation starts, Big Buck should publish a small internal security baseline covering:

- identity and access control
- encryption and secrets
- audit logging
- network boundaries
- data retention and deletion
- AI action governance
- incident response
- dependency/security scanning

That baseline should become a product requirement, not a later ops task.
