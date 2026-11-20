# 17 — Workflow State Machine

## Goal

Define the workflow model Big Buck should use so recruiting actions are explicit, auditable, and automation-friendly.

This doc focuses on state, transitions, and invariants — not UI behavior.

## Core idea

Big Buck should model the ATS as a set of **small, explicit state machines** rather than one giant opaque workflow.

The most important objects are:

- requisitions
- jobs
- postings
- applications
- interviews
- offers
- approvals
- documents

Each of those should have a clearly defined lifecycle.

## State machine principles

1. **State is current truth; history is append-only.**
2. **All transitions happen through commands, not ad hoc writes.**
3. **Every transition records actor, timestamp, source surface, and reason.**
4. **Terminal states are explicit.**
5. **Workflow state is separate from comments, audit logs, and analytics.**
6. **Application stage and application lifecycle are not the same thing.**

## Workflow layer model

Big Buck should separate workflow into three layers:

### 1) Lifecycle state
The coarse-grained status of an object.

Examples:
- requisition: draft, pending approval, open, paused, closed
- offer: draft, pending approval, sent, accepted, rejected
- interview: requested, scheduled, completed, cancelled

### 2) Workflow stage
The fine-grained recruiting pipeline location.

Examples:
- application stage: applied, recruiter screen, hiring manager screen, onsite, offer

### 3) History / event record
The immutable record of what changed.

Examples:
- stage transition
- approval decision
- offer update
- interview reschedule
- document status update

## Requisition lifecycle

A requisition represents approved hiring demand.

### Suggested states
- `draft`
- `pending_approval`
- `approved`
- `open`
- `paused`
- `closed`
- `canceled`
- `archived`

### Suggested transitions
- `draft -> pending_approval`
- `pending_approval -> approved`
- `approved -> open`
- `open -> paused`
- `paused -> open`
- `open -> closed`
- `pending_approval -> canceled`
- `approved -> canceled`
- `closed -> archived`

### Notes
- `draft` and `pending_approval` support enterprise approval flows
- `open` means the requisition is active for hiring
- `closed` means no new hiring activity is expected
- `archived` is a retention state, not a business state

## Job lifecycle

A job is the working recruiting object tied to a requisition.

### Suggested states
- `draft`
- `active`
- `paused`
- `closed`
- `archived`

### Suggested transitions
- `draft -> active`
- `active -> paused`
- `paused -> active`
- `active -> closed`
- `paused -> closed`
- `closed -> archived`

### Notes
- jobs can be paused without closing the requisition
- jobs should inherit or reference requisition-level controls where appropriate, including the requisition's dimension tags ([`org-structure.md`](./org-structure.md))
- the job's state decides what can change in its pipeline: anything in `draft`; add, rename, reorder and interview edits in `active` and `paused` (removing a stage that holds applications needs a target stage); nothing in `closed` or `archived`. Full table: [`job-pipelines.md`](./job-pipelines.md#job-states-and-what-can-be-edited)
- stages carry their interviews; entering a stage creates its interviews and runs their scheduling mode

## Posting lifecycle

A posting is the published surface for a job.

### States

Built in M2b (2026-10-24) with three states; scheduling a publish date can come later:

- `draft`
- `published` (live on the careers page; only while the job is `active`)
- `closed`

### Transitions
- `draft -> published`, `closed -> published` (the job must be `active`)
- `published -> closed`
- a job leaving `active` (paused, closed, archived) closes its published postings; reopening the job leaves republishing to a person

### Notes
- posting state controls visibility, not the hiring workflow itself
- a confidential job's posting starts from the job's code name and never copies its description
- one job may have multiple postings across channels

## Application lifecycle

The application is the central recruiting transaction.

### Lifecycle states

Simplified when built (M2a, 2026-10-24). Where an application is in the process is its stage; the status says only whether it is still open:

- `active` (open, somewhere in the pipeline)
- `hired`
- `rejected`
- `withdrawn`
- `archived` (retention)

### Transitions
- `active -> hired` (the `hire` command)
- `active -> rejected` (the `reject` command, with a reason); `rejected -> active` (`unreject`)
- `active -> withdrawn` (the `withdraw` command, with a reason)
- `hired`, `rejected` or `withdrawn` `-> archived`
- a person has at most one open application per job

### Notes
- `application.status` is the lifecycle state
- `application.current_stage_id` is the pipeline position
- an application can move across many stages while staying in the same lifecycle state
- `rejected` and `withdrawn` are terminal business states, while `archived` is retention
- reject, unreject, withdraw and hire are **their own commands** (`POST /applications/{id}/reject` and so on), separate from stage moves. A rejected application keeps the stage it was rejected at, so funnel reports can say where people drop out. Pipelines therefore have no "Rejected" or "Hired" stages.
- every job has its **own pipeline**, built from a template plus that job's edits ([`job-pipelines.md`](./job-pipelines.md)). Applications run on the job pipeline's current version; when it changes, applications keep their stage (matched by key), applications in a removed stage move to a named target, and each move is a transition with `reason = pipeline_edit` or `pipeline_upgrade`

## Pipeline stage model

Pipeline stages are not the same as lifecycle states.

A stage is a configurable point in the hiring process, such as:
- recruiter screen
- hiring manager interview
- take-home
- panel interview
- offer review

### Stage rules
- stages belong to a versioned, reusable pipeline; jobs point at a pipeline instead of owning stages
- stages have explicit ordering and a stable `key` across versions
- each stage has a fixed reporting `type` (`review`, `screen`, `assessment`, `interview`, `offer`, `other`) so funnels compare across jobs
- stage transitions are append-only
- a stage may trigger automation
- a stage may require approvals or evidence (entry and exit guards, checked by the transition command)

