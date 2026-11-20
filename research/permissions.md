# 18 — Permissions and Visibility Model

## Goal

Define how Big Buck should control access to records, actions, and fields so the product can support enterprise recruiting workflows safely.

This should cover both authorization and visibility.

## Core principle

Big Buck should use **layered access control**:

1. organization membership and role
2. resource-level permissions
3. ownership / assignment / collaboration scope
4. field-level visibility
5. integration scope
6. audit visibility

The UI should reflect these rules, but the server must enforce them.

## Why this matters

ATS data is sensitive.

A strong permissions model must protect:
- candidate identity and contact info
- interview feedback
- internal notes
- compensation and offer details
- requisition planning data
- integration secrets
- audit logs
- AI-generated recommendations and outputs

## Access-control layers

### 1) Organization membership
A user must belong to an organization before they can access tenant data.

Membership should define:
- organization
- role
- status
- optional team memberships
- optional temporary elevation

### 2) Role-based permissions
Roles should map to explicit permissions, not UI labels.

Examples:
- `requisition.read`
- `requisition.manage`
- `job.manage`
- `job.read_confidential` — see every confidential job and its applications without being on the access list (organization owner only, by default)
- `project.read_confidential` — see every confidential sourcing project and its members without being on the access list (organization owner only, by default)
- `job.pipeline.edit_stages` — add, remove, rename or reorder stages in a job's own pipeline ([`job-pipelines.md`](./job-pipelines.md))
- `job.pipeline.edit_interviews` — add, change or remove interviews in a job's own pipeline
- `job.pipeline.edit_locked_interviews` — change interviews inside a stage the template has locked at `structure` level
- `pipeline_template.manage` — change organization pipeline templates and scorecard templates
- `reason.manage` — rejection, withdrawal and archive reasons
- `message_template.manage`
- `automation.manage`
- `role.manage` — create roles and change which permissions they hold
- `dimension.manage` — define dimensions and edit values whose source is `ui` ([`org-structure.md`](./org-structure.md))
- `person.read`
- `person.read_restricted` — read people whose visibility is restricted, confidential or private without being on their access list (owners and admins by default)
- `person.create`
- `person.update`
- `person.merge`
- `person.export` — data subject access requests
- `person.erase` — data subject erasure requests
- `company.manage`
- `application.read`
- `application.move_stage`
- `application.reject`
- `application.hire`
- `interview.schedule`
- `scorecard.write`
- `offer.create`
- `offer.read` — without compensation fields
- `offer.view_compensation`
- `offer.send`
- `offer.record_response` — record accept or decline on the candidate's behalf
- `offer.rescind`
- `offer_template.manage` — offer templates and offer fields ([`offers.md`](./offers.md))
- `approval_policy.manage`
- `approval.override` — approve on someone else's behalf (audited). Approving itself needs no permission: being named by the policy is the grant
- `communication.send` — send manual messages to candidates
- `calendar_connection.manage` — connect calendars, including domain-wide ([`scheduling.md`](./scheduling.md))
- `interviewer_pool.manage`
- `scheduling.manage` — book, reschedule and cancel interviews for applications in scope
- `compliance.manage` — compliance policies, notices and consent purposes ([`consent-and-compliance.md`](./consent-and-compliance.md))
- `data_request.manage` — handle access, correction and erasure requests
- `document.upload`
- `document.read`
- `audit.read`
- `integration.manage`
- `webhook.manage`
- `custom_field.manage`
- `project.read` — see talent pools and their members (added M2b)
- `project.manage` — talent pools
- `posting.manage` — create, publish and close postings (added M2b)
- `sequence.manage` — create and edit outreach sequences
- `sequence.enroll` — enroll people (sends email from the user's own mailbox or a shared mailbox they may send as)
- `mailbox.connect` — connect one's own Gmail
- `mailbox.manage` — connect shared mailboxes and set up domain-wide delegation
- `mailbox.send_as` — granted per shared mailbox, not per role
- `consent.manage`
- `config.plan` — preview configuration changes ([`recruiting-as-code.md`](./recruiting-as-code.md))
- `config.apply` — apply configuration changes and roll back
- `config.lock` — turn repository lock on or off
- `config.break_glass` — open a time-limited emergency override of repository lock ([`recruiting-as-code.md`](./recruiting-as-code.md#emergency-override-break-glass))
- `eeo.read_aggregate` — EEO reports only; no role can read individual EEO answers through the app
- `export.data`
- `settings.manage`
- `admin.manage`

> **Updated 2026-10-24:** `candidate.*` permissions became `person.*` when the candidate record became the person record ([`data-model.md`](./data-model.md#person)). "Candidate" remains the product term. API scopes use the same names with a colon (`people:read`, `config:apply`); see [`api-strategy.md`](./api-strategy.md#conventions).

## Every setting is a permission

Decided 2026-10-24. Companies disagree about who should change things: some want only admins touching anything, others are happy for any recruiter or hiring manager to adjust their own jobs. Big Buck therefore never hard-codes who may change a setting.

- **Every setting area has its own permission.** Pipeline templates, a job's stages, a job's interviews, custom fields, dimensions, reasons, message templates, sequences, automations, webhooks, integrations, roles: each is a separate grant (the list above).
- **Roles are the customer's.** The shipped roles are starting points. A company can edit them, add its own, and give any role any permission.
- **Grants combine with scope.** A permission applies within the user's resource scope (below). "Hiring managers may edit interviews" means on jobs they are scoped to or on whose hiring team they sit, never on every job.
- **Every change is audited**, and changes to roles and permissions are themselves configuration revisions, so "who gave recruiters access to webhooks, and when?" has an answer.

### Governance presets
At setup a company picks a preset. The preset only decides which shipped roles get which permissions; everything stays editable afterwards.

| Setting area | Permission | Admins only | Recruiting team | Open |
|---|---|---|---|---|
| Pipeline templates, scorecard templates | `pipeline_template.manage` | Admins | Admins | Admins, recruiters |
| A job's stages | `job.pipeline.edit_stages` | Admins | Admins, recruiters | Admins, recruiters, hiring managers |
| A job's interviews | `job.pipeline.edit_interviews` | Admins | Admins, recruiters, hiring managers | Admins, recruiters, hiring managers |
| Interviews in a locked stage | `job.pipeline.edit_locked_interviews` | Admins | Admins, recruiters | Admins, recruiters, hiring managers |
| Custom fields | `custom_field.manage` | Admins | Admins | Admins, recruiters |
| Dimensions and their values | `dimension.manage` | Admins | Admins | Admins, recruiters |
| Reasons, message templates | `reason.manage`, `message_template.manage` | Admins | Admins, recruiters | Admins, recruiters |
| Sequences | `sequence.manage` | Admins | Admins, recruiters | Admins, recruiters |
| Offer templates and offer fields | `offer_template.manage` | Admins | Admins | Admins, recruiters |
| Approval policies | `approval_policy.manage` | Admins | Admins | Admins |
| Interviewer pools | `interviewer_pool.manage` | Admins | Admins, recruiters | Admins, recruiters |
| Compliance policies and notices | `compliance.manage` | Admins | Admins | Admins |
| Calendar connections (domain-wide) | `calendar_connection.manage` | Admins | Admins | Admins |
| Automations | `automation.manage` | Admins | Admins | Admins, recruiters |
| Roles and permissions, integrations, webhooks, repository lock, break glass | `role.manage`, `integration.manage`, `webhook.manage`, `config.lock`, `config.break_glass` | Admins | Admins | Admins |

"Admins" means `organization_admin` and `recruiting_admin`. The last row stays admin-only in every preset because those settings change who can see data or where it goes. A company can still grant them more widely; the UI warns, and the grant is audited.

Presets are ordinary role files, so a company managing configuration as code starts with `bigbuck config init --preset recruiting-team` and edits from there ([`recruiting-as-code.md`](./recruiting-as-code.md)).

### 3) Resource scope
Some permissions should still be limited by resource context.

Updated 2026-10-24: the main scoping tool is **dimension scopes** on a membership ("recruiter for Department = Engineering, including sub-departments"). They are resolved through the dimension tree, so a reorg that moves a team under a new parent updates access automatically. See [`org-structure.md`](./org-structure.md#what-dimensions-drive).

Scopes can **combine dimensions** from v1 (decided 2026-10-24): "Engineering *and* EMEA" covers only records tagged with both. One membership can hold several scopes, and it sees a record if any one scope matches:

| Scope | Matches |
|---|---|
| Department = Engineering (and below) | Every Engineering job, anywhere |
| Department = Engineering (and below) **and** Region = EMEA | Engineering jobs in EMEA only |
| Discipline = Backend or Frontend **and** Level = IC4 or IC5 | Backend or frontend jobs at IC4 or IC5 |

Within a scope, values of the same dimension are alternatives (OR) and different dimensions must all match (AND). Several scopes on one membership add up (OR). Stored in `membership_scopes` and `membership_scope_conditions` ([`db/structure.sql`](../db/structure.sql)).

Examples:
- a recruiter may manage jobs in their own org but not all departments
- a hiring manager may read candidates for assigned requisitions only
- a coordinator may schedule interviews but not approve offers
- an interviewer may write scorecards but not see compensation details

### Person visibility

Added 2026-10-24. Scopes govern requisitions, jobs, applications and projects. A person is visible through them:

- a user sees a person if they can see **any** of that person's applications or project memberships, or
- the user holds `person.read` with an org-wide scope and the person's `visibility` is `public_to_org`, or
- the user is on the person's access list.

Restrictions win:
- an application on a confidential job, or a membership in a restricted project, makes the person visible only to that record's access list, and does not reveal to anyone else that the record, or the person, exists (see [Confidential jobs](#confidential-jobs))
- an `employee` person is visible as a candidate only through applications the user can see; their employee status is shown only to `person.read` holders with org-wide scope

**Hidden means quiet** (decided 2026-10-24). Nothing hidden produces a different response: a hidden record answers `404`, never `403`, and a new record that collides with a hidden person is created normally, keeping the value as a held duplicate, with a merge suggestion that only someone who can see both people receives. A candidate applying always has the same experience as every other candidate.

**Built in M2a.** The `person_visible` predicate covers applications and the access list; project memberships join it in M2b. A person whose only applications are on confidential jobs stays hidden even from holders of `person.read_restricted`: restricted reading reaches restricted people, not confidential work, which needs `job.read_confidential` (or `project.read_confidential`). Jobs use one `job_visible` predicate: org-wide or in-scope for ordinary jobs, the access list or `job.read_confidential` for confidential ones.

Every read path applies the same rule: record reads, search, the timeline, `expand[]=person`, merge suggestions, duplicate detection on create, and agent tools. The rule is one SQL predicate shared by all of them, tested against a fixture of scoped users.

### Confidential jobs

Added 2026-10-24, after reviewing how Ashby, Greenhouse and Lever handle confidential work. A job (or requisition) can be marked confidential. Then:

- **Who sees it.** Only the job's access list (named users and roles) and holders of `job.read_confidential`, which no shipped role has except the organization owner. Department scopes do not reach confidential jobs, as in Ashby.
- **Its applications.** Visible only to the same people. A person whose only applications are confidential is hidden from everyone else; a person with other, visible applications stays visible, but the confidential application, its stage, interviews, scorecards, offer and messages are left out. A direct link answers `404`.
- **Lists, search and reports.** Confidential jobs and applications are omitted for everyone without access, including from counts. Greenhouse includes private candidates in everyone's reports; Big Buck does not, because a count can reveal an executive search.
- **The posting.** Not on the careers page unless the company publishes it under a code name. Postings, calendar events and emails to interviewers can use the job's `codename` instead of its title.
- **Interviews.** Calendar events are created private, with the code name as the title and guests hidden from each other (`guestsCanSeeOtherGuests: false`).
- **Events and integrations.** Events about confidential records go only to credentials granted the `confidential:read` scope; others never receive them.
- **Candidates never know.** The candidate's experience (application, scheduling, messages, offer) is the same as for any other job.

### Confidential sourcing

Added 2026-10-24. Sourcing gets the same protection as hiring, because a confidential search usually starts in sourcing, before any job exists. A **project** (talent pool) can be marked confidential, and a sourcing project for a confidential job is confidential automatically. Then:

- **Who sees it.** Only the project's access list and holders of `project.read_confidential` (organization owner only, by default).
- **Its members.** A person who is only in confidential projects is hidden from everyone else. A person who is also visible elsewhere stays visible, but the confidential membership, its stage, notes, tags and outreach are left out of their profile, timeline and search results. A direct link answers `404`.
- **Target companies.** A confidential project's list of target companies ("who we are hiring away from") is part of the project and hidden with it. Companies themselves stay ordinary shared records.
- **Sequences.** Outreach for a confidential project runs in confidential sequences: hidden from other users' sequence lists, analytics and the person's timeline ([`candidate-communications.md`](./candidate-communications.md#confidential-communication)).
- **Two sourcers, one person.** Another sourcer can still add the person to their own project quietly; neither learns about the other. To stop a person being emailed by two teams at once, every enrollment checks a **contact cooldown** across all sequences, confidential or not, and refuses with the same message either way: "this person was contacted recently; try again after <date>". Because ordinary outreach triggers the same message, it reveals nothing about a confidential search.
- **Conversion.** Converting a member of a confidential project creates the application on the project's job, which is confidential too, so the record never passes through a visible state.
- **Reports and attribution.** Sourcing funnels, response rates and source-of-hire omit confidential projects for everyone without access, including from counts.
- **Events and integrations.** Like confidential jobs, only credentials with the `confidential:read` scope receive events about them.
- **Prospects never know.** A prospect's emails read the same as any other outreach.

**Built in M2b.** The `project_visible` predicate: the owner, the access list and holders of `project.read_confidential` see a confidential project; an ordinary one is seen org-wide, through dimension scopes, or through its job. People are visible through visible memberships as well as applications, and a person known only through confidential jobs or confidential projects stays hidden even from `person.read_restricted` holders. A project for a confidential job is made confidential (enforced by a trigger), and conversion from a confidential project onto an ordinary job is refused. The contact cooldown arrives with sequences (M4).

### 4) Field-level visibility
Certain fields should be hidden from some roles even when the record is visible.

Examples:
- compensation band
- salary expectations
- reference checks
- private notes
- identity documents
- sensitive candidate tags
- confidential hiring plan fields

## Recommended role set

This is a starting model, not the final set.

### Platform / org roles
- `organization_owner`
- `organization_admin`
- `recruiting_admin`
- `recruiter`
- `coordinator`
- `hiring_manager`
- `interviewer`
- `read_only`
- `finance_approver`
- `integration_bot`
- `support_operator` with tightly scoped elevation

### Candidate portal roles later
- `candidate`
- `referrer`

## Permission groups

### Recruiting core
- manage requisitions
- manage jobs
- publish postings
- move applications
- archive applications
- create notes
- schedule interviews
- submit feedback
- make offers
- approve offers

### Data and reporting
- read applications
- export data
- view analytics
- read audit logs
- download documents

### Platform and config
- manage integrations
- manage webhooks
- manage custom field definitions
- manage field groups
- manage pipeline templates
- manage users and roles
- manage dimensions (departments, locations, disciplines, levels and any company-defined structure)

## Visibility rules

### Candidate visibility
A candidate record can be one of:
- `public_to_org`
- `restricted`
- `confidential`
- `private_to_assignees`

Suggested rules:
- public candidates are visible to permitted org roles
- restricted candidates are visible only to assigned recruiters/hiring managers
- confidential candidates hide identity/contact info from broad audiences
- private-to-assignees records are visible only to a defined access list

### Application visibility
Applications should inherit candidate and job access, but may also have their own restrictions.

Examples:
- confidential executive search
- sensitive internal transfer
- merger-related hiring

### Note visibility
Notes should support at least:
- `private`
- `internal`
- `shared_with_hiring_team`
- `shared_with_candidate` only if the product later supports that flow

### Interview and scorecard visibility
Feedback should be more restricted than the application record itself.

Suggested defaults:
- hiring team can see interview schedules
- scorecards are visible only to authorized hiring stakeholders
- compensation-related feedback is visible only to approved roles

### Offer visibility
Offer data should be tightly scoped.

At minimum:
- hiring managers may see offer status
- recruiters may see draft and approval state
- finance or compensation approvers may see band details
- general read-only users should not see compensation fields

### Custom field visibility
Custom field groups and field definitions should carry visibility policy.

Examples:
- candidate profile group visible to recruiters and hiring managers
- compensation group visible to recruiter admin and finance approvers only
- legal/compliance group visible to authorized admins only
- internal screening group hidden from general viewers

## Integration and automation access

Integrations should be granted explicit scopes.

Examples:
- `people:read`
- `applications:write`
- `applications:transition`
- `jobs:read`
- `webhooks:write`
- `audit:read`
- `offers:write`
- `config:plan`
- `config:apply`

Scopes should be narrow by default.

Automation services and agents should also obey explicit scopes, with separate read/write tool permissions.

## Audit visibility

Audit logs are not the same as normal business records.

Access should be limited to:
- org admins
- security or compliance roles
- support operators under controlled elevation

Audit access itself should be logged.

## Suggested enforcement order

When the server receives a request, it should evaluate:

1. tenant membership
2. session or token validity
3. permission check
4. resource ownership / assignment / scope
5. field-level visibility
6. action-specific policy
7. audit record creation

## Data model implications

The permissions model implies the following tables or entities:

- roles
- permissions
- role_permissions
- memberships
- membership_roles if multiple roles are ever needed
- team memberships
- resource access lists for confidential records
- membership scopes and their conditions (dimension-based resource scope)
- field groups
- field definitions
- field visibility rules
- audit events
- integration scopes

## Policy style

The implementation should use explicit policy functions, not hardcoded checks in UI components.

Examples:
- `canReadCandidate(user, candidate)`
- `canMoveApplicationStage(user, application)`
- `canViewOfferCompensation(user, offer)`
- `canManageCustomFieldGroup(user, group)`

This keeps business logic testable and reusable across API, CLI, and workers.

## Default-deny stance

If a role, scope, or field rule is missing, access should be denied.

This is especially important for:
- candidate PII
- compensation data
- private notes
- audit logs
- admin settings
- integration secrets

## Future-friendly extension points

These should be supported later without redesign:

- row-level access lists for confidential candidates
- temporary approval-based privilege escalation
- SCIM-provisioned roles
- candidate portal permissions
- partner/integration marketplace scopes
- export approval workflows for sensitive data

## Final recommendation

Big Buck should treat permissions as part of the product’s core data model, not as a thin auth wrapper.

That means:
- explicit roles and scopes
- field-level visibility
- confidential records
- auditable access
- default-deny policy

This is the only way to make a high-trust ATS safe enough for enterprise use.
