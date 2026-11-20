# 28 — Consent and Compliance Policies

## Principle

**Big Buck supports compliance; the company owns it.** The company using Big Buck is the data controller. It decides which notices candidates see, which consents it collects, how long it keeps data and on what legal basis, with its own counsel. Big Buck is the processor and provides the machinery: it shows what the company configured, records the evidence, blocks actions the company's policies forbid, and runs retention and data requests. Big Buck never decides what the law requires, and its product and documentation say so.

Laws change often (US state AI-in-hiring laws alone changed several times in 2025–2026). Big Buck therefore treats compliance as **configuration the company can change quickly and safely**, not as rules built into the code.

## How other ATSs do it

Researched 2026-10-24.

| | Greenhouse | Ashby | Lever |
|---|---|---|---|
| Who is responsible | Customer selects and maintains its legal basis and writes its own notice language "in consultation with counsel" | Positions customers as controllers and itself as processor under its DPA | Help centre documents GDPR settings and which countries trigger them (pages did not load for detail) |
| Consent | Consent extension emails before retention expires (requires explicit consent as the chosen legal basis); manual resend | Customizable consent forms at application, consent renewal, anonymization when consent lapses | |
| Retention | Retention time; designated people notified when it passes; offices can be included or excluded | Multiple rules per category, each targeting job locations with its own period and consent language; when rules overlap, the **latest** retention date wins; audit reports per rule | |
| Other | Candidate data packets for access requests; data collection emails for people added outside a job post | Do-not-contact flag; export, delete or anonymize while keeping aggregate reporting; demographic data kept separate | |

