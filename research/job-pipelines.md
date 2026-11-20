# 22 — Job Pipelines, Templates and Interviews

## Goal

Let a recruiter change one job's hiring process (add a take-home, drop an interview, rename a stage) without breaking the API, the reports, or every other job that shares the same template. Interviews live inside the stages they belong to.

This replaces the "separate pipeline per variation" recommendation that [`recruiting-as-code.md`](./recruiting-as-code.md) left as an open question.

## The model in one paragraph

Organizations define **pipeline templates** (one is the default). Every job gets **its own job pipeline**, created from a template when the job is created. A job pipeline is stored as *the template version it is based on* plus *an ordered list of edits* (overrides) made to that job. Big Buck resolves the two into the stages the job actually runs, and saves each result as an immutable **pipeline version**. When the template changes, Big Buck re-applies each job's edits on top of the new template. Most jobs update cleanly; a job whose edits no longer fit is held on its current version and flagged for review. Every stage carries its **interviews**, so the process for a stage is defined in one place.

## Why this shape

| Option | Problem |
|---|---|
| Every job owns a free copy of its stages (Bigbuck's original `pipeline_stages.job_id`) | Template improvements never reach existing jobs; cross-job reporting depends on stage names matching |
| Every variation is its own template (the previous recommendation) | Templates multiply ("Engineering, but with a take-home"); a one-off edit becomes an admin task |
| **Template + per-job edits (this design)** | One-offs are cheap, template changes still flow to every job, and the edits are visible and reversible |

## Concepts

### Pipeline template
Org-level configuration, versioned, editable in the UI or as files ([`recruiting-as-code.md`](./recruiting-as-code.md#pipeline-template)).

- one template per object type is marked **default**
- a template may claim **dimension values** it is the default for, such as `discipline: engineering` (see [`org-structure.md`](./org-structure.md))
- templates never hold applications; jobs do

### Default template selection
When a job is created without an explicit template, Big Buck picks one in this order:

1. the template named in the request (`pipeline_template: engineering-hiring`)
2. the template that claims the job's most specific dimension value (a template for `discipline: engineering/backend` beats one for `engineering`; ties are broken by the organization's dimension priority order)
3. the organization's default template

The choice is recorded on the job, so it is explainable later ("picked because discipline = Backend").

### Job pipeline
One per job, created at job creation.

- `base_template_version` — the template version it is built on
- `overrides` — the ordered list of edits made to this job
- `link_mode`:
  - `following` — no edits; template updates apply automatically
  - `customized` — has edits; template updates are re-applied under the edits
  - `detached` — an explicit copy that ignores the template from now on (allowed, but it gives up template updates, so the UI warns)
- `needs_review` — set when a template update conflicts with this job's edits

### Overrides
A closed set of edits, each targeting **stable keys**, never ids:

| Override | Payload |
|---|---|
| `add_stage` | the stage, and the key of the stage it goes after |
| `update_stage` | stage key, fields to set (name, guards, automations) |
| `move_stage` | stage key, new position (after key) |
| `remove_stage` | stage key, and `move_open_to` for open applications in it |
| `add_interview` | stage key, the interview |
| `update_interview` | stage key, interview key, fields to set |
| `remove_interview` | stage key, interview key |

Rules:
- **who may make each kind of edit is a permission**, not a fixed role: `job.pipeline.edit_stages` for stage edits, `job.pipeline.edit_interviews` for interview edits, within the user's scope ([`permissions.md`](./permissions.md#every-setting-is-a-permission)). One company lets hiring managers adjust their own jobs; another lets only admins touch anything
- **the job's edit wins** on any field it sets; everything it does not touch keeps following the template
- a stage that came from the template keeps its reporting `type`; a job-added stage chooses its own `type` from the fixed enum
- each override records who made it and when, so "who added this take-home?" has an answer
- deleting an override reverts that part of the job to the template

### Locked stages
A template can lock a stage that every job must keep, such as a compliance or background-check step. Locks have two levels:

| `lock` | Jobs may | Jobs may not |
|---|---|---|
| `none` (default) | Do anything their permissions allow | |
| `structure` | Add, change or remove the stage's interviews, with `job.pipeline.edit_locked_interviews` | Remove, retype or move the stage |
| `full` | Nothing; the stage changes only in the template | Edit the stage or its interviews |

`structure` is the usual choice: changing interviews after a search starts is common (a new interviewer, a different exercise, an extra round for senior candidates), so the stage stays put while its interviews stay flexible. `full` is for steps whose content is itself the requirement, such as a regulated assessment.

### Pipeline version
The resolved stages and interviews, saved immutably every time the base template or the overrides change. Each stage and interview is marked with its origin (`template` or `job`). Applications point at the job's current version; every stage transition records the version it happened under, so history stays exact.

## Worked example

Checked with a reference resolver (template plus overrides, then two template updates). `*` marks a job-added interview.

**Template `engineering-hiring` v1**

| Stage | Type | Interviews |
|---|---|---|
| review | review | |
| recruiter-screen | screen | recruiter-call |
| onsite | interview | coding, system-design, values |
| offer | offer | |

**The Staff Platform Engineer job makes four edits**
1. `add_stage` take-home (assessment) after recruiter-screen
2. `add_interview` hiring-manager-chat to recruiter-screen
3. `update_stage` onsite: name "Virtual onsite"
4. `remove_interview` values from onsite

**Resolved job pipeline**

| Stage | Name | Origin | Interviews |
|---|---|---|---|
| review | Application review | template | |
| recruiter-screen | Recruiter screen | template | recruiter-call, hiring-manager-chat* |
| take-home | Take-home | job | |
| onsite | Virtual onsite | template (renamed) | coding, system-design |
| offer | Offer | template | |

**Template v2** renames recruiter-screen to "Recruiter call", adds a `skills-test` stage after review, and adds a `bar-raiser` interview to onsite. Re-applying the four edits works cleanly, so the job moves to a new version automatically:

| Stage | Name | Interviews |
|---|---|---|
| review | Application review | |
| skills-test | Skills assessment | coding-test |
| recruiter-screen | Recruiter call | recruiter-call, hiring-manager-chat* |
| take-home | Take-home | |
| onsite | Virtual onsite | coding, system-design, bar-raiser |
| offer | Offer | |

**Template v3** replaces onsite with a `final-round` stage and adds its own `take-home` stage. Three of the job's edits no longer fit:

- edit 1: `take-home` now exists in the template
- edit 3: stage `onsite` no longer exists
- edit 4: stage `onsite` no longer exists

The job stays on its v2-based version, `needs_review` is set, and the template's plan lists it before anyone applies v3 ([`recruiting-as-code.md`](./recruiting-as-code.md#plan)). A recruiter resolves it by dropping or retargeting the conflicting edits, or by detaching the job.

## Job states and what can be edited

Job states are unchanged from [`workflow.md`](./workflow.md#job-lifecycle). What changes is what each state allows.

| Job state | Stages | Interviews | Template updates |
|---|---|---|---|
| `draft` | Any edit; nothing to migrate | Any edit | Applied automatically |
| `active` | Add, rename, reorder freely. Remove only with `move_open_to` when the stage holds open applications | Any edit; already-scheduled interviews are not touched | Applied automatically when clean; held for review on conflict |
| `paused` | Same as `active` | Same as `active` | Same as `active` |
| `closed` | Read-only; reopen the job to edit | Read-only | Not applied; the job keeps the version it closed on |
| `archived` | Read-only | Read-only | Not applied |

How a change reaches open applications:
- applications always run on their job's current pipeline version; a new version takes effect for them immediately
- an application in a stage that still exists stays in that stage (matched by key)
- an application in a removed stage moves to `move_open_to`, recorded as a stage transition with `reason = pipeline_edit`
- changed guards apply to the next transition only; nothing already done is re-checked

## Interviews inside stages

Each stage lists the interviews that happen in it. That is the whole interview plan: there is no separate object to keep in sync.

| Field | Meaning |
|---|---|
| `key` | Stable within the pipeline, e.g. `system-design` |
| `name` | Shown to interviewers and candidates |
| `format` | `phone`, `video`, `in_person`, `take_home`, `async_review`, `external` (`external` = run by a connected provider or agent) |
| `duration` | Minutes |
| `interviewers` | Who can run it: a role on the hiring team, a named pool, or specific users, plus how many |
| `scorecard` | A scorecard template key (the rubric: attributes, rating scale, questions) |
| `scheduling` | `self_schedule`, `availability_request`, `coordinator`, `manual` or `none`; see [`scheduling.md`](./scheduling.md#scheduling-modes) |
| `required` | Whether it counts toward the stage's exit guard |
| `provider` | For `external` interviews: the connected provider and its settings, such as a test id |
| `communications` | Confirmation and reminder templates, candidate instructions and the interviewer briefing for this interview; see [`candidate-communications.md`](./candidate-communications.md#per-interview-communications) |

What happens at runtime:
- entering a stage creates an `interview` record for each of its interviews, in status `requested`, and runs its scheduling mode
- the default exit guard for a stage with interviews is "all required interviews have a submitted scorecard"; stages can tighten or loosen it
- leaving a stage cancels its interviews that were never scheduled; scheduled ones stay and the coordinator is told
- rejecting or withdrawing cancels all future interviews

**Provider-run interviews** (`format: external`) are how assessment platforms, async video tools or a company's own agents plug in; Big Buck does not ship an interviewer of its own ([`v1-scope.md`](./v1-scope.md)). The provider receives the invite through the interview-provider contract, runs the session, and posts back a scorecard and any artifacts (a transcript, a test report). Before inviting, Big Buck checks whatever consents the company's compliance policy requires for that provider ([`consent-and-compliance.md`](./consent-and-compliance.md)). A provider's score is advisory, like every automated output ([`agentic-integrations.md`](./agentic-integrations.md)).

## Why this does not break the API

1. **One shape for every job.** `GET /jobs/{id}/pipeline` returns resolved stages and interviews whether the job follows its template or is heavily customized. Each stage and interview carries `origin`, but clients that ignore it still work.
2. **Keys are the contract.** Integrations address stages and interviews by key (`to_stage_key: onsite`). Keys never change meaning; ids are per version.
3. **Reporting stays comparable.** Every stage, including job-added ones, has a `type` from the fixed enum, so a funnel across 200 customized jobs still groups correctly.
4. **No silent moves.** Removing a stage that holds applications is refused without `move_open_to`; every move is a recorded transition.
5. **Concurrency is explicit.** Edits send `If-Match` with the pipeline version, so two recruiters editing one job cannot overwrite each other.
6. **Changes are events.** `job.pipeline_changed` carries the new version and the overrides that produced it; `job.pipeline_needs_review` fires on conflicts.

## API

| Action | Endpoint |
|---|---|
| Read the resolved pipeline | `GET /jobs/{id}/pipeline` |
| List this job's edits | `GET /jobs/{id}/pipeline/overrides` |
| Make one or more edits, atomically | `POST /jobs/{id}/pipeline/overrides` with `{ "overrides": [ … ] }` and `If-Match` |
| Revert an edit to the template | `DELETE /jobs/{id}/pipeline/overrides/{override_id}` (with `move_open_to` if needed) |
| Resolve a conflict or adopt the latest template | `POST /jobs/{id}/pipeline/rebase` |
| Switch template | `POST /jobs/{id}/pipeline/change-template` with `template_key` and a stage-key map |
| Detach from the template | `POST /jobs/{id}/pipeline/detach` |
| Version history | `GET /jobs/{id}/pipeline/versions` |

Example: add a take-home and a hiring-manager chat in one call.

```http
POST /v1/jobs/0192f1c2-5d6e-7f80-9a1b-2c3d4e5f6a7b/pipeline/overrides
If-Match: "pv-7"
Idempotency-Key: 9b2f6c1e-3a4d-4e5f-8a7b-1c2d3e4f5a6b
Content-Type: application/json

{
  "overrides": [
    { "op": "add_stage", "after": "recruiter-screen",
      "stage": { "key": "take-home", "name": "Take-home", "type": "assessment" } },
    { "op": "add_interview", "stage": "recruiter-screen",
      "interview": { "key": "hiring-manager-chat", "name": "Hiring manager chat", "format": "video",
                     "duration": 30, "interviewers": { "roles": ["hiring-manager"], "count": 1 },
                     "scorecard": "culture-add", "scheduling": "self_schedule", "required": true } }
  ]
}
```

## Where it lives

| Piece | Location |
|---|---|
| Tables | `pipelines` (scope, link mode), `pipeline_overrides`, `pipeline_versions`, `pipeline_stages`, `stage_interviews`, `scorecard_templates`, `interviews` ([`db/structure.sql`](../db/structure.sql)) |
| Entities | [`data-model.md`](./data-model.md#pipeline) |
| Templates as files | `kind: Pipeline` and `kind: ScorecardTemplate` ([`recruiting-as-code.md`](./recruiting-as-code.md)) |
| Job pipelines | Job data, edited in the UI or through the API; not in config files, so a repository does not fill up with hundreds of jobs |
| Permissions | `job.pipeline.edit_stages`, `job.pipeline.edit_interviews`, `job.pipeline.edit_locked_interviews`, `pipeline_template.manage` ([`permissions.md`](./permissions.md#every-setting-is-a-permission)) |

## Decisions (2026-10-24)

1. **Who can edit a job's pipeline** depends on the company's permission setup, like every other setting. The governance presets in [`permissions.md`](./permissions.md#governance-presets) range from admins only to recruiters and hiring managers editing their own jobs.
2. **Locked stages** have two levels. At `structure`, jobs keep the stage but can change its interviews, given `job.pipeline.edit_locked_interviews`; at `full`, the stage and its interviews change only in the template.
