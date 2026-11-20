# 27 — Candidate Communications

## Goal

Define every message Big Buck sends to candidates and the hiring team: which messages exist, how a company customizes them (per office, per job, per interview, per language), how they are sent and tracked, and how replies come back. Interview invites and confirmations get particular care because they are the messages candidates judge a company by.

## How other ATSs do it

Researched 2026-10-24. Lever's help pages did not load, so Lever is not included.

**Greenhouse**
- **Template types:** 18, each tied to the action that uses it, for example candidate availability request, candidate interview confirmation, candidate interview reminder, candidate self-schedule request, candidate rejection, extending offer, interviewer invite, scorecard due, thank you for applying, EEOC request.
- **Versions:** most types allow several versions, such as one interview confirmation per office.
- **Defaults:** shown in bold; editable but not deletable, and their type cannot change.
- **Tokens:** grouped around the candidate, job, interview, scheduling, the sender, and the company. Each token lists the templates it works in. Interview schedule tokens only fill once interviewers are scheduled. Some links (interview kit, scorecard) are generated and cannot be typed by hand.
- **Interview confirmations:** an email with .ics attachments, sent manually from the candidate's profile, with an optional 24-hour reminder. The .ics files do not update when the interview changes, so the recruiter must resend. An admin setting can add candidates to the live calendar event instead.
- **Interviewer invites:** one email template for all interviews by default, or customized per interview. Tokens are filled per interviewer at delivery.
- **Rejections:** emails can be scheduled for later, and un-rejecting cancels a scheduled rejection that hasn't gone out.
- **Candidate portal:** MyGreenhouse shows application status and real-time updates, and lets candidates self-schedule interviews and complete pre-hire tasks.

**Ashby**
- **Templates:** created by admins and searchable when composing. Tokens show in purple; a token with missing data shows a warning, and yellow placeholder text blocks sending until it is replaced.
- **Sending:** send now, at a set date and time, or after a delay; optional undo-send window of up to 15 seconds.
- **Who can email candidates:** limited by role. Emails sent through Ashby's own address carry a non-removable footer.
- **Interview confirmations:** whether they go out is an organization-wide default, overridable per schedule template.
- **Reminders:** as many as wanted per audience (candidates, interviewers), timed in days, hours or minutes before. Organization defaults can be overridden per interview plan or per schedule. The sender can be the organizer or a no-reply address. Slack is available for interviewers. A token inserts the video link or phone number.
- **Self-schedule links:** sent automatically on stage entry, with a connected email template.

