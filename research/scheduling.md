# 26 — Scheduling

## The short answer

**Yes, scheduling can run natively on Google, with no third-party scheduling vendor.** The Google Calendar API provides everything the calendar side needs: free/busy lookups, event creation with Google Meet links, meeting rooms, and change notifications. What Google does not provide is the *scheduling logic*: deciding who interviews, when, in what order, within whose working hours and load limits, and what happens when someone declines. That logic is Big Buck's own **availability engine**, described below.

Two more mechanics are needed beyond "connect Google":
1. **A way to see every interviewer's calendar without every interviewer connecting.** Enterprise customers authorize Big Buck once for the whole Google Workspace domain (domain-wide delegation). Smaller customers connect the coordinator's calendar, which can see colleagues' free/busy wherever the Workspace's sharing settings allow it.
2. **Microsoft 365 for companies not on Google.** Microsoft Graph offers the same building blocks; it is WIP for v1 ([`v1-scope.md`](./v1-scope.md#integrations)).
3. **A mode that needs no calendar at all**, so scheduling works on day one for any company, including Microsoft shops before Graph ships and owners who skip the calendar step ([no-calendar mode](#no-calendar-mode)).

## How other ATSs do it

| | Greenhouse | Ashby |
|---|---|---|
| Calendars | Google Calendar and Outlook 365; the scheduler connects a calendar; shared calendars supported | Bi-directional calendar sync |
| Suggestions | Window from tomorrow to 30 days out; respects candidate availability, interviewer working hours and busy events; events marked available can be overlapped; interviewers over their limits are ranked lower; panels over one or several days | Auto-scheduler generates full schedules for panels and multi-day loops (advanced add-on); considers recent interviewer load |
| Candidate input | Availability requests; self-schedule requests | Self-serve booking links sent automatically on stage entry; availability requests that trigger auto-scheduling on submit |
| Interviewers | By name, by group, or by hiring-team role | Interviewer pools with qualified members, trainees and shadowing; dynamic interviewers by hiring-team role |
| Changes | Changes start in the interviewer's calendar and sync back; candidate confirmations are emails with .ics files that do **not** update when the interview changes; optional setting adds the candidate to the live calendar event | Declined interviewers are swapped for an alternate from the pool automatically; holds; holiday blocks; debriefs |
| Reminders | Optional 24-hour reminder on confirmation | Configurable reminders to candidates and interviewers (email; Slack for interviewers) with org defaults and per-plan overrides |

Sources: [Greenhouse automated scheduling](https://support.greenhouse.io/hc/en-us/articles/36255269371419-Schedule-an-interview-with-automated-scheduling), [Greenhouse scheduling model](https://support.greenhouse.io/hc/en-us/articles/360021717371-Greenhouse-Scheduling-Model), [Greenhouse confirmation email](https://support.greenhouse.io/hc/en-us/articles/360022120932-Send-an-interview-confirmation-email-with-Google-Calendar), [Ashby Scheduling 2.0](https://www.ashbyhq.com/blog/product/ashby-scheduling-2-0), [Ashby interviewer pools](https://docs.ashbyhq.com/interviewer-pools), [Ashby reminders](https://ashbyhq.com/blog/product/interview-reminders).

What Big Buck takes from this: live calendar invites for candidates by default (static .ics files go stale), self-scheduling triggered by stage entry, interviewer pools with load balancing, automatic replacement when an interviewer declines, and reminder defaults with per-interview overrides.

## Calendar mechanics

### Google (v1)

| Need | Google API |
|---|---|
| Busy times | `freebusy.query`: up to 50 calendars per call (`calendarExpansionMax`), groups up to 100 members; returns busy periods only. Accepts the narrow `calendar.freebusy` or `calendar.events.freebusy` scopes |
| Create the interview | `events.insert` on the organizer calendar with attendees and `sendUpdates=all` |
| Video link | `conferenceData.createRequest` with `conferenceDataVersion=1`. Google advises generating a unique conference per event, never reusing one |
| Meeting rooms | Invite the room's resource email as an attendee; the room accepts or declines by itself. Rooms are listed through the Admin SDK Directory API |
| Hide the guest list from the candidate | `guestsCanSeeOtherGuests: false`, when the company chooses |
| Changes made outside Big Buck | `events.watch` push channels per calendar. Notifications are a bare signal (no event data), channels must be renewed manually, and Google says they are not 100% reliable, so a periodic incremental sync runs as a backstop |

Sources: [freebusy.query](https://developers.google.com/workspace/calendar/v3/reference/freebusy/query?authuser=8), [events.insert](https://developers.google.com/calendar/v3/reference/events/insert), [push notifications](https://developers.google.com/calendar/v3/push?authuser=0), [rooms and domain resources](https://developers.google.com/workspace/calendar/api/concepts/domain).

**Connection modes**

| Mode | Who | How |
|---|---|---|
| Coordinator OAuth | SMB default | The coordinator (or any recruiter) connects their own Google account. Big Buck reads colleagues' free/busy through it, where Workspace sharing settings allow, and creates events on that person's calendar or on a shared recruiting calendar they own |
| Interviewer OAuth | Optional | Interviewers connect their own calendars, for accounts whose free/busy is not visible to the coordinator |
| No calendar | Default when the owner skips the calendar step | Availability from Big Buck working hours; invites by email; see [no-calendar mode](#no-calendar-mode) |
| Domain-wide delegation | Enterprise | A Workspace admin authorizes Big Buck's service account client ID and scopes once in the Admin console. Big Buck can then read every interviewer's calendar and write events as the organizer calendar, with no per-person setup. Cal.com and Cronofy offer the same model ([Cal.com](https://cal.com/help/enterprise/delegation-credential-google-workspace), [Cronofy](https://docs.cronofy.com/calendar-admins/enterprise-connect-gsuite/which-google-scopes-does-cronofy-utilize/)) |

**Google app verification.** Calendar scopes are *sensitive*: Big Buck must pass Google's verification (brand verification, a justification for each scope, and a demo video), which Google says takes about 3–5 business days. Unlike reading Gmail, calendar scopes do not need the annual CASA security assessment ([Google](https://developers.google.com/identity/protocols/oauth2/production-readiness/sensitive-scope-verification)). Domain-wide installations skip brand verification but still need app verification for sensitive scopes. Start the verification early; scheduling cannot go to production without it.

**The organizer calendar.** Events are owned by a shared "Recruiting interviews" calendar where possible (enterprise), or the coordinator's calendar (SMB). A shared organizer means interviews survive when the coordinator leaves the company.

### Microsoft 365 (WIP)

| Need | Microsoft Graph |
|---|---|
| Busy times and working hours | `getSchedule`: free/busy items, a slot string, and each person's **working hours**; up to 20 people or rooms per request; time range under 62 days |
| Suggested times | `findMeetingTimes` exists but is delegated-only, so Big Buck uses `getSchedule` plus its own engine |
| Access for all interviewers | App-only permission (`Calendars.ReadWrite`) with admin consent, restricted to an interviewer group through Exchange **RBAC for Applications**, which replaces Application Access Policies. The unscoped Entra grant must be removed, or the restriction has no effect; changes take 30 minutes to 2 hours |
| Video | Teams meetings through `isOnlineMeeting` on the event |

Sources: [getSchedule](https://learn.microsoft.com/graph/outlook-get-free-busy-schedule), [RBAC for Applications](https://learn.microsoft.com/graph/auth-limit-mailbox-access).

## The availability engine

The engine turns "this application needs these interviews" into ranked, bookable options.

**Inputs**
- the interviews to schedule (one, or a stage's interviews scheduled together as a panel), with durations and order rules
- interviewer requirements per interview: roles on the hiring team, pools, or named people, and how many ([`job-pipelines.md`](./job-pipelines.md#interviews-inside-stages))
- interviewer profiles: time zone, working hours, maximum interviews per day and per week, buffer before and after, paused dates
- busy periods from the calendars (cached and refreshed by change notifications)
- company holidays per location
- the candidate's constraints: time zone, submitted availability, minimum notice (default 24 hours)
- room needs for in-person interviews (location and capacity)
- the search window (default tomorrow to 14 days out; configurable)

**Steps**
1. Build each interviewer's free time: working hours inside the window, minus busy periods, minus buffers, minus holidays and paused dates.
2. For each interview, list who could run it, dropping anyone at their daily or weekly limit.
3. Find slots on a 15-minute grid where enough eligible interviewers (and a room, if needed) are free.
4. For panels, search for sequences that respect order rules, keep gaps under the configured maximum (default 15 minutes), stay within one day unless multi-day is allowed, and never double-book an interviewer.
5. Rank options: fewest recent interviews for the chosen interviewers (load balancing over the last 7 days), then earliest, then fewest gaps, then interviewer preferences.
6. Return the top options with the reason each interviewer was chosen.

**Booking**
- Suggestions use cached busy data; **the booking itself re-checks live free/busy** for the chosen people and time. If something changed, the next-best option is offered instead of a double booking.
- Each interview becomes one calendar event on the organizer calendar with the interviewers, the candidate (by default) and the room as attendees, and its own Meet link.
- The event description comes from a candidate-safe message template. Interviewer-only material (resume, interview kit, scorecard link) is never in the event; it goes in a separate interviewer briefing and on the interview page in Big Buck ([`candidate-communications.md`](./candidate-communications.md#per-interview-communications)).
- Whether the candidate sees the interviewers' names and email addresses is a company setting (`showInterviewersToCandidate`, default on). When off, Big Buck sets `guestsCanSeeOtherGuests: false`.

## No-calendar mode

Scheduling must keep working when a calendar is missing: an interviewer outside the delegated domain in v1, and the SMB preset later ([`owner-setup.md`](./owner-setup.md)).

- **Availability:** each interviewer's working hours in Big Buck (prefilled 9:00–17:00 on weekdays in the organization's time zone, editable by the interviewer), minus interviews already booked in Big Buck and any time they block in Big Buck.
- **Invites:** Big Buck emails the candidate and the interviewers with a calendar attachment (.ics). Because these files go stale when an interview changes (Greenhouse's problem), every change sends an updated attachment with the same event identifier and a higher sequence number, so most calendar apps update the existing entry instead of adding a second one.
- **Video link:** the interviewer's saved personal meeting link (any provider), or a link the scheduler pastes. Google Meet links are created automatically only when Google Calendar is connected.
- **Labelled honestly:** suggestions say "calendars not checked" so nobody mistakes them for checked availability.

**Mixed teams.** When Google is connected but an interviewer's free/busy is not visible (outside the domain, or blocked by sharing settings), that interviewer is scheduled from their Big Buck working hours, the suggestion is marked "calendar not checked for Sam", and Sam gets a one-click link to connect their calendar. It also appears on the owner's setup checklist.

## Scheduling modes

Each interview in a stage has a scheduling mode ([`job-pipelines.md`](./job-pipelines.md#interviews-inside-stages)):

| Mode | What happens when the application enters the stage |
|---|---|
| `self_schedule` | The candidate gets a booking link (message template `self-schedule-invite`) showing live options for that interview, or for the whole panel if the stage schedules together. Booking re-checks availability |
| `availability_request` | The candidate gets a link to submit their availability. With `autoBook: true`, Big Buck books the best option as soon as they submit; otherwise the coordinator picks from the suggestions |
| `coordinator` | A task for the coordinator with suggestions ready |
| `manual` | Nothing automatic; a coordinator schedules from the interview page |
| `none` | No calendar event: take-home exercises and `external` interviews whose provider sends its own link |

A stage sets `scheduleTogether: true` to schedule its interviews as one panel instead of one by one.

## When things change

| Event | Response |
|---|---|
| An interviewer declines | If the interview uses a pool and `onDecline: replace_from_pool` (default), Big Buck swaps in the best available pool member for the same time and tells the coordinator. Otherwise it creates a coordinator task |
| An event is moved or deleted outside Big Buck | The interview is marked `needs_attention`, and the coordinator is told. Big Buck never silently re-books |
| The candidate reschedules | The single-use reschedule link in the confirmation cancels the event and re-opens self-scheduling |
| The application is rejected or withdrawn | Future interviews are cancelled, with `sendUpdates=all` so everyone's calendar updates |
| An interviewer leaves the company | Their future interviews are flagged for replacement; pools drop them |

## Reminders

Reminder defaults are set at the organization level per audience (candidate, interviewers) and can be overridden per interview in the pipeline template or per job, following Ashby's model. Example default: candidate reminders 24 hours and 1 hour before; interviewer reminder 1 hour before with the briefing. Templates and channels are in [`candidate-communications.md`](./candidate-communications.md#reminders). Slack and SMS are WIP.

## v1 boundaries

| In v1 | Later |
|---|---|
| Google Calendar and Meet, all three connection modes | Microsoft 365 and Teams (WIP), Zoom (WIP) |
| Self-schedule, availability request, coordinator and manual modes | Calendar holds while a candidate decides |
| Single interviews and same-day panels | Multi-day loops |
| Interviewer pools, load limits, buffers, working hours | Automatic shadow and reverse-shadow placement for trainees |
| Automatic replacement on decline | Debrief scheduling |
| Basic room selection by location and capacity | Room preferences, building travel time |

## API

| Action | Endpoint |
|---|---|
| Suggestions (dry run, nothing booked) | `POST /applications/{id}/scheduling/suggestions` with interview keys |
| Book a chosen option | `POST /applications/{id}/scheduling/bookings` |
| Send a self-schedule link | `POST /applications/{id}/scheduling-links` |
| Request availability | `POST /applications/{id}/availability-requests` |
| Candidate pages (public, token) | `GET /public/scheduling/{token}`, `POST /public/scheduling/{token}/book`, `POST /public/availability/{token}` |
| Reschedule or cancel | `POST /interviews/{id}/reschedule`, `POST /interviews/{id}/cancel` |
| Interviewer profiles | `GET|PATCH /users/{id}/interviewer-profile` |
| Pools | `GET|POST /interviewer-pools`, `POST /interviewer-pools/{id}/members` |
| Calendar connections | `GET|POST /calendar-connections`, `POST /calendar-connections/{id}/verify` |

Events: `interview.scheduled`, `interview.rescheduled`, `interview.cancelled`, `interview.completed`, `interview.interviewer_declined`, `interview.interviewer_replaced`, `interview.needs_attention`, `scheduling_link.sent`, `availability.submitted`.

> **Built in M5a and M5b (2026-10-25).** Connections (delegation and personal consent), interviewer profiles, pools, holidays and rooms, the engine, suggestions, booking with the live re-check, reschedule, cancel, scorecards with their stage guard, candidate self-scheduling, availability requests and reschedule links, no-calendar `.ics` invitations, push channels with a backstop sync, decline replacement, and interviewer reminders ([`progress.md`](./progress.md)). The candidate pages are served by the public API until the web app (M9).

## Tables

`calendar_connections`, `calendar_watch_channels`, `interviewer_profiles`, `interviewer_pools`, `interviewer_pool_members`, `scheduling_links`, `availability_requests`, plus calendar columns on `interviews`. The implemented columns are in [`db/structure.sql`](../db/structure.sql).

## Open questions

1. ~~Default search window~~ Decided 2026-10-24: 14 days by default, configurable per organization.
2. ~~Should SMB accounts be nudged toward domain-wide delegation?~~ Decided 2026-10-24: nothing blocks, so no forced setup. Interviewers whose calendars Big Buck can't see are scheduled from their working hours, get a connect link, and appear on the setup checklist ([`owner-setup.md`](./owner-setup.md#the-setup-checklist)).
