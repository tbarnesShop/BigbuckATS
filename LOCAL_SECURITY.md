# Local security controls

Use this sandbox to exercise the same database privilege boundaries and erasure
behavior intended for deployment. It creates a separate database and separate
Disk storage; it does not change `bigbuck_development` or `bigbuck_test`.

## Setup and daily use

Install the locked Ruby bundle, MySQL 8 client/server and ClamAV (`brew install
clamav` on macOS). The MySQL administrator must accept local connections. Set
`LOCAL_MYSQL_ADMIN_HOST` (localhost or 127.0.0.1), `LOCAL_MYSQL_ADMIN_PORT`,
`LOCAL_MYSQL_ADMIN_USER`, `LOCAL_MYSQL_ADMIN_PASSWORD`, or
`LOCAL_MYSQL_ADMIN_SOCKET` as needed. Keep passwords out of command history.
On a local server with binary logging enabled, an administrator must configure
`log_bin_trust_function_creators=1` so the database-scoped migrator can create
the audit triggers. Do not give global administrator privileges to the migrator.

```sh
bin/local-security setup
bin/local-security verify
bin/local-security run maintenance bin/rails runner 'DemoWorkspaces.prepare!("ui")'
bin/local-security run runtime bin/rails server
```

The launcher defaults to development; set `RAILS_ENV=test` explicitly for tests.
It passes only the selected database profile to the child and removes local
administrator environment variables. Normal `bin/rails` commands still use the
existing database configuration: use the launcher to exercise these controls.
Set `LOCAL_SECURITY_DATABASE=bigbuck_local_NAME` for another disposable sandbox.
Profiles and storage live in ignored `tmp/local-security/DATABASE/`; credentials
are generated randomly and written with mode 0600 inside private directories.
For Docker port forwarding, accounts also allow the exact client address
observed by MySQL; they never use a wildcard host grant.

| Process | Database permissions |
| --- | --- |
| runtime | CRUD on ordinary tables; SELECT/INSERT on audit_events |
| maintenance | CRUD on ordinary tables; SELECT/INSERT/DELETE on audit_events |
| migrator | Database-scoped ALL, without GRANT OPTION or global privileges |

Audit UPDATE is always blocked by the trigger. Audit DELETE needs both a
maintenance account and the session purge flag. `verify` proves that setting
the flag from runtime still cannot delete a real audit record; runtime also
cannot change the schema or grant permissions. Runtime startup verifies the
actual Rails identity and its audit permission boundary. Expired demo resets
refuse runtime access before modifying the sandbox; refresh them in a separate
maintenance process. On deployed workers, keep the maintenance queue and its
credentials separate from ordinary web/worker processes.

Run migrations with the migrator profile, then rerun `setup` to refresh per-table
grants for newly added tables. Setup refuses unrelated existing databases and
detects incomplete schema imports. A failed partial import needs manual removal
of that owned disposable database before retrying; it never wipes one itself.

These profiles share your local OS user and filesystem. They verify SQL
privileges, but do not isolate secrets from arbitrary code running as that OS
user. Production needs separate service identities and secret access policies.

## Scanner and cleanup checks

```sh
bin/local-security scanner-check
RAILS_ENV=test bin/rails test test/services/local_security_test.rb test/services/person_erasure_test.rb
```

`scanner-check` invokes the real ClamAV engine with a temporary, single EICAR
test signature. It verifies clean and infected results, a compressed file that
exceeds the expanded-size limit, and missing definitions. These signatures test
the integration only; they provide no production malware coverage. Configure
`freshclam` and a current full signature database for ordinary development scans.
`BIGBUCK_CLAMAV_DATABASE` can select a trusted definitions file/directory.

Regression tests cover scanner timeout, oversized input, storage deletion
failure, retained cleanup metadata, a queued retry and successful later cleanup.
Missing scanner/definitions or storage availability never counts as success.

## Offline backup and recovery rehearsal

Stop all writers and workers for the sandbox before backup, ledger export and
recovery. `LOCAL_SECURITY_OFFLINE=1` is an operator acknowledgement, not an
automatic lock. MySQL and filesystem copies are not an atomic snapshot together.
Use only synthetic local data. Snapshots are private but **not encrypted**.

```sh
LOCAL_SECURITY_OFFLINE=1 bin/local-security drill
```

The drill creates a candidate and uploaded resume, backs them up, erases the
source and restores the older snapshot into a new `bigbuck_recovery_*` database
and independent storage. It reapplies erasures and verifies residual data and
file deletion before issuing a signed READY marker. It also proves that stale,
mismatched or corrupted ledgers, modified SQL/files, and restored legal holds
cannot pass recovery. Drill databases and files remain for inspection.

Individual operations are available:

```sh
LOCAL_SECURITY_OFFLINE=1 bin/local-security backup
bin/local-security export-erasures
LOCAL_SECURITY_OFFLINE=1 bin/local-security recover SNAPSHOT_DIRECTORY FRESH_LEDGER_FILE
```

Export the ledger from the live source after the snapshot and immediately before
recovery, with writers stopped. Ledgers expire after five minutes. They contain
tenant/person IDs and erasure modes, with no raw personal fields. Snapshot
manifests, ledgers and readiness markers use standard OpenSSL HMAC-SHA256; the
local signing key stays outside the snapshot in `tmp/local-security/`.
Preserve that key separately if preserving snapshots. Losing it makes verification
impossible. This protects against accidental corruption or modification without
the key, not a compromised local OS account.

Recovery verifies hashes before SQL import, rebinds audit trigger definers to the
target migrator, and rejects external storage, non-opaque blob/cleanup keys and
legacy filesystem paths.
Erasure replay uses existing application services, honors restored legal holds
and cleans pending file intents synchronously. Recovered runtime access through
the launcher is blocked until READY is present and valid. Do not bypass the
launcher with administrative credentials or start workers against restored data.
These are disposable rehearsal databases, not a production restore promotion.

## Required with actual infrastructure

Before accepting real candidate data, configure and verify:

- Managed OAuth/OIDC registrations, issuer/audience/client settings and key rotation.
- Separate runtime, migrator and maintenance identities with the tested SQL grants;
  private database connectivity/TLS, separate secret access and queue routing.
- Private object storage, service IAM, fresh full antivirus definitions and alerts
  for scan failures, stale definitions and failed cleanup retries.
- Encrypted automated backups/PITR, retention policies, off-host recovery keys and
  an independently durable erasure journal that survives source database loss.
- A staging restore drill using that journal, held-restore quarantine and explicit
  promotion, plus backup expiration and remote-provider cleanup procedures.
- Edge limits, proxy/IP validation, centralized restricted logs and audit export,
  monitoring, alert routing and supported required GitHub merge checks.

Local CI exercises the SQL boundaries, real scanner integration and offline
recovery on every pull request. It cannot prove the eventual cloud IAM, network,
backup service, issuer or operational response configuration.
