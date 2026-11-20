# 25 — Offers

## Goal

Cover the whole offer process: build the offer, approve it, generate the letter, send it, let the candidate accept or decline, handle revisions and counter-offers, rescind when needed, and hand the hire to the HR system. Until now Big Buck had only an `offers` table and a list of states.

## How other ATSs do it

Researched 2026-10-24 from vendor help centres. Lever's help pages did not load, so Lever is not included.

| | Greenhouse | Ashby | Workable |
|---|---|---|---|
| Offer data | Offer Details on the candidate, plus custom offer fields | Custom offer fields with type, default, required flag, hide or lock when defaulted, conditional display, limits by job or department, **"Require Reapproval"** per field | Placeholders such as start date and salary |
| Letter | Upload a template with tokens; generates .docx and .pdf; missing token = error; only the latest document is shown | .docx templates with tokens, validated on upload; `_RAW` suffix removes number formatting; offer packets bundle several documents; one-off custom letter per candidate | Upload a template or use theirs; pre-drafted covering email |
| Template availability | Limited by office, department, employment type or custom offer field; must match every criterion | Limited to specific jobs | Limited by department and location |
| Approvals | Default flow plus flows by office and department; steps run **in order** or **all at once**; N approvals required per step; an approver can come from a custom job field | Processes with an optional scope (salary, department, location); **first matching process wins**; unscoped process is the catch-all, with an **"approval gap" warning** if missing; sequential steps, each **all or any one**; approvers can be **hiring-team roles**; Enterprise can push approval chains through the API | One approval workflow per template; requests go out automatically |
| Signature | DocuSign or Adobe Acrobat Sign integrations; otherwise upload the signed copy | **Native e-signature** (candidate and company signatory, initials, text inputs) or DocuSign; CC recipients notified at each step | Integrated e-signature, desktop or mobile; optional company signature |
| Versions | Current document only | Full version history with approvals and comments | Revised offer after decline goes back through approval ("counter offer") |
| Outcome | Mark Hired on the stages tab | "Set Response" records accept or decline; accepted moves to Hired; post-hire push to Rippling or BambooHR | Timeline shows pending approval, sent, accepted, declined |
| Rescind | | Archive with a "rescinded offer" reason; do not delete | |

