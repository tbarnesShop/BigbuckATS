# Migration & Sync Engine

> **v1 scope (2026-10-24):** v1 ships generic CSV import and export with field mapping, dry run and provenance, behind an importer interface. The vendor-specific analysis below is research for later importers; no vendor-named importer is promised in v1 ([`decisions.md`](./decisions.md#resolved-questions)).

## The walled garden problem

Every incumbent ATS makes switching expensive on purpose.

Greenhouse, Lever, and Workday all hold years of candidate history, pipeline state, interview feedback, offer records, and documents inside proprietary data models. There is no standard export format. Most offer partial CSV dumps that lose stage history, scorecard structure, and document attachments. Moving to a new ATS traditionally means a 3–6 month professional services project, data loss on anything that didn't fit a CSV column, and a hard cutover date that the whole recruiting team dreads.

This is not accidental. Lock-in is a retention strategy.

Big Buck's migration engine is a commercial weapon. If a team can move from Greenhouse to Big Buck in a single afternoon — full history, all documents, all users — the switching cost drops to near zero. That changes the sales conversation from "can we afford to migrate?" to "why wouldn't we?"

The CLI is the delivery mechanism. Not a wizard. Not a professional services engagement. A command.

---

## The Big Buck migration promise

```bash
# Full Greenhouse migration — dry run first
bigbuck import greenhouse --api-key $GH_KEY --mode dry-run

# Review the plan, then execute
bigbuck import greenhouse --api-key $GH_KEY --mode full --org acme-corp

# Watch it run
bigbuck import status --job-id imp_abc123 --watch

# Done. Verify.
bigbuck import verify --job-id imp_abc123
```

Target: **years of ATS history imported in under 4 hours** for a 500-person company with 10,000 historical applications.

---

## Migration engine architecture

The migration engine is built on top of the existing `import_jobs` table and worker infrastructure. It adds a structured adapter layer per source system.

```
┌─────────────────────────────────────────────────────────┐
│                    CLI / API trigger                     │
│   bigbuck import greenhouse --api-key ... --mode full    │
└──────────────────────────┬──────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────┐
│                   Import Orchestrator                    │
│   Creates import_job record                             │
│   Validates credentials and scopes                      │
│   Enqueues extraction jobs via Solid Queue              │
└──────────────┬──────────────────────────────────────────┘
               │
   ┌───────────▼────────────┐
   │   Source Adapter       │   One per ATS
   │   (greenhouse, lever,  │   Handles auth, pagination,
   │    ashby, workday, csv)│   rate limits, retries
   └───────────┬────────────┘
               │
   ┌───────────▼────────────┐
   │   Extraction Layer     │   Pulls raw source data
   │   Chunked by entity    │   Writes to staging tables
   │   Idempotent per chunk │   checkpoint-resumable
   └───────────┬────────────┘
               │
   ┌───────────▼────────────┐
   │   Transform Layer      │   Maps source schema → Big Buck schema
   │   Field mapping        │   Stage mapping (configurable)
   │   User mapping         │   Deduplication
   │   Conflict resolution  │
   └───────────┬────────────┘
               │
   ┌───────────▼────────────┐
   │   Load Layer           │   Writes to production tables
   │   Transactional        │   Audit-logged with source_surface='import'
   │   Rollback-capable     │   Preserves source IDs as external_refs
   └───────────┬────────────┘
               │
   ┌───────────▼────────────┐
   │   Verification Layer   │   Counts match source
   │   Spot-checks samples  │   Flags missing docs
   │   Generates report     │   Surfaces warnings
   └────────────────────────┘
```

### Staging tables

> Design sketch in MySQL syntax. The built CSV importer uses `import_runs` and `import_rows` (`db/structure.sql`); `external_source_refs` is not built yet.

The migration engine uses intermediate staging tables to make extraction resumable and transformation auditable:

```sql
CREATE TABLE import_staging_records (
  id              VARCHAR(36) PRIMARY KEY,
  import_job_id   VARCHAR(36) NOT NULL,
  organization_id VARCHAR(36) NOT NULL,
  source_system   VARCHAR(64) NOT NULL,   -- 'greenhouse', 'lever', 'ashby', 'csv'
  entity_type     VARCHAR(64) NOT NULL,   -- 'candidate', 'application', 'job', 'document'
  source_id       VARCHAR(255) NOT NULL,  -- original ID in source system
  raw_json        JSON NOT NULL,          -- unmodified source payload
  mapped_json     JSON,                   -- after transform (null until transformed)
  status          VARCHAR(32) NOT NULL DEFAULT 'extracted',
                                          -- 'extracted', 'mapped', 'loaded', 'skipped', 'error'
  error_json      JSON,
  created_at      DATETIME(6) NOT NULL,
  UNIQUE KEY (import_job_id, source_system, entity_type, source_id)
);
```

Extraction writes to staging. Transformation reads from staging and writes `mapped_json`. Load reads `mapped_json` and writes to production. Each phase is independently resumable.

### Import job lifecycle

```
created → validating → extracting → transforming → loading → verifying → completed
                                                                        → completed_with_warnings
                           (any phase) → failed → retryable → extracting (resume)
```

---

## CLI commands — full specification

### `bigbuck import <source>`

```bash
# Supported sources
bigbuck import greenhouse
bigbuck import lever
bigbuck import ashby
bigbuck import smartrecruiters
bigbuck import workday
bigbuck import csv
bigbuck import json          # Big Buck export format (self-migration)

# Core flags (all sources)
--api-key <key>              # Source API key or token
--org <slug>                 # Target Big Buck org (required)
--mode dry-run               # Plan only — no writes to production
--mode preview               # Extract + map first 50 records, show mapping
--mode full                  # Full migration (requires --confirm or interactive prompt)
--confirm                    # Skip interactive confirmation (for CI/scripts)
--resume <import-job-id>     # Resume a failed import from checkpoint
--since <date>               # Only import records updated after this date (incremental)
--output json                # Machine-readable progress output

# Entity selection
--include candidates,applications,jobs,documents,users,scorecards,offers
--exclude documents          # Skip document download (faster, do separately)

# Mapping overrides
--stage-map ./mappings/stages.yaml     # Custom stage name → Big Buck stage mapping
--user-map ./mappings/users.yaml       # Source user email → Big Buck user ID mapping
--source-map ./mappings/sources.yaml   # Source attribution mapping

# Document handling
--documents download         # Download and re-upload files (default)
--documents links-only       # Store source URLs only (faster, URLs may expire)
--documents skip             # Skip all documents

# Conflict handling
--on-conflict skip           # Skip records that already exist (default)
--on-conflict overwrite      # Overwrite existing records (dangerous, requires --confirm)
--on-conflict error          # Fail on any conflict
```

### `bigbuck import status`

```bash
bigbuck import status --job-id imp_abc123
bigbuck import status --job-id imp_abc123 --watch      # Live updates
bigbuck import status --job-id imp_abc123 --output json

# Output (human-readable)
Import job: imp_abc123
Source: greenhouse → org: acme-corp
Status: extracting (phase 2 of 5)

  ✓ jobs              847 extracted
  ✓ users             34 extracted
  ✓ candidates        12,451 extracted
  ↻ applications      8,203 / 14,890 extracted (55%)
  ○ documents         waiting
  ○ scorecards        waiting

  Estimated completion: ~18 minutes
  Started: 2026-04-19 14:23:11
```

### `bigbuck import verify`

```bash
bigbuck import verify --job-id imp_abc123

# Output
Verification report: imp_abc123

  Source counts (Greenhouse)    Big Buck counts    Delta
  ─────────────────────────    ───────────────    ─────
  Jobs:           847          Jobs:        847    ✓
  Candidates:  12,451          Candidates: 12,441  ⚠ -10
  Applications: 14,890         Applications: 14,890 ✓
  Scorecards:   3,201          Scorecards:  3,201  ✓
  Documents:    9,847          Documents:   9,802  ⚠ -45

  Warnings:
  - 10 candidates skipped: duplicate email collision (see import-warnings.json)
  - 45 documents: download failed (expired source URLs) — retry with:
    bigbuck import greenhouse --job-id imp_abc123 --resume --include documents
```

### `bigbuck import generate-map`

Generates a starter mapping file from source API metadata:

```bash
bigbuck import generate-map greenhouse --api-key $GH_KEY --output ./mappings/

# Creates:
# ./mappings/stages.yaml      (source stage names → placeholder Big Buck stages)
# ./mappings/users.yaml       (source users → placeholder Big Buck users)
# ./mappings/sources.yaml     (source attribution → Big Buck sources)
# ./mappings/custom-fields.yaml (source custom fields → Big Buck custom fields)
```

### `bigbuck sync <source>` (incremental / ongoing)

For teams running both systems during transition:

```bash
# Set up ongoing sync from Greenhouse (pull new/updated records every hour)
bigbuck sync greenhouse --api-key $GH_KEY --interval 1h --org acme-corp

# One-shot incremental (for cron or CI)
bigbuck sync greenhouse --api-key $GH_KEY --since 2026-04-18T00:00:00Z

# Check sync status
bigbuck sync status --org acme-corp
```

---

## Competitor analysis — what they expose today

### Tl;dr table

| ATS | API quality | Full history? | Stage history? | Documents? | Custom fields? | Complexity |
|---|---|---|---|---|---|---|
| Greenhouse | ★★★★★ | Yes | Yes | Yes (S3 URLs) | Yes | Low |
| Lever | ★★★★☆ | Yes | Yes (per-record) | Yes (expiring URLs) | Yes | Medium |
| Ashby | ★★★☆☆ | Mostly | Yes | Yes | Yes | Medium |
| SmartRecruiters | ★★★☆☆ | Mostly | Partial | Partial | Yes | Medium |
| iCIMS | ★★☆☆☆ | Partial | Partial | Partial | Yes | High |
| Workday | ★★☆☆☆ | Via RAAS | Partial | No | Yes | Very High |
| SAP SuccessFactors | ★★☆☆☆ | Via reports | Partial | No | Yes | Very High |
| Jobvite | ★★☆☆☆ | Partial | No | Partial | Limited | High |
| Breezy HR | ★★★☆☆ | Yes | Partial | Yes | Limited | Low |
| Workable | ★★★☆☆ | Yes | Partial | Yes | Limited | Low |

---

## Greenhouse — deep dive

### API surface

Greenhouse exposes two APIs relevant to migration:

- **Harvest API** (read) — `https://harvest.greenhouse.io/v1/` — the primary extraction source
- **Ingestion API** (write) — not relevant for Big Buck import; this is for pushing candidates *into* Greenhouse

### Authentication

Basic auth. API key as username, empty password. The API key is per-user and permissions depend on what that user can see. Use a service account with full admin scope.

```bash
curl -u "$GH_API_KEY:" https://harvest.greenhouse.io/v1/candidates
```

### Rate limits

200 requests per 10 seconds. At 100 records per page:
- 12,000 candidates = 120 pages = ~60 seconds at full rate
- 14,000 applications = 140 pages = ~70 seconds
- Budget ~30 minutes per 100,000 records at safe rate

### Key endpoints for migration

| Endpoint | What it returns | Pagination |
|---|---|---|
| `GET /candidates` | All candidates with embedded latest application | `?page&per_page=100` |
| `GET /applications` | All applications with stage info | `?page&per_page=100` |
| `GET /applications/{id}/activity_feed` | Notes and emails per application | none |
| `GET /jobs` | All jobs with department and location | `?page&per_page=100` |
| `GET /job_stages` | Pipeline stage definitions per job | none |
| `GET /offers` | All offers | `?page&per_page=100` |
| `GET /scorecards` | Interview scorecards | `?page&per_page=100` |
| `GET /scheduled_interviews` | Interview schedule records | `?page&per_page=100` |
| `GET /users` | All team members | none |
| `GET /departments` | Department taxonomy | none |
| `GET /offices` | Office/location taxonomy | none |
| `GET /sources` | Source attribution taxonomy | none |
| `GET /rejection_reasons` | Rejection reason taxonomy | none |
| `GET /custom_fields` | Custom field definitions | none |

### Stage history

Each application includes a `stage_history` array:

```json
{
  "stage_history": [
    {
      "stage": { "id": 1234, "name": "Application Review" },
      "entered_on": "2025-01-15T10:00:00.000Z",
      "exited_on": "2025-01-16T14:00:00.000Z"
    },
    {
      "stage": { "id": 1235, "name": "Phone Screen" },
      "entered_on": "2025-01-16T14:00:00.000Z",
      "exited_on": null
    }
  ]
}
```

This maps directly to Big Buck's `stage_transitions` table. ✓

### Documents

Candidates have attachments returned in the API response:

```json
{
  "attachments": [
    {
      "filename": "jane_smith_resume.pdf",
      "url": "https://s3.amazonaws.com/...",   // signed URL, expires in ~24 hours
      "type": "resume"
    }
  ]
}
```

**Critical gotcha:** URLs are signed S3 URLs with short TTLs (typically 1 hour to 24 hours). Documents must be downloaded and re-uploaded to Big Buck Cloud Storage during the migration window, not stored as links.

### Custom fields

Returned as a `custom_fields` hash on candidates, applications, jobs, and offers:

```json
{
  "custom_fields": {
    "work_authorization": { "name": "Work Authorization", "type": "short_text", "value": "US Citizen" },
    "salary_expectation": { "name": "Salary Expectation", "type": "number", "value": 150000 }
  }
}
```

Maps to Big Buck's `custom_field_definitions` + `custom_field_values`. The `generate-map` command auto-creates draft field definitions from this structure.

### Practical gotchas

- **Prospects vs. Candidates:** Greenhouse distinguishes "prospects" (not yet applied) from "candidates" (have applied). Both should be imported. Prospects become `people` with `lifecycle_stage = prospect` (and project members if they sit in a Greenhouse prospect pool); candidates become `people` with `lifecycle_stage = candidate` plus their applications.
- **Deleted candidates:** Not returned by default. Use `?updated_after=2000-01-01` to get archived records; deleted records are truly gone.
- **On-behalf-of header:** `On-Behalf-Of: {user_id}` scopes audit to that user. Use your service account's ID.
- **API key permissions:** Scorecards and offers require explicit permission grants on the API key. Verify before starting migration.
- **Confidential jobs:** Require the "See Confidential" permission on the API key.

---

## Lever — deep dive

### Model difference: Opportunities

Lever's core model is fundamentally different from Greenhouse and Big Buck. The primary object is the **Opportunity** — which bundles candidate + application into one record. A single person (Contact) can have multiple Opportunities (one per job they've been considered for).

```
Lever Contact (person)
  └── Opportunity A (job at Company for Role X)
  └── Opportunity B (job at Company for Role Y)

Big Buck:
  Candidate (person)
    └── Application A → Job X
    └── Application B → Job Y
```

The migration must deduplicate Contacts across Opportunities to produce one Big Buck Candidate per person.

### Authentication

API key via Basic auth (key as username, empty password), or OAuth 2.0. Use API key for migration — OAuth requires user interaction.

### Rate limits

~300 requests per minute on most endpoints. Cursor-based pagination means no page-size tuning — each response returns `hasNext: true/false` and a `next` cursor.

### Key endpoints

| Endpoint | What it returns |
|---|---|
| `GET /opportunities` | All opportunities (applications + contact inline) |
| `GET /opportunities/{id}/stage_changes` | Stage history per opportunity |
| `GET /opportunities/{id}/notes` | Notes per opportunity |
| `GET /opportunities/{id}/feedback` | Scorecard responses |
| `GET /opportunities/{id}/interviews` | Interview records |
| `GET /opportunities/{id}/files` | Attachments |
| `GET /opportunities/{id}/offers` | Offer details |
| `GET /postings` | Job postings |
| `GET /stages` | Pipeline stage definitions |
| `GET /users` | Team members |
| `GET /tags` | Tag taxonomy |
| `GET /sources` | Source taxonomy |

### Stage history

Stage changes require a **separate request per opportunity**. For 10,000 opportunities, that's 10,000 extra API calls. At 300 req/min: ~33 minutes just for stage history.

**Mitigation:** Batch stage history requests in parallel (10 concurrent), use incremental checkpointing, and cache already-fetched records.

### Documents

Files returned as `{id, name, ext, downloadUrl}`. The `downloadUrl` is a short-lived pre-signed URL.

**Critical gotcha:** Lever's download URLs expire in **under 1 hour**. The migration must download each file immediately after fetching the file record — not in a batch step later.

### Deduplication strategy

```
For each Opportunity:
  1. Normalize every contact email and phone (Opportunities[].contact.emails[], .phones[])
  2. Look up an existing Big Buck person by any of them (person_contact_points is unique per normalized value)
  3. If found: link the new Application to that Person and add any new contact points
  4. If not found: create the Person with all contact points, then create the Application
  5. If different emails match different people: create the Application on the first match and queue a merge suggestion
```

Lever's Contact maps one-to-one to a Big Buck `Person` ([`data-model.md`](./data-model.md#person)), so this is a direct mapping rather than a reconstruction.

### Practical gotchas

- **Confidential opportunities:** Require `confidential_data` scope on API key. Without it they're excluded silently.
- **Archived opportunities:** Lever returns them in the main list with `archived.reason`. Map these to `status: rejected` or `status: withdrawn` based on reason.
- **Tags on contacts vs. opportunities:** Contact-level tags ≠ opportunity-level tags. Both need to be imported as candidate and application tags respectively.
- **Multiple emails per contact:** Lever allows many email addresses per contact. Extract all and store each as a row in `person_contact_points`.

---

## Ashby — deep dive

### API style

Ashby uses **POST for read operations** (not GET), which is non-standard but functional. All list operations accept filter params in the request body.

```bash
# Ashby's pattern (unusual but consistent)
POST https://api.ashbyhq.com/candidate.list
Content-Type: application/json
{"limit": 100, "cursor": "next_cursor_value"}
```

### Key endpoints

| Endpoint | What it returns |
|---|---|
| `POST /candidate.list` | Candidates with pagination |
| `POST /job.list` | Jobs |
| `POST /application.list` | Applications (links candidates to jobs) |
| `POST /interview.list` | Interviews |
| `POST /scheduledInterview.list` | Scheduled interview instances |
| `POST /offer.list` | Offers |
| `POST /applicationFeedback.list` | Scorecards |

### Stage history

Available via the `GET /application/{id}` response, which includes an `history` array of stage changes with timestamps. Requires a per-application request.

### Practical gotchas

- **API tier gating:** Some endpoints (offers, feedback) require an enterprise API tier. Validate access before committing to a migration.
- **Rate limits:** Not publicly documented; observed ~60 requests per minute before throttling. Be conservative.
- **Newer platform:** Historical data is generally complete for companies using Ashby from the start. Companies that migrated *into* Ashby may have import artifacts in their data.
- **Custom fields:** Available but schema varies per implementation — always run `generate-map` first.

---

## SmartRecruiters — deep dive

### Authentication

OAuth 2.0 (company-level auth, not user-level). Client credentials flow for service-to-service.

### Data model

SmartRecruiters separates candidates and job applications cleanly — closer to Big Buck than Lever. A candidate can have applications to multiple jobs.

### Key endpoints

| Endpoint | What it returns |
|---|---|
| `GET /candidates` | All candidates |
| `GET /jobs` | All jobs |
| `GET /jobs/{id}/candidates` | Applications for a specific job |
| `GET /candidates/{id}/jobs/{jobId}` | Application detail |
| `GET /candidates/{id}/jobs/{jobId}/offer` | Offer |
| `GET /candidates/{id}/jobs/{jobId}/interviews` | Interviews |
| `GET /candidates/{id}/jobs/{jobId}/screeningQuestions` | Application form answers |

### Stage history

`GET /candidates/{id}/jobs/{jobId}/statusHistory` returns the sequence of status changes. Less granular than Greenhouse but sufficient for audit.

### Practical gotchas

- **No bulk candidate export:** Must paginate through `/candidates` then fetch each application separately — O(n) requests for n applications.
- **Attachments:** Available via candidate profile; download URLs are time-limited.
- **Application form answers:** Stored as screening question responses — not a standard field map. Requires custom field mapping.

---

## iCIMS — deep dive

### API reality

iCIMS has a documented REST API but it is **not a reliable migration path for most customers** without enterprise API access. The practical migration strategy for iCIMS is:

1. Request a **data export** from iCIMS directly (they provide SFTP-delivered CSV or XML bundles on enterprise plans)
2. Parse the SFTP export files using Big Buck's CSV/XML adapter
3. Fall back to the REST API only for delta-sync after initial load

### REST API (for reference)

- Auth: OAuth 2.0 (customer-specific auth URLs)
- Base: `https://{customer}.icims.com/apis/v1/`
- Key objects: `people`, `jobs`, `workflows` (= applications)
- **Significant gotcha:** Every iCIMS customer has a bespoke field configuration. There is no universal schema. `generate-map` cannot produce a useful default — it requires a discovery session per customer.

### SFTP export (practical path)

iCIMS provides SFTP-delivered flat files in a proprietary XML schema. Parse using the XML adapter:

```bash
bigbuck import icims-xml --file ./icims-export/ --org acme-corp
```

Where `./icims-export/` contains the SFTP-downloaded XML files. Big Buck maintains an iCIMS XML schema parser that handles the most common field patterns.

---

## Workday — deep dive

### API reality

Workday is the hardest migration target. The data lives in a deeply hierarchical tenant model and the APIs are designed for integration, not extraction.

Two practical paths:

### Path 1: RAAS (Reports as a Service) — recommended

RAAS allows a Workday admin to create a custom report and expose it as a REST or SOAP endpoint. This is the most reliable extraction method.

```
1. Workday admin creates RAAS reports for:
   - Job Requisitions
   - Candidates (Evergreen Requisition Candidates)
   - Applications (Worker Application Records)
   - Offer Letters
   - Interview Schedules

2. Reports exposed as REST endpoints:
   GET https://{tenant}.workday.com/ccx/service/customreport2/{tenant}/{report_name}?format=json

3. bigbuck import workday-raas --endpoint $RAAS_URL --token $TOKEN
```

Workday admin effort: 2–4 hours to set up the RAAS reports. Worth it.

### Path 2: Workday REST API (partial coverage)

- Auth: OAuth 2.0 with WID (Workday ID) service account
- Base: `https://{tenant}.workday.com/api/v1/`
- Key resources: `jobRequisitions`, `workers`, `candidates`
- **Gotcha:** The Workday REST API coverage of the ATS domain (Staffing module) is incomplete. Historical applications and interview records often require SOAP (Workday Web Services) to access.

### Practical reality

When migrating a company on Workday:
- Frame it as: "Your Workday admin runs 5 RAAS reports. We ingest them. Done."
- Do NOT promise API-based extraction without confirming the customer's Workday API tier.
- Workday ATS data completeness depends heavily on how the customer configured their Workday implementation.

---

## SAP SuccessFactors — deep dive

### API surface

OData v2 API. Key entities for ATS migration:
- `JobRequisition` — requisitions
- `Candidate` — candidate records
- `JobApplication` — applications
- `JobApplicationInterview` — interviews
- `JobOffer` — offers

### Practical path

Like Workday, most SuccessFactors migrations use **Integration Center** (SAP's ETL tool) to generate flat-file exports, which are then ingested via Big Buck's CSV adapter.

Direct API extraction is possible but requires:
- OData query expertise
- Customer-specific entity customizations (SuccessFactors implementations are heavily customized)
- High rate limit patience (OData responses are verbose)

---

## CSV / generic import — the universal fallback

Every ATS can export *something* to CSV. Even when the API is locked, the UI usually has a "Download all candidates" button. The CSV adapter is the backstop.

### CSV adapter capabilities

```bash
# Basic import with column detection
bigbuck import csv --file candidates.csv --org acme-corp

# With explicit mapping
bigbuck import csv \
  --file candidates.csv \
  --mapping ./mappings/greenhouse-csv.yaml \
  --org acme-corp

# Multiple files (candidates + applications + jobs)
bigbuck import csv \
  --candidates candidates.csv \
  --applications applications.csv \
  --jobs jobs.csv \
  --mapping ./mappings/custom.yaml
```

### Auto-detection

The CSV adapter attempts to auto-detect columns for common ATS export formats. Known patterns:

| ATS | Known export columns | Auto-detect |
|---|---|---|
| Greenhouse | `first_name, last_name, email, phone, job_name, stage, applied_at` | ✓ |
| Lever | `Contact Name, Email, Opportunity, Stage, Archived` | ✓ |
| Ashby | `First Name, Last Name, Email, Job, Stage, Created At` | ✓ |
| Workable | `Candidate, Email, Job, Stage, Applied On` | ✓ |
| Breezy HR | `Name, Email, Position, Stage, Date Added` | ✓ |
| Generic | Column header fuzzy match | Partial |

---

## Field mapping strategy

### Canonical field map — people (candidates and prospects)

| Big Buck field | Greenhouse | Lever | Ashby | CSV fallback |
|---|---|---|---|---|
| `first_name` | `first_name` | `contact.name` (split) | `name.firstName` | `first_name` or `name` (split) |
| `last_name` | `last_name` | `contact.name` (split) | `name.lastName` | `last_name` or `name` (split) |
| `person_contact_points` (email) | all `email_addresses[]` | all `contact.emails[]` | `primaryEmail` + `emailAddresses[]` | `email` |
| `person_contact_points` (phone) | all `phone_numbers[]` | all `contact.phones[]` | `phoneNumber` + `phoneNumbers[]` | `phone` |
| `lifecycle_stage` | `prospect` if every application has `prospect: true`, else `candidate` | `candidate` (prospects have no application) | `candidate` | `candidate` |
| `headline` | `title` | `contact.headline` | `headline` | `title` or `headline` |
| `location` | `addresses[0].value` | `contact.location.name` | `location.name` | `location` or `city` |
| `source` | `source.public_name` | `sources[0]` | `sourceName` | `source` |
| `source_platform` | `'greenhouse'` | `'lever'` | `'ashby'` | `'csv_import'` |

### Canonical field map — applications

| Big Buck field | Greenhouse | Lever | Ashby |
|---|---|---|---|
| `status` | derived from `status` | derived from `archived.reason` + `stageChanges` | derived from `status` |
| `current_stage_id` | `current_stage.name` | `stage` | `currentInterviewStage.title` |
| `applied_at` | `applied_at` | `createdAt` | `createdAt` |
| `archived_at` | `rejected_at` | `archived.archivedAt` | `archivedAt` |
| `source` | `source.public_name` | `sources[0]` | `sourceName` |

### Stage mapping

Stage names are ATS-specific and company-specific. The `generate-map` command generates a `stages.yaml` that must be reviewed:

```yaml
# stages.yaml — edit before running full import
stage_mappings:
  - source_name: "Application Review"
    bigbuck_stage: "resume_screen"
    sequence: 1
  - source_name: "Phone Screen"
    bigbuck_stage: "phone_screen"
    sequence: 2
  - source_name: "Technical Interview"
    bigbuck_stage: "technical"
    sequence: 3
  - source_name: "Offer"
    bigbuck_stage: "offer"
    sequence: 4
  # Unmapped stages will be created as-is with a warning
```

Once reviewed, `generate-map` can also write the result as a pipeline file in the [Recruiting as Code](./recruiting-as-code.md) format (`bigbuck/pipelines/<job-family>.yaml`). The migrated pipeline then lives in the customer's repository from day one, and later changes go through `plan` and `apply` like any other.

---

## Document / file migration

Documents are the most fragile part of any ATS migration.

### Strategy

```
1. Extract document metadata (filename, type, source URL) during main import
2. Queue document download tasks separately (worker pool, not serial)
3. Download from source (respect rate limits — Greenhouse: no doc-specific limit; Lever: aggressive)
4. Virus scan on arrival (Cloud Security Command Center or ClamAV)
5. Upload to Big Buck Cloud Storage (org-scoped bucket path)
6. Create document record in Big Buck DB with storage_key
7. Link to candidate + application
8. Mark source URL as downloaded (don't re-download on retry)
```

### Document download worker

Documents are processed by a dedicated worker pool to avoid slowing main data migration:

```bash
# Start document migration separately after main import
bigbuck import greenhouse \
  --job-id imp_abc123 \
  --include documents \
  --document-workers 10 \
  --resume
```

### URL expiry handling

| ATS | URL TTL | Strategy |
|---|---|---|
| Greenhouse | ~24 hours (configurable) | Download within migration window |
| Lever | < 1 hour | Download immediately on record fetch |
| Ashby | ~4 hours | Batch download phase after extraction |
| SmartRecruiters | ~2 hours | Same as Ashby |

For Lever specifically: the extraction adapter downloads documents inline during the opportunity fetch, not in a separate phase.

---

## Incremental sync (dual-run mode)

Many companies want to run Big Buck alongside their existing ATS for 30–90 days before cutting over. The sync engine supports this.

### How it works

1. **Initial full import** — migrate all historical data
2. **Ongoing sync** — poll source ATS for new/updated records every N minutes
3. **Cutover** — stop syncing, decommission source ATS

```bash
# Set up ongoing sync
bigbuck sync greenhouse \
  --api-key $GH_KEY \
  --org acme-corp \
  --interval 30m \
  --entities candidates,applications,documents

# Sync runs via Cloud Scheduler → Solid Queue worker
# Webhook-based sync (faster, where source supports it)
bigbuck sync greenhouse --webhook-mode
```

### Sync conflict resolution

During dual-run, the same record may be updated in both systems. Policy:

- **Source wins by default** — source ATS is authoritative during transition
- **Big Buck writes are preserved** — notes, scorecards, and stage moves made in Big Buck are not overwritten by sync
- **Conflict log** — all conflicts recorded in the import job audit trail

### Webhook-based sync (where available)

For Greenhouse and Lever (both have webhooks), real-time sync is possible:

```
Greenhouse webhook → bigbuck /integrations/greenhouse/webhook
   → verify signature
   → parse event type
   → enqueue sync task for affected record
   → worker fetches updated record via API
   → upsert into Big Buck
```

---

## Data model extensions for the migration engine

These additions build on the `import_jobs` and `import_staging_records` tables above.

### `external_source_refs` table

Preserves the original IDs from the source ATS on every migrated record. This is critical for:
- Resuming failed migrations (don't re-create records that already exist)
- Running incremental sync (look up Big Buck record by source ID)
- Audit and support (trace a Big Buck record back to its Greenhouse ID)

```sql
CREATE TABLE external_source_refs (
  id              VARCHAR(36) PRIMARY KEY,
  organization_id VARCHAR(36) NOT NULL,
  entity_type     VARCHAR(64) NOT NULL,   -- 'person', 'application', 'job', 'document'
  entity_id       VARCHAR(36) NOT NULL,   -- Big Buck entity ID
  source_system   VARCHAR(64) NOT NULL,   -- 'greenhouse', 'lever', 'ashby'
  source_id       VARCHAR(255) NOT NULL,  -- original ID in source system
  source_url      TEXT,                   -- original URL if applicable
  created_at      DATETIME(6) NOT NULL,
  UNIQUE KEY idx_ext_source_lookup (organization_id, source_system, entity_type, source_id),
  KEY idx_ext_source_entity (organization_id, entity_type, entity_id)
);
```

---

## Build sequence

### Phase 1 — Foundation

- `import_jobs` table (already in schema)
- `import_staging_records` table
- `external_source_refs` table
- CLI: `bigbuck import csv` with auto-detection for Greenhouse and Lever CSV exports
- Worker: basic CSV load pipeline (extract → transform → load)
- CLI: `bigbuck import status` and `bigbuck import verify`

**Demo target:** Import a 500-candidate Greenhouse CSV export in under 60 seconds via CLI.

### Phase 2 — API adapters (post-seed, Month 2–4)

- Greenhouse Harvest API adapter (full — candidates, applications, jobs, users, documents, scorecards, offers)
- Lever v1 API adapter (full — opportunities, notes, feedback, files, stage history)
- CLI: `bigbuck import greenhouse` and `bigbuck import lever` with all flags
- CLI: `bigbuck import generate-map`
- Document download worker with virus scan

**Demo target:** Full Greenhouse API migration of 10,000 candidates in under 2 hours.

### Phase 3 — Broader coverage (Month 4–8)

- Ashby API adapter
- SmartRecruiters API adapter
- iCIMS XML (SFTP export) adapter
- Workday RAAS adapter
- Incremental sync engine (`bigbuck sync`)
- Webhook-based real-time sync for Greenhouse and Lever

### Phase 4 — Enterprise (Month 8+)

- SAP SuccessFactors OData adapter
- Oracle Taleo adapter
- Custom mapping UI (web-based field mapper for non-technical admins)
- Migration project dashboard (multi-phase progress, ETA, validation reports)
- Dedicated migration support tier (for Enterprise customers)

---

## Open questions

1. **Rate limit handling for large Lever migrations** — stage history requires one request per opportunity. At 50,000 opportunities and 300 req/min, that's ~2.7 hours just for stage history. Is parallel fetching at 10x safe without violating ToS?
2. **Workday without RAAS access** — some customers won't have a Workday admin willing to set up RAAS reports. What is the fallback? Manual CSV? Block the deal?
3. **Document storage costs during migration** — a 10,000-candidate import with 2 documents each = 20,000 file downloads. At 1 MB average = 20 GB. Cloud Storage egress + storage cost is minimal but should be disclosed to customers.
4. **Confidential candidates in source ATS** — Greenhouse confidential jobs require special API key scope. If the migration key doesn't have this permission, confidential candidates are silently excluded. Verification step must flag this.
5. **User mapping for historical records** — stage transitions created by users who no longer exist in the source ATS. Map to a "Imported / Unknown Actor" system user or drop the actor reference?
