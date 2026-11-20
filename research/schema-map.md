# 09 — ERD-Style Schema Map

> **Updated 2026-10-24:** `candidate` is now `person`, pipelines are reusable and versioned, and the talent CRM entities (companies, projects, sequences, timeline) and config revisions are added. See [`data-model.md`](./data-model.md).

## Goal

Translate the ATS data model into a relationship map that is easy to reason about before implementation.

This is not a final database migration. It is the canonical shape of the product.

## Core relationship principles

- `organization` is the root boundary for nearly every record
- `requisition` is distinct from `job`
- `job` is distinct from `posting`
- `person` is distinct from `application`, and exists before any application (prospects)
- `application` is the central workflow object
- `pipeline` is shared by many jobs and versioned; applications point at a version
- `organization` is the tenant; external employers are `company` records
- every job has its own pipeline, built from a template plus that job's edits; interviews are defined inside stages
- departments, locations and any other company structure are `dimensions` with values in a tree
- `stage_transition` is append-only history
- `audit_event` is append-only system history
- custom fields are normalized, not blobbed
- integrations, webhooks, and imports are first-class platform objects

## High-level ERD

```text
organization
  ├── users (through memberships)
  │     └── membership_scopes  (→ membership_scope_conditions → dimension_value)
  ├── dimensions
  │     └── dimension_values  (tree, + closure table, + typed attributes)
  ├── entity_dimension_values  (tags on requisitions, jobs, postings, users)
  ├── organization_variables
  ├── hiring_teams
  ├── scorecard_templates
  ├── pipelines  (templates, and one job pipeline per job)
  │     ├── pipeline_overrides  (a job's edits)
  │     └── pipeline_versions
  │           └── pipeline_stages
  │                 └── stage_interviews
  ├── requisitions
  │     └── jobs  (→ pipeline)
  │           ├── postings
  │           └── applications  (→ person, → pipeline_version)
  │                 ├── stage_transitions
  │                 ├── notes
  │                 ├── interviews  (→ calendar event)
  │                 │     └── scorecards
  │                 ├── offers
  │                 │     └── offer_versions
  │                 │           ├── approvals  (→ approval_policy_step)
  │                 │           ├── offer_documents
  │                 │           ├── signature_requests
  │                 │           └── offer_responses
  │                 ├── scheduling_links
  │                 │     └── availability_requests
  │                 ├── scheduled_messages
  │                 └── documents
  ├── people
  │     ├── person_contact_points
  │     ├── person_affiliations  (→ company)
  │     ├── consents  (→ consent_purpose, → notice_version)
  │     ├── notice_receipts
  │     ├── data_requests
  │     ├── communications
  │     ├── timeline_events
  │     └── documents
  ├── companies
  ├── projects
  │     └── project_members  (→ person, → pipeline_version)
  ├── sequences
  │     ├── sequence_steps
  │     └── sequence_enrollments  (→ person)
  │           └── sequence_events
  ├── config_revisions
  ├── approval_policies
  │     └── approval_policy_steps
  ├── offer_templates
  ├── message_templates
  │     └── message_template_locales
  ├── mailbox_connections  (personal and shared Gmail)
  │     └── mailbox_connection_senders
  ├── calendar_connections
  │     └── calendar_watch_channels
  ├── interviewer_pools
  │     └── interviewer_pool_members  (→ user with interviewer_profile)
  ├── compliance_policies
  ├── notices
  │     └── notice_versions
  ├── consent_purposes
  ├── approvals
  ├── sources
  ├── tags
  ├── resource_access_lists
  │     └── resource_access_list_members
  ├── entity_status_history
  ├── integrations
  ├── webhook_subscriptions
  │     └── webhook_deliveries
  ├── import_jobs
  ├── export_jobs
  ├── audit_events
  ├── field_visibility_rules
  └── custom_field_groups
        └── custom_field_definitions
              └── custom_field_values
```