Sources: [Greenhouse: generate and send offer document](https://support.greenhouse.io/hc/en-us/articles/200485589), [Greenhouse: limit offer templates](https://support.greenhouse.io/hc/en-us/articles/115003166363-How-do-I-limit-offer-letter-templates-by-Offices-Departments-and-Employment-Types-), [Greenhouse: configure approvals](https://support.greenhouse.io/hc/en-us/articles/360062257351-Configure-job-approvals), [Ashby: offers and offer letters](https://docs.ashbyhq.com/offers-and-offer-letters), [Ashby: offer approvals](https://docs.ashbyhq.com/offer-approvals), [Workable: offer approvals](https://resources.workable.com/backstage/improve-job-offer-process-approvals).

### What Big Buck takes from this
1. **Offer fields are configuration, with a reapproval flag per field** (Ashby). Changing salary sends the offer back for approval; fixing a typo in the welcome note does not.
2. **Approval policies match on conditions, first match wins, with a required catch-all** (Ashby), and steps can be sequential or parallel with "all", "any" or "N of" approvers (Greenhouse). Approvers can be people, hiring-team roles, or a dimension attribute such as the department head.
3. **Template availability by dimension** (Greenhouse, Workable): templates claim dimension values, like pipeline templates do.
4. **Every change is a version with history** (Ashby); a declined offer can be revised, re-approved and re-sent (Workable).
5. **Rescinding is an explicit, reasoned action**, never a delete.
6. **Acceptance leads to hire and a hand-off to the HR system** (Ashby).
7. **One token language** for letters, emails and calendar text, with formatting filters instead of `_RAW` suffixes.

## The model

| Object | What it is |
|---|---|
| **Offer** | One per application at a time. Holds the current status and points at its current version |
| **Offer version** | Immutable snapshot of the offer fields, the template used, the generated documents and the approvals for that version |
| **Offer fields** | A custom field group with `entity: offer`. Each field can be `requiresReapproval`, carries visibility rules (compensation visible only to some roles) and can have a default per dimension value |
| **Offer template** | The letter: a .docx or HTML document with tokens. Claims dimension values to limit where it is offered, like pipeline templates |
| **Approval policy** | Conditions, then ordered steps of approvers. Shared by offers and requisitions |
| **Approval request** | One per approver per step per version; existing `approvals` table, extended |
| **Signature request** | The send: who signs (candidate, optional company signatory), who is copied, which provider (`click_to_accept` in v1; DocuSign, Dropbox Sign, Adobe Sign are WIP) |
| **Offer response** | The candidate's accept or decline (or a recruiter recording it on their behalf), with reason and evidence |

## Lifecycle

```text
draft ──submit──▶ pending_approval ──all steps approved──▶ approved ──send──▶ sent ──▶ accepted ──▶ (hire)
  ▲                    │  ▲                                    │               │  │
  │                 reject │ edit a reapproval field           │               │  └──▶ declined ──revise──▶ draft (new version)
  │                    ▼  │                                    │               └──▶ expired ──revise──▶ draft (new version)
  └──── revise ─── changes_requested                           │
                                                               └── edit a reapproval field ──▶ pending_approval (new version)

any state before accepted ──rescind (reason required)──▶ rescinded
```

| State | Meaning |
|---|---|
| `draft` | Being prepared; fields and letter can change freely |
| `pending_approval` | Waiting on the approval policy's steps |
| `changes_requested` | An approver rejected it with comments; goes back to draft as a new version |
| `approved` | Ready to send |
| `sent` | With the candidate; `viewed_at` records when they opened it |
| `accepted` | Candidate accepted (or a recruiter recorded acceptance) |
| `declined` | Candidate declined, with an optional reason; can be revised into a counter-offer |
| `expired` | Passed `expires_at` without a response; can be revised and re-sent |
| `rescinded` | Withdrawn by the company before acceptance; reason required; terminal |

Rules:
- **Versions:** any change to fields or letter after `draft` creates a new version. If a changed field is `requiresReapproval`, the offer returns to `pending_approval`; otherwise it keeps its approval and only the document is regenerated.
- **After sending:** editing a sent offer creates a new version that must be re-sent. The candidate's link always shows the latest sent version, and the earlier one is marked `superseded`.
- **One live offer per application.** Counter-offers are new versions of the same offer, not new offers.
- **Approvers see what they approve.** An approval request grants its approver read access to that version's fields, including compensation, for the duration of the request, even if their role normally cannot see compensation.
- **Rescind** needs `offer.rescind` and a structured reason; the candidate is told through the rescind message template, which a recruiter reviews before it goes out.
- This replaces the earlier offer states in [`workflow.md`](./workflow.md#offer-lifecycle): `rejected` is now `declined` (candidate) and `withdrawn` is now `rescinded` (company).

## Approval policies

```yaml
apiVersion: bigbuck/v1
kind: ApprovalPolicy
metadata:
  key: engineering-senior-offers
  name: Senior engineering offers
spec:
  appliesTo: offer
  priority: 10                      # higher is checked first; first match wins
  when:
    job.dimensions.department: engineering   # includes sub-departments
    job.dimensions.level: [ic6, ic7]
  steps:
    - name: Hiring manager
      approvers: [role:hiring-manager]
      require: all
    - name: Department head and finance
      mode: parallel                # parallel | sequential (default)
      approvers:
        - attribute: job.dimensions.department.head
        - role:finance-approver
      require: all
    - name: Above band
      when:
        op: gt
        left: offer.fields.base-salary
        right: job.dimensions.level.attributes.salary-max   # level dimension has salary-max
      approvers: [user:cfo@acme.example]
      require: any
  reapprovalFields: [base-salary, equity, sign-on-bonus, start-date, level]
---
apiVersion: bigbuck/v1
kind: ApprovalPolicy
metadata:
  key: default-offers
  name: All other offers
spec:
  appliesTo: offer
  priority: 0
  catchAll: true                    # exactly one per appliesTo; validate fails without it
  steps:
    - name: Hiring manager
      approvers: [role:hiring-manager]
      require: all
      ifNoApprover: skip            # skip | fallback:<approver> | block
      allowSelfApproval: false      # the person who submitted cannot approve their own offer
```

- Approvers can be users, hiring-team roles (`role:`), permission roles, or a reference attribute on a dimension value (`attribute:`), so "the department head" follows reorgs.
- `require` is `all`, `any`, or a number.
- `ifNoApprover` decides what happens when a step resolves to nobody (no hiring manager on the job, or the only candidate approver is the person who submitted): `skip` records why and moves on, `fallback:` names who approves instead (for example `fallback:role:recruiting-admin`), and `block` stops until someone is assigned. The setup's default policy uses `skip`, so a one-person company or a job without a hiring manager never gets stuck ([`owner-setup.md`](./owner-setup.md#fallbacks-that-keep-it-working)). Enterprise policies usually use `fallback` or `block`.
- `allowSelfApproval` (default false) stops submitters from approving their own offers; a step that would need it follows `ifNoApprover`.
- Steps are sequential unless a step says `parallel`.
- A step with `when` is skipped if its condition is false. Conditions are structured YAML rules over offer fields, job dimensions and their attributes, type-checked at `validate` ([`build-plan.md`](./build-plan.md#if-rules), [`recruiting-as-code.md`](./recruiting-as-code.md#file-format)).
- `bigbuck config validate` fails if there is no catch-all policy, which is Ashby's "approval gap" made into a hard error.
- An admin with `approval.override` can approve on someone's behalf; it is recorded as an override, and the original approver is notified.
- Approval requests are sent by email and shown in the approver's task list; Slack is WIP. Reminders follow the communications settings.

## Offer templates and tokens

```yaml
apiVersion: bigbuck/v1
kind: OfferTemplate
metadata:
  key: us-full-time
  name: US full-time offer
spec:
  document: templates/offers/us-full-time.docx
  format: docx                       # docx | html
  availableFor:                      # offered only for jobs tagged with these values (or below them)
    location: [united-states]
    employment-type: [full-time]     # a company-defined dimension
  signers:
    candidate: required
    company: { role: recruiting-admin, required: false }
  expiresAfter: 7d
  coverMessage: offer-sent           # message template key
```

Tokens use the same language as messages ([`candidate-communications.md`](./candidate-communications.md#tokens)):

```text
Dear {{ candidate.preferred_name | default: candidate.first_name }},

We are delighted to offer you the position of {{ job.title }} in our
{{ job.dimensions.department.label }} team, starting {{ offer.fields.start-date | date: "long" }}.

Your base salary will be {{ offer.fields.base-salary | currency: offer.fields.currency }} per year.

{{ signature.candidate }}   {{ signature.date }}
```

- **Availability:** a template is offered only for jobs whose dimensions match its `availableFor`; when several match, the most specific is preselected. A template without `availableFor` is available everywhere.
- Uploading a template validates every token against the offer field set and the token catalog; unknown tokens are rejected at upload, not at send (Greenhouse reports them only at generation).
- Generating a document with a missing value blocks the send and names the missing field.
- Formatting is a filter (`| currency`, `| number: 0`, `| date: "long"`), so raw values never need a separate token.
- A recruiter can attach a one-off document to a single offer; it is stored on that version and audited.

## Acceptance and signature

**v1: click-to-accept with an audit trail**, implemented as the first `signature_provider` (decided 2026-10-24), so e-signature providers plug in behind the same interface. The candidate gets an email with a single-use, expiring link to the offer page. They can read the letter, download the PDF, and accept or decline (optionally with a reason). Big Buck records the version accepted, the exact document hash, timestamp, IP address, user agent and the email address the link was sent to, and stores a stamped PDF with that evidence.

Whether click-to-accept is a sufficient signature for a given company and jurisdiction is the company's decision; Big Buck says so in the product and documentation ([`consent-and-compliance.md`](./consent-and-compliance.md#who-is-responsible-for-what)).

**WIP: e-signature providers.** DocuSign, Dropbox Sign and Adobe Acrobat Sign through a `signature_provider` interface: Big Buck creates the envelope from the generated document, maps signer roles, and receives completion through the provider's webhook. The offer becomes `accepted` when the provider reports it fully signed.

**Recording a response.** A recruiter with `offer.record_response` can mark an offer accepted or declined on the candidate's behalf (for example, after a phone call), with a note. It is recorded as such, never as the candidate's own action.

> **Built in M6b** ([`db/structure.sql`](../db/structure.sql)): offer templates (Markdown, Liquid, claimed to dimensions), letter PDFs, `offer_signature_requests` (click-to-accept only; the `provider` column is where e-signature providers land), append-only `offer_responses`, sending, the candidate's page, expiry, recorded responses and the hire packet. Not yet: the "other open applications flagged for review" step, Word templates, and e-signature providers.

## After acceptance

1. `offer.accepted` is emitted.
2. If the organization setting `offers.hireOnAccept` is on (off by default; the SMB preset turns it on), the application gets the `hire` command; otherwise a recruiter hires it.
3. The person's lifecycle stage becomes `employee`, other open applications for that person are flagged for review, and the job's openings count goes down.
4. **HRIS hand-off (WIP):** a hire packet (person, job, dimensions, offer fields, signed documents) is sent to the connected HR system. Until that ships, the packet is available as a download and through `GET /applications/{id}/hire-packet` and the `application.hired` event.

## API

| Action | Endpoint |
|---|---|
| Create an offer (draft) | `POST /applications/{id}/offers` |
| Edit fields (creates a version after draft) | `PATCH /offers/{id}` with `If-Match` |
| Preview approval policy and steps (dry run) | `POST /offers/{id}/approval-preview` |
| Submit for approval | `POST /offers/{id}/submit-for-approval` |
| Approve or request changes | `POST /approvals/{id}/approve`, `POST /approvals/{id}/request-changes` |
| Generate documents | `POST /offers/{id}/documents` |
| Send | `POST /offers/{id}/send` with `message_template`, `expires_at`, `signature_provider` |
| Record a response | `POST /offers/{id}/record-response` |
| Rescind | `POST /offers/{id}/rescind` with `reason_key` |
| Version history | `GET /offers/{id}/versions` |
| Candidate view (public, token) | `GET /public/offers/{token}`, `POST /public/offers/{token}/accept`, `POST /public/offers/{token}/decline` |
| Hire packet | `GET /applications/{id}/hire-packet` |

Events: `offer.created`, `offer.version_created`, `offer.submitted`, `offer.approval_step_completed`, `offer.changes_requested`, `offer.approved`, `offer.sent`, `offer.viewed`, `offer.accepted`, `offer.declined`, `offer.expired`, `offer.rescinded`. Compensation fields follow field visibility in event payloads, and webhook endpoints with thin payloads never carry them.

## Permissions

| Permission | Allows |
|---|---|
| `offer.create` | Draft offers on applications in scope |
| `offer.read` | See offers in scope, without compensation fields |
| `offer.view_compensation` | See compensation fields |
| `offer.send` | Send approved offers |
| `offer.record_response` | Record accept or decline on the candidate's behalf |
| `offer.rescind` | Rescind an offer |
| `offer_template.manage` | Manage offer templates and offer fields |
| `approval_policy.manage` | Manage approval policies |
| `approval.override` | Approve on someone else's behalf (audited) |

Approving needs no permission of its own: being named by the policy is the grant, limited to that request.

## Tables

`offers`, `offer_versions`, `offer_documents`, `approval_policies`, `approval_policy_steps`, `approvals` (extended), `signature_requests`, `offer_responses`. The implemented columns are in [`db/structure.sql`](../db/structure.sql).
