# 08 — ATS Data Model

> **Updated 2026-10-24 — unified ATS + talent CRM.** This revision applies the recommendations in [`competitor-api-deep-dive.md`](./competitor-api-deep-dive.md) §5:
>
> - `Candidate` becomes **`Person`**: one record per human, whether prospect, applicant, employee or alumni. "Candidate" stays the product term for a person with at least one application.
> - New talent CRM objects: **`Company`**, **`Project`** (talent pool), **`Sequence`** (outreach) and a per-person **timeline**.
> - Pipelines become **reusable and versioned** instead of being defined per job; stages carry a fixed `type` for cross-job reporting.
> - Reject, withdraw and hire are **lifecycle commands**, separate from stage moves (see [`workflow.md`](./workflow.md)).
> - New compliance objects: **`Consent`** and a separate **EEO** store.
> - Configuration (pipelines, fields, roles, automations) is versioned as **config revisions**, the backbone of [`recruiting-as-code.md`](./recruiting-as-code.md).
> - Every job has **its own pipeline**, built from a template plus that job's edits, with **interviews defined inside stages** ([`job-pipelines.md`](./job-pipelines.md)).
> - Departments and locations become **dimensions** that each company defines for itself, with custom attributes ([`org-structure.md`](./org-structure.md)).
>
> **Enterprise build, same day.** The talent CRM objects are in v1, not phase 2; matching, person visibility, sequence senders, legal holds and data classes follow [`architecture.md`](./architecture.md#design-rules).

## Goal

Define a best-in-class ATS data model that is:

- enterprise-grade
- auditable
- tenant-safe
- API-friendly
- workflow-aware
- extensible without becoming a blob of custom JSON

## Design principles

The data model should be shaped by the strongest patterns from enterprise ATS platforms:

- separate requisitions from postings and applications
- treat workflow transitions as first-class data
- model custom fields as schema, not as an afterthought
- keep provenance for every imported or automated record
- preserve complete audit history
- make webhooks and integrations part of the model, not external glue
- keep org boundaries explicit on every record

## Canonical system boundaries

Big Buck should have three distinct layers of recruiting data:

1. **Org-owned operating data**
   - users
   - roles
   - permissions
   - requisitions
   - jobs
   - pipeline definitions

2. **People, relationship and application data**
   - people (and their contact points, affiliations, consents)
   - companies
   - projects (talent pools) and their members
   - sequences and enrollments
   - communications and the person timeline
   - applications
   - documents
   - interviews
   - notes
   - scorecards

3. **Platform metadata**
   - config revisions (versioned pipelines, fields, roles, automations)
   - audit events
   - webhook subscriptions
   - webhook deliveries
   - integration configs
   - import jobs
   - export jobs
   - automation rules

## Core entity model

### Organization
The top-level tenant boundary.

Naming rule: `organization` always means **the tenant** (the Big Buck customer). External employers, agencies and clients are **`Company`** records, never organizations.

Minimum fields:
- `id`
- `name`
- `slug`
- `status`
- `createdAt`
- `updatedAt`

Rules:
- every business record belongs to exactly one organization unless explicitly shared
- permissions are evaluated in the context of the organization

### User
A person who can log into the system.

Minimum fields:
- `id`
- `email`
- `name`
- `status`
- `createdAt`
- `updatedAt`

### Membership
Connects users to organizations.

Minimum fields:
- `id`
- `organizationId`
- `userId`
- `roleId`
- `status`
- `createdAt`
- `updatedAt`

### Role / Permission
Use explicit roles and permissions, not implicit UI behavior.

Recommended shape:
- `roles`
- `permissions`
- `role_permissions`
- `membership_permissions` only if overrides are required

### Requisition
The approved hiring demand.

This is distinct from a posting.

Minimum fields:
- `id`
- `organizationId`
- `code`
- `title`
- `dimensions` — department, location and any company-defined dimensions (see [`org-structure.md`](./org-structure.md))
- `employmentType`
- `headcount`
- `status`
- `ownerUserId`
- `approvedAt`
- `createdAt`
- `updatedAt`

### Job
The hiring object the team works against.

A requisition can spawn one or more jobs/postings depending on the business model.

Minimum fields:
- `id`
- `organizationId`
- `requisitionId`
- `title`
- `summary`
- `description`
- `status`
- `visibility`
- `hiringTeamId`
- `pipelineId` — this job's own pipeline, built from a template (see [`job-pipelines.md`](./job-pipelines.md))
- `dimensions` — copied from the requisition, editable per job
- `createdAt`
- `updatedAt`

### Posting
The external or internal published representation of a job.

Minimum fields:
- `id`
- `organizationId`
- `jobId`
- `channel`
- `slug`
- `publishedAt`
- `closedAt`
- `status`
- `createdAt`
- `updatedAt`

### Person
The single record for a human. Replaces `Candidate`.

A person exists independently of any application, so the same record serves sourcing (CRM) and hiring (ATS). This is Lever's Contact → Opportunity shape, and it avoids Gem's problem of syncing two records for one human.

Minimum fields:
- `id`
- `organizationId`
- `firstName`
- `lastName`
- `preferredName`
- `primaryEmail` — denormalized from contact points for display and lookup
- `primaryPhone` — denormalized from contact points
- `headline`
- `location`
- `lifecycleStage` (`prospect`, `candidate`, `employee`, `alumni`)
- `ownerUserId` — the recruiter or sourcer who owns the relationship
- `doNotContact`, `doNotContactReason`
- `source`
- `visibility`
- `version` — optimistic concurrency, exposed as the API `ETag`
- `createdAt`
- `updatedAt`

Rules:
- one person per human per organization; deduplication runs on every create (see below)
- `lifecycleStage` moves forward automatically: the first application makes a prospect a `candidate`; a hire makes them an `employee`
- do not bury contact data in an opaque JSON blob
- records retain source and provenance

### Contact point
Every email, phone and profile URL a person has, so people with several addresses still dedupe.

Minimum fields:
- `id`
- `organizationId`
- `personId`
- `kind` (`email`, `phone`, `url`, `linkedin`, `github`)
- `value` — as entered
- `normalizedValue` — lower-cased email, E.164 phone, canonical URL
- `isPrimary`
- `source`
- `verifiedAt`
- `createdAt`

Rules:
- `(organizationId, kind, normalizedValue)` is unique among canonical contact points: an email or phone belongs to one person. A value that collides and cannot attach is kept as a **held duplicate** (`duplicateOfPersonId` set) and paired with a merge suggestion
- **matching on create** (updated 2026-10-24): an exact email match attaches the new application, pool membership or import row to the existing person, but never overwrites that person's fields; differing values are added as extra contact points or offered as suggestions
- phone, URL and name matches never attach automatically; the value is kept as a held duplicate and a merge suggestion goes to a human
- a person whose `lifecycleStage` is `employee` or `alumni` is matched only by a verified email or by a user
- **collisions are quiet** (decided 2026-10-24): a match never reveals anything about a person the caller cannot see. A candidate applying sees exactly what every other candidate sees. An internal caller whose new record collides with a hidden person gets an ordinary new record that keeps the value as a held duplicate; the merge suggestion is visible only to someone who can see both people. Adding the same person again attaches to the caller's own record ([`permissions.md`](./permissions.md#person-visibility))
- do-not-contact and consent are checked across every record that holds an address, canonical or duplicate, so a held duplicate can never be used to reach someone who opted out
- fuzzy matches (same name and company, different email) produce a merge suggestion for a human, never an automatic merge
- merges are explicit commands that keep the surviving id and record the merged ids in history

### Company
An external organization: a candidate's current or past employer, a sourcing target, an agency or (later) an agency client.

Minimum fields:
- `id`
- `organizationId`
- `name`
- `domain`
- `linkedinUrl`
- `industry`
- `sizeRange`
- `createdAt`
- `updatedAt`

### Affiliation
A person's role at a company over time.

Minimum fields:
- `id`
- `organizationId`
- `personId`
- `companyId`
- `title`
- `startDate`
- `endDate`
- `isCurrent`
- `source` (resume parse, import, manual, enrichment)
- `createdAt`

### Consent
What a person has agreed to, for which purpose, and what they were shown when they agreed. Updated 2026-10-24: purposes are defined by each company, not by Big Buck ([`consent-and-compliance.md`](./consent-and-compliance.md)).

Minimum fields:
- `id`
- `organizationId`
- `personId`
- `consentPurposeId` — a company-defined purpose such as `data-processing`, `talent-pool`, `recording`, `automated-tools`
- `noticeVersionId` — the exact notice text shown
- `compliancePolicyId` — the company policy that required it
- `lawfulBasis` — as the company declared it for the purpose
- `status` (`granted`, `withdrawn`, `expired`)
- `capturedVia` (`apply_form`, `email_link`, `company_form`, `import`, `recorded_by_user`)
- `capturedAt`
- `expiresAt`
- `evidence` — IP address, user agent, link used

Rules:
- append a new row for every change; never edit a consent row (the retention job may only anonymize the evidence)
- actions the company's policies block (outreach, provider-run interviews, adding to a talent pool) check for a current `granted` consent before running
- the company writes the purposes, notices and policies; Big Buck shows, records and enforces them

Related objects: **Compliance policy**, **Notice** and **Notice version**, **Consent purpose**, **Notice receipt**, **Data request**, **Retention action**.

### Application
The join between a person and a job.

This is the central ATS transaction object.

Minimum fields:
- `id`
- `organizationId`
- `jobId`
- `personId`
- `status` — lifecycle state (see [`workflow.md`](./workflow.md))
- `pipelineVersionId` — the exact pipeline version this application runs on
- `currentStageId`
- `source`
- `appliedAt`
- `rejectedAt`, `rejectionReasonKey`
- `withdrawnAt`
- `hiredAt`
- `archivedAt`
- `version`
- `createdAt`
- `updatedAt`

Rules:
- application status and stage are not the same thing: a rejected application keeps the stage it was rejected at, which is what funnel reporting needs
- application history must be retained even when the current stage changes
- one person can have multiple applications over time, but each application has a single current stage
- rejection reasons are structured keys from config, never free text (Ashby pattern)

### Pipeline
Either a **template** (org configuration, e.g. `engineering-hiring`) or a **job pipeline** (one per job, built from a template plus that job's own edits). Full design: [`job-pipelines.md`](./job-pipelines.md).

Minimum fields:
- `id`
- `organizationId`
- `scope` (`template`, `job`, `project`)
- `key` — templates only; stable identifier used in config files
- `name`
- `objectType` (`application`, `project_member`)
- `isDefault` — templates only; one default per object type
- `defaultFor` — templates only; dimension values this template is the default for (`discipline: backend`)
- `jobId`, `templatePipelineId`, `baseTemplateVersionId` — job pipelines only
- `linkMode` (`following`, `customized`, `detached`) — job pipelines only
- `needsReview` — a template update conflicted with this job's edits
- `currentVersionId`
- `status` (`active`, `archived`)
- `version`
- `createdAt`
- `updatedAt`

### Pipeline Override
One edit to one job's pipeline. The job pipeline is the base template version with its overrides applied in order.

Minimum fields:
- `id`
- `organizationId`
- `pipelineId`
- `position`
- `op` (`add_stage`, `update_stage`, `move_stage`, `remove_stage`, `add_interview`, `update_interview`, `remove_interview`)
- `targetStageKey`, `targetInterviewKey`
- `payload`
- `createdBy`, `createdAt`
- `revertedAt`

Rules:
- overrides target stable keys, never ids
- the job's edit wins on any field it sets; untouched fields keep following the template
- a template update re-applies the overrides; if one no longer fits, the job is held on its current version and flagged `needsReview`

### Pipeline Version
An immutable snapshot of a pipeline's stages and rules.

Minimum fields:
- `id`
- `organizationId`
- `pipelineId`
- `version` — 1, 2, 3…
- `definition` — the resolved stages, interviews, transitions and guards, each marked with its origin (`template` or `job`)
- `definitionHash`
- `baseTemplateVersionId`, `overridesHash` — for job pipelines
- `configRevisionId` — for templates, the config revision that created it
- `createdBy`
- `createdAt`

Rules:
- any change creates a new version; versions are never edited
- applications always run on their job pipeline's current version; a stage that still exists keeps its applications (matched by key)
- removing a stage that holds open applications requires a target stage, and each move is recorded as a transition
- every transition records the version it happened under, so history stays exact

### Pipeline Stage
One stage inside a pipeline version.

Minimum fields:
- `id`
- `organizationId`
- `pipelineVersionId`
- `key` — stable across versions, e.g. `recruiter-screen`
- `name`
- `position`
- `type` — fixed, cross-tenant enum used for reporting: `review`, `screen`, `assessment`, `interview`, `offer`, `other` for application pipelines; `sourced`, `contacted`, `engaged`, `other` for project pipelines
- `entryRequirements`, `exitRequirements` — guards such as a submitted scorecard or an approval
- `automationPolicy`
- `interviews` — the interviews held in this stage (see Stage Interview)
- `origin` (`template`, `job`)
- `lock` (`none`, `structure`, `full`) — `structure`: jobs may not remove, retype or move the stage but may change its interviews; `full`: only the template can change the stage or its interviews
- `createdAt`

Rules:
- stage keys are stable across versions, so mapping applications between versions is by key
- tenants name stages freely; `type` keeps funnel analytics comparable across jobs and tenants, including stages a single job added
- there are no terminal stages: hire, reject and withdraw are lifecycle commands

### Stage Interview
An interview defined inside a stage. Together, a stage's interviews are its interview plan; there is no separate plan object to keep in sync.

Minimum fields:
- `id`
- `pipelineVersionId`, `stageId`
- `key` — stable, unique within the pipeline
- `name`
- `format` (`phone`, `video`, `in_person`, `take_home`, `async_review`, `external`); `external` means run by a connected provider or agent
- `durationMinutes`
- `interviewerRules` — roles, pools or named users, and how many
- `scorecardTemplateId`
- `schedulingMode` (`self_schedule`, `availability_request`, `coordinator`, `manual`, `none`); see [`scheduling.md`](./scheduling.md#scheduling-modes)
- `required` — counts toward the stage's exit guard
- `providerKey`, `providerConfig` — for `external` interviews
- `communications` — confirmation and reminder templates, candidate instructions, interviewer briefing ([`candidate-communications.md`](./candidate-communications.md#per-interview-communications))
- `origin` (`template`, `job`)

Rules:
- entering a stage creates one `Interview` per stage interview and runs its scheduling mode
- `external` interviews check the consents the company's compliance policy requires before inviting ([`consent-and-compliance.md`](./consent-and-compliance.md))

### Scorecard Template
A reusable rubric: attributes evaluated, rating scale and questions. Referenced by stage interviews; configuration, so versioned through config revisions.

### Stage Transition
An immutable record of workflow movement.

Minimum fields:
- `id`
- `organizationId`
- `applicationId` or `projectMemberId` (exactly one)
- `fromStageId`
- `toStageId`
- `actorType`
- `actorId`
- `reason`
- `sourceSurface` (`web`, `cli`, `api`, `import`, `automation`, `agent`, `config`)
- `createdAt`

This should be append-only. Moves caused by pipeline changes are recorded as transitions with `reason = pipeline_edit` (a job edit) or `pipeline_upgrade` (a template update).

### Note
Human collaboration data.

Minimum fields:
- `id`
- `organizationId`
- `applicationId`
- `authorUserId`
- `body`
- `visibility`
- `mentions`
- `createdAt`
- `updatedAt`

### Interview
A scheduled or completed evaluation event, created from a stage interview when the application enters the stage.

Minimum fields:
- `id`
- `organizationId`
- `applicationId`
- `pipelineVersionId`, `stageInterviewKey` — which stage interview this is
- `format`
- `providerKey`, `externalSessionId` — for `external` interviews
- `scheduledStartAt`
- `scheduledEndAt`
- `status`
- `location`
- `meetingUrl`
- `createdAt`
- `updatedAt`

### Feedback / Scorecard
Structured evaluation from an interviewer or system.

Minimum fields:
- `id`
- `organizationId`
- `applicationId`
- `interviewId`
- `authorUserId`
- `score`
- `recommendation`
- `signals`
- `body`
- `createdAt`
- `updatedAt`

### Document
Any uploaded file or extracted artifact.

Minimum fields:
- `id`
- `organizationId`
- `personId`
- `applicationId`
- `kind`
- `fileName`
- `mimeType`
- `storageKey`
- `checksum`
- `sizeBytes`
- `extractionStatus`
- `createdAt`
- `updatedAt`

Rules:
- store only metadata in the database
- store bytes in object storage
- uploads are quarantined until a malware scan passes (`scanStatus`)
- support versioning for replaced documents

### Offer
The decision and compensation artifact. One live offer per application, with immutable versions. Full process in [`offers.md`](./offers.md).

Minimum fields:
- `id`
- `organizationId`
- `applicationId`
- `status` (`draft`, `pending_approval`, `changes_requested`, `approved`, `sent`, `accepted`, `declined`, `expired`, `rescinded`)
- `currentVersionId`
- `rescindReasonKey`
- `createdAt`
- `updatedAt`

Related objects:
- **Offer version** — immutable snapshot of offer field values, template, documents and approval state
- **Offer fields** — a custom field group with `entity: offer`; fields can be `requiresReapproval` and carry visibility rules (compensation)
- **Offer template** — the letter, with tokens; available by dimension values
- **Approval policy** — conditions and ordered approver steps, shared with requisitions
- **Signature request** — the send: link, signers, provider (`click_to_accept` in v1)
- **Offer response** — accept or decline, with evidence

### Activity / Audit Event
The system log of meaningful changes.

Minimum fields:
- `id`
- `organizationId`
- `entityType`
- `entityId`
- `action`
- `actorType`
- `actorId`
- `requestId`
- `before`
- `after`
- `diff`
- `sourceSurface`
- `createdAt`

This is mandatory for all write paths.

## Talent CRM objects

In v1 (updated 2026-10-24). These sit in the same API, permissions, audit and search as the ATS objects. That is the point of the unified model: no second record to sync.

### Project
A talent pool: a named group of people being sourced or nurtured, optionally tied to a job.

Minimum fields:
- `id`
- `organizationId`
- `key`
- `name`
- `description`
- `ownerUserId`
- `jobId` — optional; a sourcing project for an open job
- `pipelineId` — optional; a project pipeline such as sourced → contacted → engaged
- `confidential` — hidden from everyone outside its access list; forced on when `jobId` is a confidential job ([`permissions.md`](./permissions.md#confidential-sourcing))
- `codename` — shown instead of `name` wherever the project might be seen outside its access list
- `targetCompanyIds` — companies being sourced from; hidden with the project when it is confidential
- `status` (`active`, `archived`)
- `createdAt`
- `updatedAt`

### Project Member
A person in a project.

Minimum fields:
- `id`
- `organizationId`
- `projectId`
- `personId`
- `pipelineVersionId`
- `currentStageId`
- `status` (`active`, `converted`, `removed`)
- `convertedApplicationId` — set when the member becomes an applicant
- `addedByUserId`
- `source`
- `addedAt`
- `version`

Rules:
- a person appears in a project at most once
- converting a member creates an application on the project's job and records both ids, so sourcing attribution survives into hiring reports

### Sequence
A multi-step outreach cadence.

Minimum fields:
- `id`
- `organizationId`
- `key`
- `name`
- `status` (`draft`, `active`, `archived`)
- `stopOnReply`
- `stopOnApplication`
- `sendingPolicy` — sending window, time zone, daily cap per mailbox
- `createdAt`
- `updatedAt`

### Sequence Step
Minimum fields:
- `id`
- `organizationId`
- `sequenceId`
- `position`
- `kind` (`email`, `task`, `wait`)
- `delay`
- `messageTemplateId`
- `taskDescription`

### Sequence Enrollment
One person going through one sequence.

Minimum fields:
- `id`
- `organizationId`
- `sequenceId`
- `personId`
- `projectMemberId` — optional
- `senderUserId` — the user the sequence sends for
- `mailboxConnectionId` — the connected Gmail mailbox that sends: the sender's own, or a shared mailbox they may send as
- `status` (`active`, `paused`, `completed`, `stopped`)
- `currentStepPosition`
- `nextRunAt`
- `stoppedReason` (`replied`, `applied`, `bounced`, `unsubscribed`, `do_not_contact`, `manual`)
- `enrolledByUserId`
- `createdAt`

Rules:
- enrollment is refused when the person is `doNotContact` or lacks current `outreach` consent where the jurisdiction requires it
- a reply or a new application stops the enrollment automatically

### Mailbox Connection
A connected Gmail mailbox that sends and is synced (v1, decided 2026-10-24).

Minimum fields:
- `id`
- `organizationId`
- `kind` (`personal`, `shared`)
- `ownerUserId` — the recruiter, for personal mailboxes; the admin who connected it, for shared ones
- `emailAddress`
- `authMethod` (`oauth`, `domain_delegation`)
- `status` (`active`, `reauth_required`, `revoked`)
- `syncCursor` — Gmail history id and push watch expiry
- `dailySendLimit` — 2,000 by default, Google's Workspace cap

Rules:
- only people allowed by `mailboxConnectionSenders` may send as a shared mailbox
- only messages with a participant who matches a person are stored
- credentials live in Secret Manager, never in the database

### Communication
Every email, message, call or calendar event with a person. Extends the existing table.

Minimum fields:
- `id`
- `organizationId`
- `personId`
- `applicationId` — optional
- `sequenceEnrollmentId` — optional
- `channel` (`email`, `sms`, `call`, `calendar`, `inmail`)
- `direction` (`inbound`, `outbound`)
- `threadId`
- `mailboxConnectionId`
- `subject`
- `body`
- `status`
- `externalId`
- `sentAt`, `receivedAt`

### Timeline Event
A read model, not a source of truth: one row per thing that happened to a person (stage change, email, note, interview, project add), fed from the outbox. It backs the unified person feed and can be rebuilt at any time.

Minimum fields:
- `id`
- `organizationId`
- `personId`
- `occurredAt`
- `kind`
- `subjectType`, `subjectId`
- `summary`
- `visibility` — copied from the source record so feed reads respect note and scorecard visibility
- `sourceEventId`

### Config Revision
A numbered, immutable snapshot of an organization's configuration: pipelines, custom fields, roles, rejection reasons, automations, sequences and templates. Every change creates one, whether it came from the UI, the CLI or the API. See [`recruiting-as-code.md`](./recruiting-as-code.md).

Minimum fields:
- `id`
- `organizationId`
- `number`
- `parentRevisionId`
- `source` (`ui`, `cli`, `api`, `import`, `setup`) — `setup` for the owner setup ([`owner-setup.md`](./owner-setup.md))
- `actorType`, `actorId`
- `manifest` — the full configuration as of this revision
- `manifestHash`
- `plan` — the computed diff and impact that was applied
- `gitRepository`, `gitCommitSha` — when applied from CI
- `breakGlassSessionId` — set when the change was made during an emergency override of repository lock
- `status` (`applied`, `failed`)
- `appliedAt`

### Break Glass Session
A time-limited emergency override of repository lock: who opened it, why, which settings it covers, when it opened and closed, and the commit that brought the repository back in sync. See [`recruiting-as-code.md`](./recruiting-as-code.md#emergency-override-break-glass).

Rules:
- at most one open session per organization, at most 4 hours long, always with a written reason
- only the admin who opened it can edit during the window; every edit is a config revision tagged with the session
- the organization shows as out of sync with its repository until the session is reconciled

### EEO Response
Voluntary self-identification answers. Stored outside the operational schema with its own database role.

Minimum fields:
- `id`
- `organizationId`
- `applicationId`
- `questionKey`
- `answer`
- `collectedAt`

Rules:
- never joined into operational queries, search, the timeline, AI inputs or webhooks
- readable only through aggregate reporting views with a minimum group size

## Supporting schema objects

### Custom field groups
Use field groups to organize custom fields into reusable or entity-specific sections.

Examples:
- requisition details
- job details
- candidate profile
- application review
- interview feedback
- offer terms
- integration metadata

A group should carry:
- `key`
- `label`
- `entityScope`
- optional `parentGroupKey`
- `displayOrder`
- visibility rules

This lets us support custom fields in any part of the ATS without flattening the schema into one blob.

### Custom field definitions
Use a typed schema for extensibility.

Model:
- field group
- field name
- field type
- scope
- required/optional
- enum values
- validation rules
- visibility rules
- display order

### Custom field values
Store values in a relational structure tied to entity and field definition.

Avoid a single free-form JSON blob for everything.

Recommended shape:
- `entityType`
- `entityId`
- `fieldDefinitionId`
- `valueString`
- `valueNumber`
- `valueBoolean`
- `valueDate`
- `valueJson`
- `valueReferenceType`, `valueReferenceId` — for reference fields that point at a person, user, company or job

Use the typed column that matches the field. Reference fields exist because free-text names cannot be reported on; Ashby added a linked *Employee* field type for the same reason.

### Resource access lists
Use explicit allow-lists for confidential candidates, applications, offers, documents, or other sensitive records.

Model:
- resource type
- resource id
- list name
- principal type
- principal id
- permission level
- status

### Field visibility rules
Use explicit visibility rules for custom fields and field groups.

Model:
- field group or definition reference
- principal type
- principal id
- rule type
- effect
- conditions

### Tags / labels
Useful for search and workflow grouping.

Keep tags normalized and tenant-scoped.

### Dimensions (department, location and company-defined structure)
These are not optional enterprise niceties, and every company draws them differently.

Updated 2026-10-24: instead of fixed department and location tables, each organization defines **dimensions** (department, discipline, level, business unit, region, anything) with optional hierarchy and typed attributes on their values. Requisitions, jobs, postings and users are tagged with dimension values, and the same tags drive permission scopes, reporting, default pipeline templates, approval routing and template variables. `department` and `location` are seeded as system dimensions. Full design: [`org-structure.md`](./org-structure.md).

### Organization Variables
Typed key-value settings (careers URL, benefits link, recruiting inbox) used in message templates and automations as `{{ org.vars.<key> }}`. Configuration, versioned through config revisions.

### Teams
Hiring teams stay a separate object: they are groups of users with roles on a job, not a way of classifying the organization.

### Integration
Represents an external system connection.

Minimum fields:
- `id`
- `organizationId`
- `provider`
- `status`
- `authType`
- `scopes`
- `metadata`
- `createdAt`
- `updatedAt`

### Webhook subscription
A first-class outgoing event contract.

Minimum fields:
- `id`
- `organizationId`
- `eventType`
- `targetUrl`
- `secretRef`
- `enabled`
- `createdAt`
- `updatedAt`

### Webhook delivery
Tracks reliability and retry behavior.

Minimum fields:
- `id`
- `subscriptionId`
- `eventId`
- `status`
- `attempts`
- `responseCode`
- `lastAttemptAt`
- `deliveredAt`
- `createdAt`

### Import / export job
Used for migrations and bulk sync.

Minimum fields:
- `id`
- `organizationId`
- `type`
- `source`
- `status`
- `startedAt`
- `completedAt`
- `error`
- `createdAt`

## Provenance requirements

Every meaningful record should carry provenance where practical:

- who created it
- how it was created
- whether it was imported
- whether it was machine-generated
- which source system supplied it
- which user or integration last touched it
- which API surface caused the change

This is critical for audit, support, and AI traceability.

## Data capture rules

### What to capture on every write

- actor identity
- organization identity
- source surface
- request ID
- timestamp
- before and after values
- permission context
- external reference IDs
- validation errors, when relevant

### What not to lose

- prior stage history
- previous notes and feedback
- imported source references
- deleted document metadata if legally allowed
- webhook delivery attempts
- automation decisions

### What must stay out of shared “current state”

- internal reviewer notes that should remain private
- proprietary scoring logic
- transient UI state
- raw AI chain-of-thought or hidden reasoning
- duplicate computed fields that can be derived reliably

## Recommended invariants

1. Every record belongs to an organization unless explicitly shared.
2. Every state change is written as an immutable event or transition record.
3. Every application has a current stage and a transition history.
4. Requisitions and postings are separate concepts.
5. Custom fields are schema-backed.
6. Documents are stored outside the database.
7. Webhooks are delivery-tracked.
8. Audit data is append-only.
9. AI outputs store provenance.
10. Foreign-key integrity is preferred over loose JSON references.
11. One person per human per organization; contact points are unique.
12. Pipelines are versioned; every job has its own pipeline (template plus edits), and every transition records the version it ran under.
13. Hire, reject and withdraw are lifecycle commands, not stages.
14. Every configuration change is a numbered config revision, whatever surface made it.
15. Tenant isolation is enforced in two layers: the `TenantScoped` default scope (fails closed when no tenant is set) and composite `(organization_id, id)` foreign keys in the database (MySQL has no row-level security). See [`build-plan.md`](./build-plan.md#mysql-principles).
16. EEO data never leaves its own schema except as aggregates.
17. Applications and project members are the two pipeline subjects and share one shape, one transition history and one set of commands.
18. Every field has a data class; personal data never enters audit history as a value.

## Suggested implementation approach

### Start with these tables
- organizations
- users
- memberships
- roles
- permissions
- requisitions
- jobs
- postings
- people
- person_contact_points
- companies
- person_affiliations
- consents
- applications
- pipelines
- pipeline_overrides
- pipeline_template_defaults
- pipeline_versions
- pipeline_stages
- stage_interviews
- scorecard_templates
- stage_transitions
- dimensions
- dimension_values
- dimension_value_closure
- entity_dimension_values
- membership_scopes
- membership_scope_conditions
- organization_variables
- notes
- interviews
- scorecards
- documents
- audit_events
- custom_field_definitions
- custom_field_values
- config_revisions
- break_glass_sessions (ships with repository lock)
- webhook_subscriptions
- webhook_deliveries
- integrations
- import_jobs
- export_jobs
- outbox_events
- offers, offer_versions, offer_documents, offer_responses, signature_requests
- approval_policies, approval_policy_steps
- calendar_connections, calendar_watch_channels, interviewer_profiles, interviewer_pools, interviewer_pool_members
- scheduling_links, availability_requests
- message_templates, message_template_locales, scheduled_messages, mailbox_connections, mailbox_connection_senders
- compliance_policies, notices, notice_versions, consent_purposes, notice_receipts, data_requests, retention_actions

- legal_holds
- projects
- project_members
- sequences
- sequence_steps
- sequence_enrollments
- sequence_events
- timeline_events

### Add later if needed
- tasks
- mentions
- offer signatures
- search projections
- analytics snapshots
- AI job runs

## Final recommendation

Do not let the model become a generic HR schema.

Make the ATS spine first-class, keep the audit/provenance layer strong, and model extensibility explicitly. That gives Big Buck room to support enterprise requirements without losing clarity.