## Entity relationship map

### Organization
**Relationships**
- has many memberships
- has many departments
- has many locations
- has many hiring teams
- has many requisitions
- has many jobs
- has many people
- has many companies
- has many pipelines
- has many projects and sequences
- has many config revisions
- has many applications indirectly through jobs
- has many approvals
- has many sources
- has many tags
- has many resource access lists
- has many integrations
- has many webhook subscriptions
- has many audit events
- has many entity status history records
- has many custom field groups and definitions
- has many field visibility rules
- has many import/export jobs

**Notes**
- everything important is org-scoped
- org is the authorization boundary and the reporting boundary

### User
**Relationships**
- has many memberships
- has many notes authored
- has many scorecards authored
- has many offers or approvals initiated
- may be owner/assignee on requisitions and jobs

**Notes**
- user is identity; membership is tenancy access

### Membership
**Relationships**
- belongs to organization
- belongs to user
- belongs to role

**Notes**
- this is the bridge between identity and tenant access
- explicit membership state beats implicit access

### Role and Permission
**Relationships**
- role has many permissions through role_permissions
- membership belongs to one primary role

**Notes**
- keep permissions normalized so the product can support enterprise RBAC cleanly

### Resource Access List
**Relationships**
- belongs to organization
- may attach to person, application, requisition, job, offer, document, project, or other sensitive resource
- has many members/users/roles

**Notes**
- this supports confidential records and explicit allow-lists
- use this for cases where role-based access is not sufficient

### Field Visibility Rule
**Relationships**
- belongs to organization
- belongs to field group or field definition
- may reference one or more roles, permissions, or access scopes

**Notes**
- this is how we hide compensation, PII, legal, or internal fields without duplicating records
- field visibility is separate from record visibility

### Entity Status History
**Relationships**
- belongs to organization
- belongs to any lifecycle-controlled entity such as requisitions, jobs, postings, applications, interviews, offers, approvals, or documents
- records all lifecycle transitions

**Notes**
- this is the append-only history layer for workflow state machines
- it complements stage transitions and audit events

### Dimension and Dimension Value (replaces Department and Location)
**Relationships**
- dimension belongs to organization and has many values
- a value may have a parent value in the same dimension
- values tag requisitions, jobs, postings, users (and other records the dimension applies to)
- values carry typed attributes through custom field values
- membership scope conditions reference values; a scope's conditions are ANDed across dimensions and ORed within one

**Notes**
- `department` and `location` are seeded system dimensions; companies add their own (discipline, level, business unit, region)
- location keeps city, region, country and timezone as system attributes
- the same tags drive permissions, reporting, default templates, approvals and template variables; see [`org-structure.md`](./org-structure.md)

### Hiring Team
**Relationships**
- belongs to organization
- may have many jobs
- may have many users through team membership

**Notes**
- hiring team should be explicit so recruiters, hiring managers, and coordinators can be modeled cleanly
- enterprise ATSs almost always need this for visibility and permissions

### Approval
**Relationships**
- belongs to organization
- may belong to requisition, job, or offer
- may reference approver users or roles

**Notes**
- approvals are a first-class enterprise concern
- approval history should be auditable and stage-aware

### Source Attribution
**Relationships**
- belongs to organization
- may belong to person, application, or posting
- may reference campaign, referral, import, or partner source data

**Notes**
- source tracking is critical for reporting and channel effectiveness
- keep source metadata explicit instead of burying it in notes or free-form text

### Communication
**Relationships**
- belongs to organization
- belongs to a person; may also reference an application, interview or sequence enrollment
- may have many messages, email events, and scheduling events

**Notes**
- communications should be first-class so outreach and scheduling can be audited
- this becomes especially important for integrations and candidate experience

### Tag
**Relationships**
- belongs to organization
- may be attached to people, jobs, requisitions, applications, projects, and documents

