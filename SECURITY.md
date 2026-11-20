# Security controls and rollout

The API uses shared resource visibility and offer-field policies across REST and
GraphQL. OAuth access is configured through an external issuer; see OAUTH.md.
The normal GitHub workflows run tests, schema comparison, Ruby lint, Brakeman,
Ruby advisory scans and audits of all four JavaScript dependency trees. Web
correctness lint and formatting of changed files also run on pull requests.

## Production configuration

Apply the forward migrations before deploying the new application. Tenant
foreign keys validate existing rows and intentionally reject inconsistent data;
investigate any migration failure instead of disabling the constraints. The
posting migration removes a stale audience default without overwriting explicit
posting audiences. Test the upgrade against a restored staging database first.

Set BIGBUCK_ALLOWED_HOSTS to a comma-separated list of the actual API hostnames.
Startup refuses an empty list. TLS/HSTS and Secure cookies are enabled; only
/up is exempt from host checks and HTTPS redirects. Configure exact WEB_ORIGIN
and WEB_ORIGINS values. The Remix SESSION_SECRET must contain at least 32
characters; its cookie payload uses authenticated encryption and the production
cookie is explicitly Secure. Rotating this secret invalidates browser cookies.
Use separate secrets for production and disposable demo deployments.

Run database migrations with a separate administrative identity. Runtime users
should have only the SELECT/INSERT/UPDATE/DELETE grants each application needs,
never DDL, GRANT, trigger alteration, or global administration privileges. The
runtime account must have only SELECT/INSERT on audit_events. The maintenance
account may additionally DELETE, using the purge flag as an accidental-deletion
guard. The session variable is not a security boundary; table grants block a
runtime connection from deleting history even if it sets that flag. Local
provisioning and a real privilege test are available in LOCAL_SECURITY.md.
Use private Cloud SQL connectivity with the authenticated connector/socket, or
verified-identity TLS for direct TCP connections (MYSQL_SSL_CA is required).
Verify grants and transport against the deployed database.

API IP limits use the shared Solid Cache MySQL tables in production. Sign-in,
OAuth and public careers requests have tighter limits. Request bodies are
bounded before JSON parsing. Apply edge limits and execution deadlines as well,
and validate proxy/IP behavior with the actual hosting configuration.
Email demo sign-in only accepts registered disposable demo tenants.

## Documents and erasure

Set GOOGLE_CLOUD_PROJECT and BIGBUCK_DOCUMENT_BUCKET to a private GCS bucket.
Use uniform bucket-level access, public access prevention and an application
service identity scoped to that bucket. Active Storage public routes are disabled;
downloads require document.read, candidate visibility and a clean scan.
Uploads use opaque keys, bounded reads and quarantine. A missing scanner,
scanner failure or exceeded scan limit never grants download access.

The image includes ClamAV. Supply regularly refreshed signature databases to
workers and monitor definition age, failed scans and the documents queue. Set
BIGBUCK_CLAMSCAN only to a trusted executable if overriding clamscan. The scan
process has a deadline and bounded scan limits. Validate it with clean, EICAR,
archive-limit and unavailable-definition samples in staging before enabling
production uploads. The local check now verifies real ClamAV with test-only
EICAR definitions, scan limits and unavailable definitions; full live signature
updates and deployed worker coverage still need infrastructure verification.

Erasure persists redaction and cleanup intent before deleting storage. Cleanup
jobs run after the outer database transaction commits and retry failures.
Verification checks both blob metadata and the actual storage keys; inaccessible
storage counts as pending. A data request remains open until verification passes
and can then be completed by retrying. Monitor failed cleanup jobs and replay
ErasedDocumentCleanupJob with the retention action ID after resolving the cause.
Unsafe legacy paths require operator review rather than following traversal or
symlinks outside storage. Remote mail/provider cleanup remains an operational
responsibility; database erasure cannot recall previously delivered messages.

## Webhooks and retries

New endpoints receive unique encrypted signing keys. Creation and rotation return
the plaintext once. Rotate existing endpoints whose legacy secret reference is
not encrypted: those deliveries fail closed. Store the new key in the receiver's
secret manager before resuming delivery; rotation immediately invalidates the
old key. Verify X-BigBuck-Signature as HMAC-SHA256 over the literal
X-BigBuck-Timestamp, a dot and the exact raw request body bytes. Compare in
constant time, reject timestamps outside a short replay window, and deduplicate
X-BigBuck-Delivery. Test receiver compatibility before rolling out this change.

Idempotent database writes hold an organization row lock and commit business
state and the response together. Keys bind the tenant, principal, effective
permissions, method, path, query and canonical body. Changed requests and
responses whose resource is no longer visible cannot replay. Secrets are never
cached for replay. Organization-level serialization is deliberately simple but
limits concurrent writes for a tenant; monitor lock waits. This provides no
exactly-once guarantee for external effects. Use the existing transactional
outbox and receiver deduplication for external delivery.

## Deployment verification still required

Verify live issuer registrations/key rotation, proxy headers, runtime grants,
bucket permissions, scanner updates, Secret Manager IAM and log access/retention.
Enable automated backups/PITR with an explicit retention policy. Perform a
restore drill and reapply erasure records before a restored database serves
traffic; backup copies expire under the retention policy, not the live-row purge.
Keep backup and production credentials separate.
The offline local recovery drill in LOCAL_SECURITY.md verifies erasure replay
and readiness gating in isolated MySQL/Disk storage. It is not a replacement
for encrypted managed backups or an independently durable erasure journal.

GitHub's branch-protection API returned HTTP 403 because the current private
repository plan does not support it. Workflow checks are present, but required
merge gates cannot currently be enforced by branch protection. Upgrade the plan
or configure supported repository rules, then require CI and Security checks.

Shared client generation, optimistic-locking cleanup and list-query batching
remain code-quality follow-ups. They are not claimed as completed security fixes.