Sources: [Greenhouse GDPR features](https://support.greenhouse.io/hc/en-us/articles/360061849112-GDPR-features-overview), [Ashby retention rules](https://www.ashbyhq.com/product-updates/create-multiple-data-retention-rules-for-flexible-compliance-control), [Ashby GDPR](https://www.ashbyhq.com/gdpr), [Lever GDPR settings](https://help.lever.co/hc/en-us/articles/20087339443101).

What Big Buck takes from this: company-written language, rules scoped by location, per-rule consent text, evidence of exactly what was shown, and explicit customer responsibility. Where Ashby silently picks the latest retention date when rules overlap, Big Buck makes the company choose, because "keep longer" and "delete sooner" can both be the legal answer depending on the law.

## Concepts

| Concept | What it is | Who writes it |
|---|---|---|
| **Notice** | A piece of text a candidate must be shown: a privacy notice, an "automated tools are used in this process" notice, a recording notice. Versioned; every change is a new version | Company |
| **Consent purpose** | Something the company asks permission for, with its own key, label, declared legal basis and whether it is required to proceed. Examples: `data-processing`, `talent-pool`, `recording`, `automated-tools`, `outreach` | Company |
| **Compliance policy** | When it applies (candidate location, job location, how the person entered), and what it requires: notices, consents, retention, response times, blocked actions | Company |
| **Evidence** | What was shown or agreed: notice version, consent purpose, time, channel, IP address, the link used | Big Buck records it |
| **Enforcement** | Showing notices, collecting consent, blocking actions, running retention, tracking data requests | Big Buck does it, as configured |

## A policy

```yaml
apiVersion: bigbuck/v1
kind: CompliancePolicy
metadata:
  key: eu-candidates
  name: Candidates in the EU and EEA
spec:
  priority: 20
  when:
    candidate.location.region: [eu, eea]       # the location the candidate gives
    # job.dimensions.location: [europe]         # or the job's location, or both
  notices:
    - notice: privacy-notice-eu
      show: [apply-form, first-outreach]        # where the notice must appear
  consents:
    - purpose: data-processing
      collect: apply-form
      required: true
    - purpose: talent-pool
      collect: apply-form
      required: false
      expiresAfter: 24mo
  retention:
    afterLastActivity: 12mo
    action: anonymize                           # anonymize | delete | review
    extensionRequest:                           # ask before acting
      sendBefore: 30d
      template: consent-extension
  dataRequests:
    respondWithin: 30d
    assignTo: role:recruiting-admin
  blocks:
    - action: sequence.enroll
      unless: { consent: talent-pool }
    - action: interview.external
      unless: { consent: automated-tools }
---
apiVersion: bigbuck/v1
kind: CompliancePolicy
metadata:
  key: everyone-else
  name: Default policy
spec:
  fallback: true                                # exactly one; applies when nothing else matches
  notices:
    - notice: privacy-notice
      show: [apply-form]
  consents:
    - purpose: data-processing
      collect: apply-form
      required: true
  retention:
    afterLastActivity: 24mo
    action: review
---
apiVersion: bigbuck/v1
kind: Notice
metadata:
  key: privacy-notice-eu
  name: EU candidate privacy notice
spec:
  renotify: on-next-contact                     # never | on-next-contact | immediately
  locales:
    en: |
      Acme Ltd processes your application data to assess your candidacy…
    de: |
      Acme Ltd verarbeitet Ihre Bewerbungsdaten…
```

## How policies are applied

**Matching.** A person's applicable policies come from the location they gave, the location of the job they applied to, and how they entered (applied, sourced, referred, imported). IP-based location is never used on its own; a company can turn it on as a hint for people who gave no location. If nothing matches, the `fallback` policy applies, and `validate` fails without one.

**Several policies at once.** All matching policies apply: their notices, consents and blocks are combined. For retention, the matching policy with the highest `priority` decides. `bigbuck config validate` warns whenever two policies can match the same person with different retention periods, and names the one that wins, so the company decides deliberately instead of by accident.

**Where Big Buck enforces them**
- **Apply form:** shows the required notices for the candidate's location (re-evaluated when they change their location) and collects consents, refusing to submit if a required consent is missing.
- **Sourced and referred people:** the first outreach carries the required notices; people added without contact get the policy's notice the first time Big Buck contacts them.
- **Actions:** each `block` is checked before the action runs, whether a person, an automation or an agent triggered it. A blocked action fails with `code: blocked_by_policy`, naming the policy and the missing consent.
- **Interviews by connected providers:** `external` interviews are blocked until the consents the policy names are in place ([`job-pipelines.md`](./job-pipelines.md#interviews-inside-stages)).
- **Retention:** a nightly job finds people past their retention date, sends extension requests where configured, and then anonymizes, deletes or queues them for review. Every action is logged. Anonymizing keeps aggregate reporting intact, as Ashby does.
- **Data requests:** access, correction and erasure requests are tracked with a due date from `respondWithin`. Access requests produce an export of everything held about the person (their "packet").
- **Messages:** outreach checks consent and do-not-contact before sending, and always carries an unsubscribe link ([`candidate-communications.md`](./candidate-communications.md#sending-and-replies)).

**Evidence.** Every notice shown and every consent given or withdrawn records the exact notice version and text hash, purpose, time, channel and IP address, linked to the policy version that required it. When an auditor asks "what did this candidate see on 3 March?", the answer is a record, not a reconstruction.

## When laws change

1. The company updates its policy or notice files (or edits them in the UI). Each change is a config revision.
2. `bigbuck config plan` shows the impact before anything changes: for example, "Notice `privacy-notice-eu` v3 → v4: 1,240 people will be re-notified on next contact; retention for 312 people moves from 24 to 12 months, and 41 of them pass their new date immediately."
3. The company applies the change after its own review. Retention changes that would delete data immediately need an explicit confirmation.

**Example policies, never applied automatically.** Big Buck publishes a library of example policies and notices (for instance GDPR-style, CCPA-style, and AI-in-hiring notice examples), each marked *"Example only, not legal advice"* with the date it was last reviewed. When Big Buck updates an example because a law changed, admins see it in a changelog with a diff against their own policy. Big Buck never applies it for them.

### Legal hold

A hold on a person, application or job pauses retention and erasure for everything it covers until it is released. Holds need `data_request.manage`, always carry a reason, and every skipped action is logged (`retention_actions.action = held`). Tables in [`db/structure.sql`](../db/structure.sql).

### Erasure reaches every copy

Erasing or anonymizing a person clears their personal fields, documents and message bodies, deletes their timeline and search rows, and redacts their events inside the 30-day replay window. Audit history never held their personal values in the first place, and backups age out with the 7-day recovery window, which the product documents as the erasure lag ([`db/structure.sql`](../db/structure.sql)).

### Example policies in the SMB preset (after v1)

So that the apply form works on day one, the owner setup asks where the company's candidates are and who handles privacy questions, then activates the matching example policies filled with the company's name and privacy contact ([`owner-setup.md`](./owner-setup.md#the-setup)). Before finishing, the owner confirms that the company is responsible for its policies and will review the examples. Skipping the privacy step does not count as that confirmation: the examples stay inactive until the owner confirms. The examples stay flagged "example, not reviewed" in settings and on the setup checklist until the owner marks them reviewed. In v1 (enterprise), Big Buck activates nothing: the company writes or imports its policies, reviewed through plan and apply. Activating an example does not make Big Buck responsible for it.

> **Built in M7b** ([`db/structure.sql`](../db/structure.sql)): legal holds, the retention job with extension requests and reviews, data requests with the access packet, and erasure across tables, storage and events. What it does and the defaults taken are in [`progress.md`](./progress.md#m7b--retention-data-requests-legal-holds-erasure) and [`decisions.md`](./decisions.md).
>
> **Built in M7a** ([`db/structure.sql`](../db/structure.sql)): purposes, notices and versions, policies, append-only consents and notice receipts, the apply-form gate, blocked actions and the first-outreach notice. Policies use snake_case keys over the API (`after_last_activity`, `expires_after`). Not yet: policies in configuration files (M8).

## Who is responsible for what

| The company (controller) | Big Buck (processor) |
|---|---|
| Deciding which laws apply and what they require | Providing policy, notice, consent and retention tools |
| Writing notice and consent wording | Showing the right version to the right person, in their language |
| Choosing the legal basis for each purpose | Recording the declared legal basis with each consent |
| Setting retention periods and actions | Running retention on schedule and logging every action |
| Deciding whether click-to-accept is a sufficient signature for its offers ([`offers.md`](./offers.md#acceptance-and-signature)) | Recording acceptance evidence |
| Bias audits and impact assessments for automated tools it uses | Adverse-impact reports from EEO aggregates and provider audit logs |
| Responding to data requests | Tracking deadlines and producing exports, corrections and erasures |
| Reviewing example policies with counsel before use | Keeping examples dated and clearly labelled |

The product shows this split where it matters: on the compliance settings page, on every example policy, and in the setup checklist.

## API

| Action | Endpoint |
|---|---|
| Policies and notices | Through configuration ([`recruiting-as-code.md`](./recruiting-as-code.md)), and `GET /compliance/policies`, `GET /notices/{key}/versions` |
| Which policies apply to a person, and why (dry run) | `GET /people/{id}/compliance` |
| Record consent (from Big Buck pages or the company's own forms) | `POST /people/{id}/consents` with `purpose`, `notice_version`, evidence |
| Withdraw consent | `POST /people/{id}/consents/{purpose}/withdraw` |
| Data requests | `POST /data-requests`, `GET /data-requests?status=open`, `POST /data-requests/{id}/complete` |
| Retention preview | `GET /compliance/retention-preview?days=30` — who will be acted on, and how |

Events: `person.consent_changed`, `notice.shown`, `compliance.action_blocked`, `retention.extension_requested`, `retention.applied`, `data_request.created`, `data_request.completed`.

## Tables

`compliance_policies`, `notices`, `notice_versions`, `consent_purposes`, `consents` (now referencing purposes and notice versions), `notice_receipts`, `data_requests`, `retention_actions`. The implemented columns are in [`db/structure.sql`](../db/structure.sql).