**Notes**
- tags are useful for search, segmentation, and workflow grouping
- keep them normalized and tenant-scoped

### Custom Field Group
**Relationships**
- belongs to organization
- may scope to any core entity or sub-entity group
- has many custom field definitions

**Notes**
- this is how Big Buck supports custom fields in any group without flattening the model
- groups can be reusable templates or entity-specific sections

### Requisition
**Relationships**
- belongs to organization
- may have many jobs
- may have one owner user
- may reference department, location, employment type, and headcount controls

**Notes**
- requisition is the approval and demand object
- it should survive even if postings change

### Job
**Relationships**
- belongs to organization
- belongs to requisition
- has many postings
- has many pipeline stages
- has many applications
- has many custom field values

**Notes**
- job is the working recruiting object
- one requisition may map to one or more jobs if the product later needs that flexibility

### Posting
**Relationships**
- belongs to organization
- belongs to job

**Notes**
- posting is the published surface
- it can have channel-specific metadata without contaminating the core job record

### Person (formerly Candidate)
**Relationships**
- belongs to organization
- has many contact points (unique per organization, the dedupe key)
- has many affiliations, each to a company
- has many consents
- has many applications
- has many project memberships
- has many sequence enrollments
- has many communications and timeline events
- has many documents
- may have many tags
- may have many custom field values
- may have one or more resource access list entries when confidential

**Notes**
- one record per human, from prospect to alumni; "candidate" is the product term for a person with an application
- deduplication is enforced by unique contact points, with merge suggestions for fuzzy matches
- keep a separate provenance trail for imported people
- person visibility should be explicit and auditable

### Company
**Relationships**
- belongs to organization
- has many affiliations (people who work or worked there)

**Notes**
- named `company` so it never collides with `organization`, the tenant

### Project and Project Member
**Relationships**
- project belongs to organization, optionally to a job and a pipeline
- project member belongs to project and person, and to a pipeline version and current stage when the project has a pipeline
- a converted member references the application it became

**Notes**
- a person appears in a project once
- conversion keeps sourcing attribution into hiring reports

### Sequence and Enrollment
**Relationships**
- sequence has many ordered steps
- enrollment belongs to sequence and person, optionally to a project member, and sends from a mailbox connection
- enrollment has many sequence events, which may reference communications

### Config Revision
**Relationships**
- belongs to organization
- has a parent revision
- creates pipeline versions, field definitions, templates and other configuration

**Notes**
- append-only and numbered; every configuration surface (UI, CLI, API, CI) writes one

### Application
**Relationships**
- belongs to organization
- belongs to job
- belongs to person
- belongs to pipeline version
- belongs to current stage (which must be in that version)
- has many stage transitions
- has many notes
- has many interviews
- has many scorecards
- has many documents
- has many offers
- may have one or more resource access list entries when confidential

**Notes**
- this is the most important transactional entity in the ATS
- application state should be current, but history must be immutable
- application visibility should be explicit and can differ from person visibility

### Pipeline, Pipeline Version, Pipeline Stage
**Relationships**
- pipeline belongs to organization and is used by many jobs (or projects)
- pipeline has many immutable versions; one is current
- version has many stages
- stage has many stage transitions as source or destination

**Notes**
- stages define workflow shape
- stage ordering must be explicit and deterministic
- stage keys are stable across versions; stage `type` is a fixed enum for cross-job reporting

### Stage Transition
**Relationships**
- belongs to organization
- belongs to application or project member (exactly one)
- belongs to from stage
- belongs to to stage
- optionally belongs to actor user
- optionally belongs to automation or agent actor

**Notes**
- this is the canonical workflow history table
- append-only, never edited in place

### Note
**Relationships**
- belongs to organization
- belongs to application
- belongs to author user

**Notes**
- visibility should be modeled, not inferred
- support internal-only and shared note types

### Interview
**Relationships**
- belongs to organization
- belongs to application
- may have many scorecards
- may have assigned interviewers/users