Sources: [Greenhouse email template types](https://support.greenhouse.io/hc/en-us/articles/115002573326-Email-template-types), [Greenhouse token glossary](https://support.greenhouse.io/hc/en-us/articles/360007039771-Token-glossary), [Greenhouse confirmation email](https://support.greenhouse.io/hc/en-us/articles/360022120932-Send-an-interview-confirmation-email-with-Google-Calendar), [Greenhouse scheduling model](https://support.greenhouse.io/hc/en-us/articles/360021717371-Greenhouse-Scheduling-Model), [Greenhouse automated scheduling](https://support.greenhouse.io/hc/en-us/articles/36255269371419-Schedule-an-interview-with-automated-scheduling), [Greenhouse scheduled rejection emails](https://support.greenhouse.io/hc/en-us/articles/115003070843-Un-rejecting-candidates-with-scheduled-rejection-emails), [MyGreenhouse](https://www.greenhouse.com/blog/meet-mygreenhouse-a-new-kind-of-candidate-portal), [Ashby emails](https://docs.ashbyhq.com/sending-emails-from-the-candidate-profile), [Ashby confirmation default](https://www.ashbyhq.com/product-updates/default-confirmation-email), [Ashby reminders](https://ashbyhq.com/blog/product/interview-reminders), [Ashby Scheduling 2.0](https://www.ashbyhq.com/blog/product/ashby-scheduling-2-0).

### What Big Buck takes from this
1. **Typed templates.** A template's type decides where it can be used and which tokens it may contain. Each type ships with a default that can be edited but not deleted (Greenhouse).
2. **Specific beats general.** The interview's own template wins over the job's, which wins over the office or department template, which wins over the organization default.
3. **Live calendar invites, not static .ics files.** Greenhouse's .ics confirmations go stale when an interview moves; Big Buck puts the candidate on the live event ([`scheduling.md`](./scheduling.md#the-availability-engine)).
4. **Missing data blocks the send.** Tokens are validated when a template is saved, and a send with unfilled required data is refused (Ashby).
5. **Scheduled sends that cancel themselves.** A rejection can be delayed, and un-rejecting cancels it (Greenhouse).
6. **Reminder defaults with per-interview overrides**, for candidates and interviewers separately (Ashby).

## Message types

Every message Big Buck sends has a type. Types are fixed by Big Buck; templates are the company's.

| Type | Audience | Sent when | Default |
|---|---|---|---|
| `application-received` | Candidate | They apply | On |
| `availability-request` | Candidate | Scheduling mode `availability_request` | On |
| `self-schedule-invite` | Candidate | Scheduling mode `self_schedule` | On |
| `interview-confirmation` | Candidate | An interview is booked (accompanies the calendar invite) | On |
| `interview-updated` | Candidate | Time, place, link or interviewers change | On |
| `interview-cancelled` | Candidate | An interview is cancelled | On |
| `interview-reminder` | Candidate | Per reminder schedule | 24 h and 1 h before |
| `interview-calendar-description` | Candidate | Text inside the calendar event | Always |
| `interviewer-briefing` | Interviewers | An interview is booked; carries the kit, resume and scorecard links | On |
| `interviewer-reminder` | Interviewers | Per reminder schedule | 1 h before |
| `scorecard-due` | Interviewers | Scorecard not submitted after the interview | 2 h after, then daily |
| `rejection` | Candidate | An application is rejected | Off for un-interviewed applicants; on after interviews |
| `offer-sent` | Candidate | An offer is sent | Always |
| `offer-expiring` | Candidate | Before `expires_at` | 48 h before |
| `offer-rescinded` | Candidate | An offer is rescinded (always reviewed by a person before sending) | Manual |
| `approval-request` | Approvers | An approval step starts | On |
| `notice` and `consent-request` | Candidate | A compliance policy requires a notice or consent ([`consent-and-compliance.md`](./consent-and-compliance.md)) | Per policy |
| `data-request-response` | Candidate | A data access or erasure request is fulfilled | Manual |
| `sequence-step` | Prospect | An outreach sequence step | Per sequence |
| `general` | Anyone | A person writes a message by hand | Manual |

## Templates

```yaml
apiVersion: bigbuck/v1
kind: MessageTemplate
metadata:
  key: onsite-confirmation-london
  name: Onsite confirmation (London)
spec:
  type: interview-confirmation
  channel: email                    # email in v1; sms and whatsapp are planned
  availableFor:
    location: [london]              # most specific match wins
  sender: coordinator               # coordinator | recruiter | organizer | no-reply | shared:<address>
  locales:
    en:
      subject: "Your interview with {{ org.name }} on {{ interview.start | date: 'EEEE d MMMM' }}"
      body: |
        Hi {{ candidate.preferred_name | default: candidate.first_name }},

        You're confirmed for **{{ interview.name }}** for the {{ job.title }} role.

        **When:** {{ interview.start | datetime: candidate.time_zone }} ({{ interview.duration }} minutes)
        **Where:** {{ interview.location | default: interview.meeting_url }}
        {% if settings.show_interviewers_to_candidate %}**With:** {{ interview.interviewers | names }}{% endif %}

        {{ interview.candidate_instructions }}

        Need a different time? {{ links.reschedule }}

        {{ sender.signature }}
    fr:
      subject: "Votre entretien avec {{ org.name }} le {{ interview.start | date: 'EEEE d MMMM' }}"
      body: |
        …
```

Rules:
- **Selection order, most specific first:** the interview's own template (from the pipeline) → the job's → a template whose `availableFor` matches the job's dimensions (deepest match wins) → the organization default for the type.
- **Language:** the candidate's preferred language if the template has it, otherwise the posting's language, otherwise the organization default.
- **Defaults:** every type has an organization default that can be edited but not deleted. New organizations get English defaults for every type, which the company replaces or extends.
- **Validation on save:** every token must exist and be allowed for the template's type. For example, `links.reschedule` is allowed in interview messages but not in a rejection.
- **Preview with real data:** any template can be previewed against a real application before saving.
- **Blocked sends:** if a required token has no value at send time (no meeting link yet, no interview time), the send is refused and the missing field is named. Optional tokens use `| default:`.
- **Permissions:** `message_template.manage` covers templates ([`permissions.md`](./permissions.md#every-setting-is-a-permission)); who may send manual emails is separate (`communication.send`).

## Tokens

One token language serves messages, offer letters and calendar descriptions: Liquid-style `{{ path | filter }}` with `{% if %}` blocks only (no loops in v1).

| Group | Examples |
|---|---|
| Candidate | `candidate.first_name`, `candidate.preferred_name`, `candidate.time_zone`, `candidate.email` |
| Job | `job.title`, `job.posting_url`, `job.dimensions.department.label`, `job.dimensions.level.attributes.band` (subject to field visibility) |
| Interview | `interview.name`, `interview.start`, `interview.duration`, `interview.meeting_url`, `interview.location`, `interview.interviewers`, `interview.candidate_instructions`, `interview.stage` |
| Panel | `schedule.interviews` (rendered as an itinerary), `schedule.start`, `schedule.end` |
| Offer | `offer.fields.*`, `offer.expires_at`, `offer.link` |
| People | `sender.name`, `sender.signature`, `recruiter.name`, `coordinator.name`, `hiring_manager.name` |
| Organization | `org.name`, `org.vars.*` ([`org-structure.md`](./org-structure.md#organization-variables)) |
| Links (generated, never typed) | `links.reschedule`, `links.self_schedule`, `links.availability`, `links.offer`, `links.consent`, `links.unsubscribe` |

Filters: `default`, `date`, `datetime` (with a time zone), `currency`, `number`, `names`, `upcase`, `downcase`.

Interviewer-only tokens (interview kit, scorecard link, resume link) exist only in `interviewer-briefing`, `interviewer-reminder` and `scorecard-due`. Validation rejects them in any candidate-facing type, so internal links cannot leak to a candidate.

## Per-interview communications

Each interview inside a pipeline stage can carry its own communications ([`job-pipelines.md`](./job-pipelines.md#interviews-inside-stages)):

```yaml
    - key: onsite
      name: Onsite
      type: interview
      scheduleTogether: true
      interviews:
        - key: system-design
          name: System design
          format: video
          duration: 60
          scheduling: self_schedule
          scorecard: system-design
          communications:
            confirmation: onsite-confirmation       # template key; omit to use the default chain
            reminders:
              candidate: [ { before: 24h }, { before: 1h } ]
              interviewers: [ { before: 1h } ]
            candidateInstructions: |
              Bring a laptop with a browser. We'll share a drawing tool at the start.
            interviewerBriefing: system-design-briefing
```

- Jobs change these with the usual one-off edits (`update_interview`), so a recruiter can tweak one job's onsite instructions without touching the template.
- `candidateInstructions` is plain candidate-safe text that templates show through `{{ interview.candidate_instructions }}`; it is also written into the calendar event description.
- For a panel (`scheduleTogether: true`) the candidate gets **one** confirmation with the full itinerary plus one calendar event per interview, not one email per interview.

## Reminders

- Organization defaults per audience, set in the scheduling settings.
- Overrides per interview in the pipeline template, then per job.
- Several reminders on the same day can be combined into one message.
- Reminders are cancelled automatically when the interview is cancelled or moved, and re-scheduled for the new time.
- v1 channel: email. Slack for interviewers, and SMS or WhatsApp for candidates, are WIP and planned respectively.

## Sending and replies

> **Built in M4a (2026-10-25).** Mailboxes connect with Google OAuth (personal, or a shared one by an admin) or through domain-wide delegation. Delegation is keyless: Big Buck's service account signs the token request through the IAM Credentials API, so no service-account key exists. OAuth refresh tokens live only in Secret Manager. The first shared mailbox connected becomes the organization's default, which templates with `sender_role: shared` and no address send from. A hand-written message uses `sender_role: sender` (the writer's own Gmail, or a shared mailbox they are granted).
>
> The queue never holds a database transaction across a call to Gmail. A message is claimed and committed, sent, then recorded. A message left mid-send by a crash is settled by asking Gmail for its Message-ID before anything is sent again, so nobody receives it twice. A message that cannot go yet stays queued with a stated `held_reason`:
> - `quiet_hours`
> - `mailbox_daily_limit`
> - `mailbox_reauth_required`, and the owner is told
> - `waiting for …`, naming the missing mailbox
>
> At send time, do-not-contact, outreach opt-outs, required tokens and the application's status are checked again.
>
> **Built in M4b.** Gmail push and a backstop sync store only mail with a participant in Big Buck, threaded by Gmail thread or `In-Reply-To`; unplaced mail for someone with confidential work is confidential. Sequences run email, wait and task steps inside a sending window, stop on reply, application, unsubscribe or do-not-contact, and are confidential with their project. The contact cooldown (`organizations.contact_cooldown_days`, default 14) is checked across every address the human has and every sequence.
>
> Templates allow the tokens of their type only, and `{% if %}`/`{% unless %}` but no loops. The filters built so far are `default`, `date`, `upcase`, `downcase`, `capitalize`, `strip`, `escape` and `truncate`; `datetime`, `currency`, `number` and `names` arrive with interviews and offers. Types available now: `application-received` (sent from the default shared mailbox when someone applies on the careers page), `rejection` (when a rejection asks to notify; cancelled if un-rejected first), `general` and `sequence-step`. Outreach carries an unsubscribe link and RFC 8058 one-click headers.

Decided 2026-10-24: candidate mail goes out from real company mailboxes through Gmail, and Big Buck tracks both kinds.

**Two kinds of mailbox.**
- **Personal:** a recruiter's or sourcer's own Gmail. They connect it once with Google; sequences and one-to-one messages go from it, so candidates see a real person and reply to them.
- **Shared:** a company mailbox such as recruiting@acme.com, connected by an admin. Confirmations, reminders, scheduling links, rejections and offers usually go from it. Admins grant who may send as it (`mailbox.send_as`).

**Which mailbox sends.** Each template names a sender role (`recruiter`, `coordinator`, `organizer`, or `shared` with a named shared mailbox). The role resolves to a connected mailbox at send time; if the person's mailbox is not connected or needs re-authorization, the send waits and the sender is told, rather than silently switching mailboxes.

**Tracking both.** Big Buck syncs every connected mailbox through Gmail push notifications, with a periodic history sync as a backstop. It stores only messages where a participant matches a person in Big Buck, and ignores the rest, including mail between colleagues. A matched reply is attached to the person and thread, appears on the timeline, and stops any sequence it answers. A recruiter can mark a synced thread private.

**Limits.** Google caps each Workspace account at 2,000 messages a day. The send queue spreads work within each mailbox's cap and holds messages that would exceed it. Keeping outreach on personal mailboxes and transactional mail on shared ones also keeps a sourcing spam complaint from affecting interview reminders.

**Google requirements.** Sending uses `gmail.send` (sensitive: app verification). Syncing uses `gmail.readonly` (restricted: restricted-scope verification and a CASA security assessment every 12 months). Gmail data is used only to show and act on candidate communication, under Google's Limited Use rules. Workspace admins can connect every recruiter at once through domain-wide delegation instead of one OAuth consent per person.

**Big Buck's own notifications** (approval requests, scorecard reminders, "your mailbox needs reconnecting") go to users from Big Buck's domain through a transactional email provider. They never go to candidates.

**Scheduled sends.** Any message can be sent now, at a time, or after a delay. Scheduled messages are cancelled automatically when the reason disappears: un-rejecting cancels a pending rejection, and cancelling an interview cancels its reminders.

**Quiet hours.** Automated candidate messages wait for the candidate's daytime (default 08:00–20:00 in their time zone). Messages the candidate asked for (a booking confirmation) go immediately.

**Undo window.** Manual sends wait 10 seconds by default so the sender can undo, as Ashby allows.

**Compliance hooks.** Before any send, Big Buck checks do-not-contact and the company's compliance policies. Outreach (`sequence-step`) needs whatever consent the policy requires and always includes `links.unsubscribe`. Transactional messages (confirmations, offers) are not blocked by outreach opt-outs ([`consent-and-compliance.md`](./consent-and-compliance.md)).

**Tracking.** Delivery, bounce and reply are tracked. Open tracking is off by default and is a company setting, because some jurisdictions treat tracking pixels as needing consent.

## Confidential communication

Decided 2026-10-24. Every message belongs to a person and, where it can be known, to an application, project or sequence. Its visibility follows the most restrictive of those:

- **Linked messages inherit.** A message sent from Big Buck for an application on a confidential job is visible only to that job's access list. Replies to it inherit the thread's visibility.
- **Synced mail is classified by thread.** A synced Gmail message joins the thread it belongs to and takes that thread's visibility. A message Big Buck cannot place, for a person who has any confidential application, is visible only to its sender and the confidential job's access list until someone files it. Unknown is treated as confidential.
- **Per-job choice to skip sync.** A confidential job can turn off mailbox sync for its candidates entirely, as Ashby allows; messages sent from Big Buck are still recorded.
- **Offer-stage mail is private.** Messages sent while an application is in an offer stage, or that use offer tokens, are visible only to holders of `offer.read`, because they usually carry compensation (Ashby marks offer-stage email private for the same reason).
- **Private threads.** The sender can mark any thread private: visible to them and to holders of `person.read_restricted`.
- **Confidential sequences.** A sequence can be confidential: hidden from other users' lists, reports and the person's timeline. Sequences for a confidential sourcing project are confidential automatically.
- **Contact cooldown.** Before any enrollment, Big Buck checks when the address was last contacted by any sequence, confidential or not. Inside the company's cooldown window (default 14 days) the enrollment is refused with the same message in every case, "this person was contacted recently; try again after <date>", so it reveals nothing about a confidential search ([`permissions.md`](./permissions.md#confidential-sourcing)).
- **Interviewer-facing messages** for confidential jobs use the job's code name.
- **Opt-outs cross records.** Do-not-contact and consent are checked against the address, across every record that holds it, before any send.

The candidate never sees any of this: their emails read the same as on any other job.

## Candidate-facing pages in v1

No full portal in v1 ([`v1-scope.md`](./v1-scope.md#out-of-v1)). Instead, each link opens a single-purpose page in the company's branding: book or reschedule an interview, submit availability, read and accept an offer, give or withdraw consent, and request a copy or deletion of their data. A portal that ties these together (status, upcoming interviews, documents) is planned.

## API

| Action | Endpoint |
|---|---|
| Templates | `GET|POST /message-templates`, `GET|PATCH /message-templates/{key}` |
| Preview against a real record | `POST /message-templates/{key}/preview` with `application_id` |
| Which template would be used (dry run) | `POST /message-templates/resolve` with `type`, `application_id`, `interview_key` |
| Send a message | `POST /communications` with `template_key` or a body, `to`, `send_at` |
| Scheduled messages | `GET /scheduled-messages`, `POST /scheduled-messages/{id}/cancel` |
| Mailboxes | `GET|POST /mailbox-connections`, `POST /mailbox-connections/{id}/reauthorize`, `GET|PUT /mailbox-connections/{id}/senders` (who may send as a shared mailbox) |

Events: `communication.sent`, `communication.delivered`, `communication.bounced`, `communication.replied`, `scheduled_message.cancelled`.

## Tables

`message_templates` (extended), `message_template_locales`, `scheduled_messages`, `mailbox_connections`, `mailbox_connection_senders`, plus `communications` ([`db/structure.sql`](../db/structure.sql)).
