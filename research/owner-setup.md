# 29 — Owner Setup and Defaults (SMB preset, after v1)

> **Deferred 2026-10-24.** v1 is built for enterprise and onboarded by Big Buck ([`build-plan.md`](./build-plan.md)). This design is kept for the SMB preset that follows: the same product with a restricted, pre-chosen configuration. When it is built, two additions apply: self-serve sign-up needs trust and safety controls (verified company identity before a careers page uses a company's name, send limits for new organizations, review of first postings), and skipping the privacy step cannot stand in for the owner's confirmation, so the example policies stay inactive until the owner confirms.

## Decisions (2026-10-24)

1. **SMB works out of the gate.** A new account can post a job, take applications, schedule interviews, send an offer and get it accepted without visiting a settings page, connecting anything, or waiting on anyone.
2. **The owner chooses the defaults.** The account owner goes through a short setup that asks the few questions whose answers really differ between companies. Every question has a recommended answer already selected, every step can be skipped, and skipping gives a working account.
3. **Setup is configuration, like everything else.** The owner's choices are written as one config revision (`source = setup`). They can be changed later in settings, as files ([`recruiting-as-code.md`](./recruiting-as-code.md)), or by re-opening any setup step.

## The setup

Seven steps, each on one screen. "Recommended" means pre-selected. Target: under 10 minutes if the owner reads every step, under 1 minute if they accept every recommendation.

| Step | Question | Choices (recommended in bold) | What it writes |
|---|---|---|---|
| 1. Company | Name, logo, brand colour, careers page address, time zone, where you hire | Prefilled from the sign-up email domain and website; **careers page at `<company>.jobs.<bigbuck-domain>`** | Organization variables, `location` dimension values, careers page |
| 2. Team and permissions | Who should be able to change things? | "Just me, or a small team where everyone can edit" (`open`) · **"A recruiting team"** (`recruiting-team`) · "Only admins" (`admins-only`) | Governance preset ([`permissions.md`](./permissions.md#governance-presets)); optional teammate invites with roles |
| 3. Hiring process | Which hiring processes do you run? How do interviews usually happen? | **General hiring** (always included, default) · Engineering · Hourly / high-volume · Sales. Interview format: **video (Google Meet)** · phone · in person. Scheduling: **candidates pick a time** (`self_schedule`) · a coordinator schedules | Pipeline templates with interviews and scorecards; default scheduling mode ([`job-pipelines.md`](./job-pipelines.md)) |
| 4. Calendar and email | Connect your calendar? How should candidate emails be sent? | Calendar: **connect Google** (one consent screen if signed in with Google) · skip and use availability set in Big Buck. Email: **Big Buck sending address, ready now** · your own domain (adds DNS records, can be done later) | Calendar connection or no-calendar mode ([`scheduling.md`](./scheduling.md#no-calendar-mode)); sending address ([`candidate-communications.md`](./candidate-communications.md#sending-and-replies)) |
| 5. Offers | Who approves offers? Offer basics | Approval: no approval · **hiring manager approves** · hiring manager, then an admin. Currency, **offer expires after 7 days**, **mark hired when accepted** | Catch-all approval policy, offer template and fields, `offers.hireOnAccept` ([`offers.md`](./offers.md)) |
| 6. Candidate messages | Languages, and which emails go out automatically | Language: **from step 1's locations**. Auto-send: **application received** on · **rejection after an interview** on, delayed to the next business morning · rejection before any interview off · **reminders 24 h and 1 h before** | Default message templates per type and language, reminder defaults ([`candidate-communications.md`](./candidate-communications.md)) |
| 7. Privacy | Where are your candidates? Who handles privacy questions? How long do you keep candidate data? | Regions: **from step 1**. Privacy contact: **the owner's email**. Retention: 12 · **24** · 36 months after last activity. Owner confirms: "We are responsible for our privacy policies and will review these examples" | Example compliance policies and notices for those regions, filled with the company's details and labelled as examples ([`consent-and-compliance.md`](./consent-and-compliance.md#when-laws-change)) |

At the end, a summary screen lists every choice with a "change" link, then: **Post your first job**.

Rules:
- **Skip anything.** A skipped step applies its recommended answers. Skipping the whole setup applies them all.
- **Nothing blocks.** No step waits on DNS, an admin elsewhere, or a third party. Steps that involve those (own email domain, domain-wide calendar access) offer a working default now and a reminder in the setup checklist.
- **Owner only.** Setup is run by the organization owner, or anyone they give `settings.manage`.
- **Revisable.** Every step can be re-opened from settings. Re-running a step shows the plan (what changes, what it affects) before applying, like any config change.
- **Agents can run it.** Setup is an API (below), so an onboarding agent or a script can complete it with the same choices.

## The setup checklist

After setup, a checklist stays on the home screen until each item is done or dismissed. None of them are needed for the account to work.

- Review your privacy notices and retention with your counsel (from step 7)
- Use your own email domain for candidate emails
- Connect calendars for interviewers whose availability Big Buck can't see
- Add a hiring manager to each open job
- Upload your offer letter, or keep the default
- Invite your team

## Fallbacks that keep it working

The setup's defaults are only half of "out of the gate". The other half is that the product keeps working when something is missing.

| Missing | What happens instead |
|---|---|
| No calendar connected | **No-calendar mode:** interviewers' availability comes from the working hours set in Big Buck; invites go out by email with calendar attachments; the video link is the interviewer's saved personal meeting link ([`scheduling.md`](./scheduling.md#no-calendar-mode)) |
| A colleague's free/busy isn't visible | That interviewer is scheduled from their Big Buck working hours, the suggestion is marked "calendar not checked", and they get a one-click link to connect their calendar |
| No own email domain | Emails go from the Big Buck sending address for the company, with replies captured and forwarded ([`candidate-communications.md`](./candidate-communications.md#sending-and-replies)) |
| No hiring manager on the job, or the requester is the only possible approver | The approval step follows its `ifNoApprover` rule; the setup policy skips the step and records why ([`offers.md`](./offers.md#approval-policies)) |
| No offer letter uploaded | The default offer letter template, filled from the company's details |
| No privacy policy written yet | The example policy chosen in step 7 is active, with the company's name and privacy contact, and stays flagged as an example until the owner marks it reviewed |
| A one-person company | The owner is recruiter, hiring manager and interviewer; nothing waits for a second person |

## Release gate (SMB preset)

The SMB preset does not ship until this passes, automated and repeated on every release:

> A new account signs up with Google, accepts every recommendation in setup, posts a job, applies to it as a candidate, books an interview through the self-schedule link, submits a scorecard, sends an offer, and accepts it as the candidate, all in one session, without opening a settings page or touching DNS.

Run it twice: once with Google Calendar connected and once with the calendar step skipped (no-calendar mode).

A launch dependency: Google app verification for the calendar scopes must be complete before launch. Until then, Google shows an "unverified app" warning and limits the number of users ([`scheduling.md`](./scheduling.md#google-v1)), which would break the first impression.

## Enterprise

Enterprise accounts can use the same setup, or skip it entirely and apply their configuration from a repository (`bigbuck config init --preset admins-only`, then `apply`). The setup and the files produce the same thing: config revisions.

## API

| Action | Endpoint |
|---|---|
| Current setup state and recommended answers | `GET /setup` |
| Answer a step (dry run returns the plan) | `PUT /setup/steps/{step}?dry_run=true` |
| Finish, applying recommended answers to any skipped step | `POST /setup/complete` |
| Re-open a step later | `PUT /setup/steps/{step}` (creates a new config revision) |
| Checklist | `GET /setup/checklist`, `POST /setup/checklist/{item}/dismiss` |

Events: `setup.step_completed`, `setup.completed`, `setup.checklist_item_completed`.