**Notes**
- interviews should be schedulable independently from the stage move that created them

### Scorecard / Feedback
**Relationships**
- belongs to organization
- belongs to application
- belongs to interview
- belongs to author user

**Notes**
- scorecards are structured and auditable
- keep numeric scores and textual feedback separate

### Document
**Relationships**
- belongs to organization
- may belong to person
- may belong to application
- may be referenced by offer or interview artifacts

**Notes**
- document bytes live in object storage
- the DB stores metadata and access control context

### Offer
**Relationships**
- belongs to organization
- belongs to application
- may reference documents/signature artifacts
- may require approval records later

**Notes**
- offer should not be collapsed into application status
- it is a separate business object with its own lifecycle

### Audit Event
**Relationships**
- belongs to organization
- references any entity type and entity id
- may reference actor user or integration

**Notes**
- this is the universal system history stream
- it should capture all writes, not just high-value ones

### Custom Field Definition
**Relationships**
- belongs to organization
- belongs to custom field group
- may be scoped to requisition, job, person, company, application, project, interview, offer, or any future entity group
- has many custom field values

**Notes**
- schema-backed extensibility is required for enterprise adoption
- fields should be reusable across groups when that improves consistency

### Custom Field Value
**Relationships**
- belongs to organization
- belongs to field definition
- belongs to one owning entity

**Notes**
- values should be strongly typed and queryable
- avoid a generic unstructured JSON solution as the primary path

### Integration
**Relationships**
- belongs to organization
- may own sync cursors, tokens, and mapping state
- may emit or consume webhook events

**Notes**
- integrations should be modeled as durable records; their credentials never appear in config files (see [`recruiting-as-code.md`](./recruiting-as-code.md))

### Webhook Subscription
**Relationships**
- belongs to organization
- has many webhook deliveries

**Notes**
- subscriptions are explicit contracts with delivery guarantees

### Webhook Delivery
**Relationships**
- belongs to webhook subscription
- references event payload and retries

**Notes**
- track response codes, retry counts, and final outcome

### Import Job / Export Job
**Relationships**
- belongs to organization
- may produce or consume many entities
- may reference source mappings and transformation logs

**Notes**
- bulk migration and sync flows should be auditable like normal writes

## Recommended cardinalities

### One-to-many
- organization → requisitions
- organization → people
- organization → jobs
- organization → applications
- pipeline → jobs
- pipeline → pipeline_versions
- job → applications
- person → applications
- person → contact points
- project → project_members
- sequence → sequence_enrollments
- application → notes
- application → interviews
- interview → scorecards
- organization → integrations
- organization → webhook_subscriptions
- webhook_subscription → webhook_deliveries

### Many-to-many
- users ↔ organizations through memberships
- people ↔ companies through affiliations
- people ↔ projects through project members
- roles ↔ permissions through role_permissions
- tags ↔ core entities through join tables if needed
- custom fields ↔ many entity types through scoped definitions

## Shape decisions that matter later

### Separate job from posting
This keeps public careers-site concerns from polluting the internal workflow model.

### Separate application from stage history
This makes analytics, audit, and workflow replay feasible.

### Separate person from application
This makes one person able to apply multiple times, and to be sourced before applying, without collapsing historical context or creating a second record for the CRM.

### Normalize custom fields into groups
This lets the schema support enterprise reporting, reusable sections, and avoids a dead-end JSON blob.

### Keep immutable history tables
This is required for trust, support, and compliance.

## Future-compatible extension points

These should be planned even if not implemented immediately:

- approvals
- interview panels
- offer signatures
- source attribution and campaign tracking
- analytics snapshots
- AI run provenance
- outbound messaging events
- candidate portal artifacts

## Final recommendation

The ERD should be optimized for a real ATS, not for a generic HR platform.

If a relationship makes workflow history, permissions, or reporting clearer, keep it explicit even if it adds tables.