### Stage transition rules
- a transition must reference `from_stage_id` and `to_stage_id`
- which moves are allowed is the pipeline's `transitions` policy:
  - `forward_only`: to any later stage
  - `forward_and_back` (the default): to the next stage or any earlier one
  - `any`: to any stage
- entry and exit guards are checked by the move command. Built in M2a: `fields_present` (named fields must be filled before entering or leaving a stage). Scorecard guards arrive with interviews (M5) and approval guards with offers (M6); until then a pipeline that names them validates but they are not enforced
- outcomes (hired, rejected, withdrawn) are lifecycle commands, not stages, so there are no terminal stages to police

## Interview lifecycle

### Suggested states
- `requested`
- `scheduled`
- `rescheduled`
- `completed`
- `cancelled`
- `no_show`
- `needs_feedback`
- `feedback_submitted`
- `needs_attention` — the calendar event was moved or deleted outside Big Buck, or an interviewer declined with no replacement (added 2026-10-24)

### Notes
- interview scheduling should not silently move application stage unless policy allows it
- feedback submission should be separately tracked from interview completion
- how interviews get scheduled, and what happens when calendars change, is in [`scheduling.md`](./scheduling.md)

## Offer lifecycle

Updated 2026-10-24; the full process is in [`offers.md`](./offers.md).

### States
- `draft`
- `pending_approval`
- `changes_requested`
- `approved`
- `sent`
- `accepted`
- `declined` — by the candidate (previously `rejected`)
- `expired`
- `rescinded` — by the company, reason required (previously `withdrawn`)

### Notes
- an approval policy decides whether and how an offer is approved; a catch-all policy is mandatory
- every change after draft is a new immutable version; changing a reapproval field sends it back to `pending_approval`
- declined and expired offers can be revised into a new version and re-sent (counter-offers)
- acceptance is recorded with its evidence and can trigger the hire command and the HRIS hand-off (WIP)

## Approval lifecycle

### Suggested states
- `requested`
- `approved`
- `rejected`
- `withdrawn`
- `expired`

### Notes
- approvals can apply to requisitions, offers, and other controlled actions
- approval records should include reason and approver identity

## Document lifecycle

### Suggested states
- `uploaded`
- `scanned`
- `parsed`
- `available`
- `replaced`
- `deleted`
- `quarantined`

### Notes
- document status must support virus scanning and parsing workflows
- replaced and deleted should remain auditable

## Talent CRM lifecycles

Added 2026-10-24 with the unified ATS + talent CRM model ([`data-model.md`](./data-model.md#talent-crm-objects)).

### Person lifecycle stage
- `prospect -> candidate` automatically on the first application
- `candidate -> employee` automatically on hire
- `employee -> alumni` when the HRIS or a user marks them as departed
- moves forward automatically and backward only by explicit command; it describes the relationship, not a workflow

### Project member lifecycle
Built in M2b. Adding a person keeps their lifecycle stage: a prospect stays a prospect until they apply or are converted. A project without a pipeline is a plain list whose members have no stage.

- `active -> converted` (creates an application; both ids are kept for sourcing attribution)
- `active -> removed`
- `removed -> active` (re-added)
- while `active`, a member can move through the project's pipeline stages (for example sourced → contacted → engaged) using the same transition rules as applications

### Sequence enrollment lifecycle
- `active -> paused -> active`
- `active -> completed` after the last step
- `active -> stopped` automatically on reply, application, bounce, unsubscribe or do-not-contact, or manually
- enrollment is refused when the person is do-not-contact or lacks the outreach consent their jurisdiction requires

### Config revision
- not a state machine: revisions are append-only, numbered, and `applied` or `failed`
- rollback is a new revision, never an edit ([`recruiting-as-code.md`](./recruiting-as-code.md#rollback))

## Command model

Each workflow should be mutated through explicit commands, such as:

- `create requisition`
- `submit requisition for approval`
- `approve requisition`
- `open job`
- `publish posting`
- `move application stage`
- `schedule interview`
- `submit interview feedback`
- `approve offer`
- `send offer`
- `accept offer`
- `reject application`
- `unreject application`
- `withdraw application`
- `hire application`
- `edit job pipeline` (add, change, move or remove a stage or interview for one job)
- `revert job pipeline edit`
- `rebase job pipeline` (resolve a template conflict)
- `merge people`
- `add person to project`
- `convert project member`
- `enroll person in sequence`
- `stop sequence enrollment`
- `apply config plan`
- `roll back config`

The HTTP shape of each command is in [`api-strategy.md`](./api-strategy.md#commands-not-patches).

## Event model

Every command should emit one or more events:

- audit event
- stage transition event
- webhook event
- outbox event
- job run record when async work is involved

## Invariants

1. A terminal state should not be silently left unless a reopen command exists.
2. A stage transition must always reference the application and the source/destination stage.
3. A lifecycle change and a stage change are separate records.
4. Approval outcomes must be recorded before dependent actions execute.
5. History is immutable even if current state changes later.
6. Automation may suggest transitions, but policy decides whether they execute.

## Recommended implementation shape

- write APIs accept commands, not raw status patches where avoidable
- the application service validates legal transitions
- the domain layer owns transition rules
- the database stores current state plus immutable transition history
- outbox events propagate changes to webhooks, search, analytics, and integrations

## Final recommendation

Big Buck should model workflow as a controlled set of state machines with append-only history.

That gives us:
- enterprise approval support
- reliable auditability
- cleaner automation
- easier reporting
- better reasoning about what changed and why
