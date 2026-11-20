# UI mechanics fixes

Prepared November 6, 2026 from two hands-on UI passes against the `big-buck-lab-ui` sandbox (Remix UI on `127.0.0.1:44100`, Rails API on `127.0.0.1:3000`): a **candidate journey** (Mina Varga, Senior Product Designer, from applicant review through a submitted offer) and an **admin pass** (every page under Settings and Admin). No code was changed during either pass; this document is the follow-up work list.

**Scope.** Interaction and correctness problems only. Missing features are in [section 6](#6-feature-gaps-not-bugs) so they are recorded without being mistaken for bugs.

## How to read this

- **Evidence** says how each item was established:
  - **Observed**: reproduced in the browser.
  - **Code-read**: confirmed by reading the source, not run.
  - **Unverified**: suspected, not reproduced. These are the places where I could be wrong; check before fixing.
- **Layer**: `FE` = Remix UI (`web/app/...`), `BE` = Rails (`app/...`), `Both`.
- Paths are relative to the repo root. Line numbers are as of this commit and will drift.
- Test with the lab sandboxes (`/session`, Owner persona). They reset hourly, and `DemoPolicy` (`app/services/demo_policy.rb`) blocks several writes there. That is why some items below could not be verified end to end.

## Contents

1. [Silent failures and data integrity](#1-silent-failures-and-data-integrity)
2. [Dead ends and broken affordances](#2-dead-ends-and-broken-affordances)
3. [Friction](#3-friction)
4. [Raw-value leaks and copy noise](#4-cleanup-list-raw-value-leaks-and-copy-noise)
5. [Permission inconsistencies](#5-permission-inconsistencies)
6. [Feature gaps (not bugs)](#6-feature-gaps-not-bugs)
7. [Untested and sandbox limits](#7-untested-and-sandbox-limits)
8. [Suggested order](#8-suggested-order)

---

## 1. Silent failures and data integrity

These appear to succeed but did not do what the screen implied, or they let invalid state in. Fix first.

### 1.1 Webhook signing secret is discarded

- **Layer:** Both. **Evidence:** Observed (database value checked) plus Code-read.
- **What's wrong.** The Settings → Webhooks form asks for "Bring your own secret reference". I entered `sm://admin-test-secret`, saw "added.", and the stored `secret_ref` was a generated `enc:v1:…` value. The supplied secret is thrown away, and no screen shows the generated signing secret, so a receiver can never verify a signature.
- **Where.**
  - `app/models/webhook_endpoint.rb:9` has `before_validation :generate_signing_key, on: :create`. It overwrites `secret_ref` unconditionally on create (`:26`).
  - Form: `web/app/actions/settings/sections.tsx` (~`:248`, `:333`, `:354`) and `web/app/actions/settings/sections-controller.tsx:267-289`.
  - The model already has `rotate_signing_secret!` and `signing_secret`. Nothing in the UI uses them.
- **Why it matters.** Webhook signature verification is the whole security story for receivers. The UI tells users they control the secret and they don't.
- **Approach.**
  1. Decide the model: the server generates the signing secret and the user never supplies one (matches current behavior).
  2. Remove the `secret_ref` input and its copy from the form (`sections.tsx`, `sections-controller.tsx:267-289`, including the `sec://demo` rejection).
  3. After creation, show the signing secret once on the success screen and offer "Rotate secret", which calls `rotate_signing_secret!` and shows the new value once. This needs an endpoint if `app/controllers/v1/webhooks_controller.rb` lacks one. Check for an existing rotate route before adding.
  4. If a user-supplied secret really is wanted, change `generate_signing_key` to run only when `secret_ref` is blank and teach `signing_secret` to resolve `sm://` references. That is a larger change.
- **Unsure.** Whether the API or OpenAPI contract (`openapi/openapi.yaml`) documents `secret_ref` as a supported input. If it does, removing it is a contract change.

### 1.2 Import reports "Import finished." when every row failed

- **Layer:** Both. **Evidence:** Observed plus Code-read.
- **What's wrong.** The import textarea is prefilled with `display_name,email` and a sample row. The importer's default mapping only recognizes the headers `email`, `name`, `phone`, `id`. Running the untouched sample gives 1 error and 0 people created, but the banner says "Import finished." Per-row errors (`missing_required`) are stored but never shown.
- **Where.**
  - Sample: `web/app/actions/settings/sections.tsx:275`.
  - Unconditional banner: `web/app/actions/settings/sections-controller.tsx:241`.
  - Mapping: `app/services/csv_people_importer.rb:21-26` (`DEFAULT_MAPPING`). The web action sends no mapping.
  - Error rows: `csv_people_importer.rb:82-93`. The `ImportRow` rows hold `error_message`.
- **Why it matters.** A first-time user following the page's own example loses all their data and is told it worked.
- **Approach.**
  1. **Quick fix:** make the sample match the importer (`name,email`, or add `display_name` to `DEFAULT_MAPPING`). Preferably do both and accept either header.
  2. In the controller, read the created run's `processed_count`, `error_count` and created count from the `createImport` response. Show "N created, M failed". Use an error style when created is 0 or errors are above 0.
  3. Link the run in the history table to a detail view listing failed rows with `row_number` and `error_message`. This may need `GET /v1/imports/:id/rows`; check `app/controllers/v1/imports_controller.rb`.
  4. Add a header check up front: if no column maps to email, reject before creating a run, with the accepted header names in the message.

### 1.3 Config plan "Applied" gives no usable result

- **Layer:** Both. **Evidence:** Observed.
- **What's wrong.** Applying a config plan prints "Applied plan → applied" and created an "Engineering hiring" pipeline template. Nothing in the UI can assign that template to a job (the New job form has no template field), and the notice doesn't say what changed. Plan creation shows only `Plan 01a1af68… (draft) with N changes`.
- **Where.**
  - Messages: `web/app/actions/admin/controller.tsx:65-75`.
  - Page: `web/app/actions/admin/pages.tsx`.
  - Backend: `app/services/config_planner.rb`, `config_applier.rb`, `config_executors.rb`.
- **Why it matters.** Config-as-code has no feedback loop, and the one thing it creates (a pipeline template) is unreachable.
- **Approach.**
  1. Render the plan's `change_set` as a readable list (create/update/delete, kind and key) before the Apply button, and the applied result after. The data is already in the `createConfigPlan` response.
  2. Replace the truncated id and `plan.status` with that summary.
  3. Pair with the feature gap in [6](#6-feature-gaps-not-bugs): a pipeline-template picker on job create/edit. Without it, config-applied pipelines have no consumer.

### 1.4 Feedback is accepted for interviews that haven't happened

- **Layer:** BE (rule) plus FE (hide the form). **Evidence:** Observed.
- **What's wrong.** A screen booked three days out accepted feedback immediately, and the stage guard then counted it as done, so the candidate could advance.
- **Where.**
  - `app/services/scorecard_submitter.rb` checks only rubric attributes and has no time or status check.
  - `app/services/stage_guards.rb:84-88`: `scorecard_submitted?` checks only that a submitted scorecard exists.
  - The form is shown whenever `canScore`: `web/app/actions/applications/pages.tsx:442`.
- **Why it matters.** The "can't advance without feedback" guard is bypassed by feedback that can't be real.
- **Approach.**
  1. In `ScorecardSubmitter#call`, reject submission when `interview.starts_at` is in the future, with an error like `interview_not_started`. Decide whether the check uses `starts_at` or the interview's `status == "completed"`. Both exist; I'd gate on `starts_at <= Time.current` and leave `status` alone.
  2. **Draft scorecards** (`status: "draft"`) should stay allowed early so interviewers can prepare. Only the transition to `submitted` is gated. The seed has drafts.
  3. In `pages.tsx:442`, don't render the submit form for future interviews; show "Opens when the interview starts (date)".
  4. Add a test in `test/services` for a future interview.
- **Unsure.** Whether any API consumer or MCP tool intentionally submits scorecards early (for example for imports of historical data). Check `mcp/` tool usage and `test/` before enforcing.

### 1.5 Scorecard credited to the wrong interviewer

- **Layer:** Both. **Evidence:** Observed. The root cause is Code-read, but the exact path is not confirmed (see Unsure).
- **What's wrong.** I booked Riley for the screen, but the submitted feedback shows "Big Buck Owner". The scorecard is stored against the signed-in actor, not the scheduled interviewer.
- **Where.**
  - `app/controllers/v1/scorecards_controller.rb:23-28`: user is `scorecard_params[:user_id]` if present, else `Current.actor_id`.
  - `web/app/actions/applications/controller.tsx:232-251` forwards `user_id` only if the form posts one.
  - The form (`pages.tsx:442`) has no `user_id` field, so every scorecard is attributed to whoever clicked. The form is also hidden only when the *signed-in* user already has a card (`card.user_id === signedIn()?.userId`).
- **Why it matters.** Feedback attribution is the audit trail for hiring decisions. It also means "feedback owed" logic (which looks at the assigned interviewers) can't ever clear for the right person.
- **Approach.**
  1. Decide the rule. Recommended: a scorecard can be filed by an assigned interviewer for that interview, or by a user with an explicit "file on behalf" permission (which then requires `user_id` and records both actor and subject).
  2. BE: in `ScorecardsController#create` or `ScorecardSubmitter`, verify `user` is in the interview's interviewer list unless the actor holds the override permission.
  3. FE: in `pages.tsx`, for each interview, render the form only for assigned interviewers. For users with the override, add an "On behalf of" select pre-set to the assigned interviewer and post `user_id`.
  4. Make the "already submitted" check use the interview's assigned interviewers, not the signed-in user.
- **Unsure.** How interview-to-interviewer assignment is stored (`Interview` join/`interviewer_user_ids`). I did not read `app/models/interview*.rb`; confirm before writing the rule. Also confirm that the demo personas map to the intended permission, since the Owner persona being able to file for anyone is likely the reason this looked wrong in the lab.

### 1.6 Interview length ignores the pipeline definition

- **Layer:** FE (probably) / Seed data. **Evidence:** Observed. The cause is Unverified.
- **What's wrong.** Portfolio review is defined as 45 minutes and Craft as 60, but the scheduling form says 30 and every offered slot is 30 minutes.
- **Where.**
  - Default: `web/app/actions/applications/pages.tsx:352-356` uses `bookingDraft?.duration ?? available[0]?.duration_minutes ?? 30`.
  - Server side: `web/app/actions/applications/controller.tsx:183` uses `form.get('duration_minutes') ?? definition.duration_minutes ?? 30`.
  - Slot generation: `app/services/availability_engine.rb:68` takes `interview.fetch(:duration_minutes)`.
- **Why it matters.** Interviewers' calendars get the wrong block, and candidates are told the wrong length.
- **Approach.**
  1. First establish which side is wrong. Inspect the stored pipeline JSON (`PipelineTemplate` stages → `interviews[]`) for the Design pipeline and look for the key the seed writes. The seed content is in `lib/big_buck_demo/content.rb` (the interview `STEPS`). The UI reads `duration_minutes`; if the seed (or the API) uses another key such as `duration`, the UI silently falls back to 30. This may be a **seed bug rather than a UI bug**.
  2. If the data is right, trace why `available[0]?.duration_minutes` is empty. Check the web `PipelineStage` interview type in `web/app/data/` for a missing field in the API serializer.
  3. Whichever way, take the duration from the interview definition for the *selected* `interview_key`, not `available[0]`. Today the default is the first unscheduled interview, even if the user picks another one in the select.
  4. Add a test that a 45-minute definition yields 45-minute slots.
- **Unsure.** Which of the three layers (seed data, API serialization, UI default) is at fault. Step 1 settles it in a minute; do it before changing code.

### 1.7 Sequence enrollment person picker is truncated

- **Layer:** FE. **Evidence:** Observed (100 options, 271 people).
- **What's wrong.** The "enroll person" select is populated from a single `listPeople(session)` call, which returns one page (100). Most people can't be enrolled, with no hint that the list is cut off.
- **Where.** `web/app/actions/sequences/controller.tsx:20`; the select is in `web/app/actions/sequences/pages.tsx`. API: `web/app/data/api.ts:259` (`listPeople`).
- **Approach.** Replace the `<select>` with a search input (query via `listPeople({ q })`, which already supports `q`) or a typeahead, and enroll by id. Don't just raise the limit, because it won't scale. A stopgap is to show "Showing 100 of N" and a search box.

---

## 2. Dead ends and broken affordances

### 2.1 Offer approval has no eligible persona (flow dead-ends)

- **Layer:** Seed/lab config, with possible BE/FE gap. **Evidence:** Observed.
- **What's wrong.** A submitted offer sat at "Step 1 · Morgan Reyes · pending". Morgan (design hiring manager) is not one of the four lab personas, and the page shows Approve only to the exact `approver_user_id` (`web/app/actions/offers/controller.tsx:62-64`). Owner and Admin have no approve or override control. No selectable persona can complete the flow in the lab.
- **Where.**
  - Gating: `web/app/actions/offers/pages.tsx:165-172`.
  - Backend allows overrides: `app/services/offer_approver.rb:21` (`@override ||`).
  - Controller calls `approveOffer(session, id, false)`; the third argument is the override: `offers/controller.tsx:102-103`.
  - Approver choice for new jobs came from my seed (`lib/big_buck_demo/content.rb`, hiring-team and approval-policy rows).
- **Why it matters.** A demo that cannot finish its central workflow, and in production a stuck offer when an approver leaves or is on leave.
- **Approach.**
  1. **Lab/seed (do this regardless):** make the approvers of seeded approval policies lab personas (or add Morgan, Taylor and Casey as selectable personas), so the full offer flow works in the lab.
  2. **Product:** add an "Approve as admin (override)" action shown to a permission such as `offer.approve_override`, which calls `approveOffer(..., true)` and records the override reason. The backend already supports `override`. The FE needs the button and a required reason field.
  3. Show who the pending approver is and a "Remind" or "Reassign approver" affordance. That is a feature, so log it in [6](#6-feature-gaps-not-bugs) if not done now.
- **Unsure.** Which permission should gate override. Check `docs/permissions.md` in `web/docs/` and the offer permission list in `app/models`.

### 2.2 Stage pills look clickable but do nothing

- **Layer:** FE. **Evidence:** Observed (clicked "3. Portfolio review": no effect). The pills are `<span>`s.
- **Where.** `web/app/actions/applications/pages.tsx:120-133` (`<nav class="pills section-pills">` containing `<span class="pill">`). The same class also styles real links elsewhere (`:566-581`).
- **Why it matters.** Users try to use the pipeline strip to navigate or move the candidate. The styling invites it.
- **Approach.** Pick one. **(a)** Make them non-interactive progress markers: use a distinct "step" style (no hover, no pointer cursor, no button look), swap `<nav>` for a `<ol>` with `aria-label`, and keep `aria-current="step"`. **(b)** Make past and current stages link to a stage detail (anchor to `#interview-plan` or the stage history) and leave future stages inert. Option (a) is the cheap, safe default. Check `web/app/ui/kit.ts`/`tokens.ts` for the `.pill` rules, which are shared with real links.

### 2.3 "Move candidate" popover stays open after a blocked move

- **Layer:** FE. **Evidence:** Observed. The cause is Unverified.
- **What's wrong.** After a blocked move (stage guard error), Escape doesn't close the popover and it sits over the red error banner until you click elsewhere. The same error also shows twice (popover and banner).
- **Where.**
  - Behavior: `web/app/ui/public/record-action-menu.tsx`. Escape is handled on the `<details>` `keydown`, so it only fires while focus is *inside* the details.
  - Markup: `web/app/ui/record-action-menu.tsx:8` renders `<details open={initiallyOpen}>`.
  - Actions menu: `web/app/ui/application-actions.tsx`.
- **Likely cause.** After the failed POST the page re-renders with the menu forced open (`initiallyOpen`) and focus on `body`, so the keydown never reaches the `details`. It is also possible that `clientEntry` behavior isn't re-attached after the re-render.
- **Approach.**
  1. Reproduce by moving a candidate that fails a guard (for example the Design pipeline stage with missing scorecards) and pressing Escape.
  2. Attach `keydown` on `document` while the menu is open, not on the `<details>`, so Escape works regardless of focus.
  3. Don't force-open the menu on an error render. Show the error banner and leave the menu closed; keep the banner as the single place for the message.
  4. Move focus to the error banner (`role="alert"`, `tabindex="-1"`) on error render.

### 2.4 Hiring-manager gets HTTP 500 on `/admin`

- **Layer:** FE (error handling), and BE permission consistency. **Evidence:** Observed, and Code-read confirms the cause.
- **What's wrong.** As the Hiring manager persona, `/admin` returns a bare "Internal Server Error".
- **Where.** `web/app/actions/admin/controller.tsx:24-39` (`load`) runs `Promise.all` over five API calls, and `index` (`:40-45`) calls `load(session)` with **no try/catch**. Any 403 from `listWebhooks`, `listCompliancePolicies` and so on rejects the whole page, unlike `action`, which does catch (`:80-88`).
- **Why it matters.** A permission boundary shows as a server crash instead of an explanation.
- **Approach.**
  1. Wrap `load` in `index` and render a styled "You don't have access to Admin" page (reuse whatever pattern `settings-controller.tsx` uses for banners), or redirect to Today.
  2. Better: gate at the route. Check the viewer's permission once and return 403 with a proper page. See also [5](#5-permission-inconsistencies) for the broader pattern.
  3. Use `Promise.allSettled` so a user with partial access sees the sections they can read.
  4. Fix the `action` path too: in the `catch`, `load(session)` is called again and can throw the same 500.
  5. Add a controller test (see `web/app/actions/controller.test.ts` for the pattern).

### 2.5 Archive buttons can never work in the demo

- **Layer:** Lab policy (BE) plus FE. **Evidence:** Observed. The cause is Code-read.
- **What's wrong.** Every template row has an Archive button. In the sandbox, clicking it returns "archive template: This action is blocked in shared demo workspaces to preserve sample records and identity." I also couldn't remove my own test data.
- **Where.** `app/services/demo_policy.rb:3-20` (`BLOCKED_KEYS` includes `archive`, `delete`, `remove`, `reject`, `revoke`, `cancel`, `stop` and so on; it matches on the request's action key and on values in the body). The buttons are in `web/app/actions/settings/sections.tsx` and the settings pages.
- **Why it matters.** Visitors are offered a control that always fails, and the failure text leaks an internal action name ("archive template:").
- **Approach.**
  1. When the viewer's tenant is a registered demo sandbox, render destructive controls disabled with a tooltip or caption ("Disabled in the shared demo") instead of letting the request fail. The session already knows it is a demo sandbox (see `web/app/actions/lab/` and the demo banner).
  2. Rewrite `DemoPolicy::MESSAGE` handling in the FE so errors read "Archiving is turned off in the shared demo" without the `archive template:` prefix. The prefix is an `action: message` format; find where it's composed in `web/app/data/api.ts` error handling.
  3. Keep the BE block as the real enforcement.
  4. Note the side effect: because the match is on words in values as well as keys, ordinary text containing e.g. "reject" in a body can trip it (`demo_policy.rb:17-20`). Review if legitimate edits start failing in the lab.
- **Unsure.** Whether Archive works in a real tenant. I couldn't test it, and the demo block hides any bug there. Test it in a non-demo org before relying on it.

---

## 3. Friction

### 3.1 Scheduling takes three submits per interview, and each reloads to the top

- **Layer:** FE. **Evidence:** Observed.
- **What's wrong.** Open form, find times (`preview_booking`), confirm (`book`). The Design panel has two interviews, so six submits. Every submit is a full page POST and returns scrolled to the top, so the user scrolls back down each time.
- **Where.** `web/app/actions/applications/controller.tsx:140-230` (intents), `web/app/actions/applications/pages.tsx:240-370` (form). The cancel link already carries an `#interview-plan` fragment (`pages.tsx:84`), so anchors are used elsewhere.
- **Approach.**
  1. **Cheap:** redirect or render with the fragment (`#interview-plan` or the specific interview's id) after each intent, and `autofocus` the next control.
  2. Merge "open form" into the page: show the search form inline for each unscheduled interview, with no disclosure step.
  3. Collapse find-times and confirm: show the offered slots directly under the form after the first submit with a single "Book" button, and pre-select the first slot (already so).
  4. **Larger:** progressive enhancement via a Remix client entry (see `web/app/ui/public/` and `web/app/actions/public/entry.ts` for the pattern) to submit without reload. Don't do this before 1 and 2.

### 3.2 No in-flight feedback on submit

- **Layer:** FE. **Evidence:** Observed ("Move candidate" sat for 2–3 seconds looking dead).
- **Approach.** A small shared client behavior (the `clientEntry` pattern in `web/app/ui/public/`) that, on `submit`, disables the submitter and sets `aria-busy` plus a spinner or "Saving…" label. Attach it at the form level so it covers move, schedule, feedback and offer. Server round-trip time itself should be checked too: 2–3 seconds for a stage move is slow. Look at `SubjectTransitions` and the number of API calls the action makes (`applications/controller.tsx` fetches the application, job and so on before moving).

### 3.3 Offer form is a single field

- **Layer:** Both. **Evidence:** Observed.
- **What's wrong.** Creating an offer asks only for base salary. No currency, equity, bonus, start date, template or expiry. The offer can't be edited afterwards, and the candidate page shows "194000 USD". Offer templates exist (seeded: 5) but can't be chosen.
- **Where.** `web/app/actions/offers/pages.tsx`, `web/app/actions/offer/page.tsx`, the form on the candidate page, `app/services/offer_submitter.rb`, `app/models/offer_template*.rb`.
- **Approach.** FE-first: add template select (prefills fields), currency, start date, expiry, equity and bonus text; show a letter preview from the template before submit. The BE already versions offers (`offer.versions`), so "edit" means create a new version while in `draft`. Confirm `OfferSubmitter` accepts these fields.
- **Unsure.** Which fields the offer schema actually supports (`field payload` shape). Read `app/models/offer_version.rb` before designing the form.

### 3.4 Two competing settings navigations

- **Layer:** FE. **Evidence:** Observed.
- **What's wrong.** The sidebar shows only "Workspace" and "Templates" under Settings, while a pill row across the top lists all 12 pages. Two systems, with different contents.
- **Where.** `web/app/data/nav.ts:144-157` (sidebar children, `parent === 'settings'`) and `web/app/ui/settings-nav.tsx` (`SettingsNavigation` using `foldPills('settings', …)`). `nav.ts` also folds `/sequences` and `/admin` under Settings (`:77-79`).
- **Approach.** Pick the pill row as the single settings navigation (it has everything), and remove the sidebar's `Workspace/Templates` sub-items, or make the sidebar the single list and drop the pills. `nav.test.ts` covers this file, so update it. Also include Admin and Sequences in whichever list is kept, since they're reachable only from side routes today.

### 3.5 Duplicated forms: webhooks and companies

- **Layer:** FE. **Evidence:** Observed.
- **What's wrong.** Webhooks can be created in Settings → Webhooks (key, URL, secret) and in Admin → Webhooks (key, URL only). Companies are likewise created on both Companies and Admin. They behave differently, and the Admin version can't take a secret.
- **Where.** `web/app/actions/admin/controller.tsx:57-70`, `admin/pages.tsx`; `settings/sections*.tsx`; `companies/*`.
- **Approach.** Remove the create forms from Admin and link to the owning page. Admin keeps the read-only event and config-plan views. Resolve together with 1.1.

### 3.6 Forms hidden inside collapsed `<details>`

- **Layer:** FE. **Evidence:** Observed. Clicks landed on the wrong elements until the disclosure was opened.
- **Where.** `web/app/actions/requisitions/pages.tsx:20`, `web/app/actions/sequences/pages.tsx:26` (`<details class="workflow-disclosure" open={Boolean(notice)}>`).
- **Approach.** For primary create flows (new requisition, new sequence), show the form open by default or use a dedicated `/…/new` route (jobs, people and pools already do: `routes.ts`). Keep disclosures for secondary options. Also keep the form open on validation errors (currently only `notice` opens it; check `error` too).

### 3.7 Pressing Enter in the question-template form triggers "Remove question 1"

- **Layer:** FE. **Evidence:** Code-read only (HTML implicit submission). **Unverified in the browser. I did not press Enter on a populated form.**
- **Where.** `web/app/actions/jobs/question-editor.tsx:68-77` (Remove buttons, `type="submit"`, `name="intent"`) appear before the Save button in `web/app/actions/settings/question-templates.tsx:110`. Per the HTML spec, Enter in a text field activates the form's **first** submit button in tree order.
- **Approach.** Add a visually hidden default submit button as the first element in the form (`value="save"`), or move Save above the question list and give Remove/Add `type="button"` handlers with form-level `formaction`. The hidden-first-button trick is the least invasive. Verify manually, and apply the same fix to the job posting question editor, which shares `question-editor.tsx`.

### 3.8 Scheduling form: timezones, organizer calendar, interviewer email

- **Layer:** FE. **Evidence:** Observed.
- **What's wrong.** Slots show Eastern time only, with no interviewer or candidate zone and no explanation (Ravi's seeded India hours appear as 12:30–4:00 AM EST). "Organizer calendar" is a free-text field a recruiter shouldn't have to fill. "Interviewer email" is a free-text field that is overwritten from the hiring team anyway (`controller.tsx:176-181`).
- **Approach.** Show each slot in the interviewer's and the viewer's zone ("9:00 AM IST · 11:30 PM EST"). Default the organizer calendar from the signed-in user's connected calendar and hide the field when set. Drop the interviewer email field: the controller already resolves it from the selected hiring-team member.

### 3.9 The booked slot failed once ("That time is no longer available.")

- **Layer:** BE (probable). **Evidence:** Observed once. **Not reproduced.**
- **What's wrong.** A pre-selected slot (Fri Nov 6, 7:00 PM) failed on confirm, and the interviewer select reset to blank. The same slot was offered twice.
- **Approach.** Reproduce first. Suspects: the offer-token validity and expiry ("options expire in 10 minutes"), the availability engine re-checking free/busy at booking time, and the near-boundary slot after the 16–21 UTC business-hours window (the seed's interviews live in that window, so the candidate slot may have fallen outside). Look at `app/services/availability_engine.rb`, `self_schedule.rb` and `interview_hub.rb`. Separately, keep the chosen interviewer after any scheduling error (the draft already exists: `setDraft(bookingDraft)`).

### 3.10 Smaller friction

| Item | Where | Fix |
|---|---|---|
| Only reject path is "Archive application" | `applications/controller.tsx` `intent === 'archive'`, reasons via `applicationArchiveReason` | Rename to "Reject or archive" with reason groups; no model change |
| Notes are one line; four dropdowns per interview | scorecard form, `pages.tsx:442+` | Use a `<textarea>`; allow a quick "all met" shortcut |
| "Approve" tab on Offers reads like an action | `web/app/actions/offers/pages.tsx`, `nav.ts` | Rename to "Pending approval" |
| "Send to email (optional)" doesn't say who | offer send form, `offers/pages.tsx` | Prefill with the candidate's email and label it |
| Submitting New job lands on the list with "Opened Admin Test Job" and no link | `web/app/actions/jobs/controller.tsx` | Redirect to the new job's page |
| Requisition "pending approval" shows "Open for hiring" | `requisitions/pages.tsx` | Hide it until approved (I did not click it; confirm what the BE does) |
| Agents "New agent" Name is prefilled with the last agent clicked | `settings/sections.tsx` agents form | Don't carry `values` into the create form after a different action |
| Activity log is thin ("communication sent" and a date) | `web/app/actions/people/timeline-frame.tsx` | Show subject, recipient, direction |
| Events feed rows are `company.created · Company/01a1af6c` | `admin/pages.tsx` | Show actor, time and a link to the record |
| Mailboxes and Calendar pages are read-only | `settings/sections.tsx` | Feature gap, see [6](#6-feature-gaps-not-bugs) |

---

## 4. Cleanup list: raw-value leaks and copy noise

All FE, low risk, can be batched in one PR. Evidence: Observed unless noted.

**Raw values shown to users**

- Offer and status enums in lowercase snake case: `pending_approval`, `approved` (`web/app/actions/offers/pages.tsx:203` prints `offer.status`). Add a shared `statusLabel()` in `web/app/data/`.
- "12500" beside "$194,000"; "194000 USD" on the candidate page. Format with `Intl.NumberFormat` using the currency.
- Banner says "feedback for **portfolio**" while the popover says "Portfolio review". Use `interviewLabel()` (`web/app/data/application-workflow.ts:26`) in the banner message in `applications/controller.tsx`.
- "Application responses: Submitted through posting 01a1af57-de4f-…" (raw posting UUID). Show the posting title with a link.
- Application form field labels are raw keys (`display_name`, …). Map the `STANDARD` list in `settings/sections.tsx:17` to human labels.
- Calendar ids shown as `primary:owner@…`; show the owner's email or name.
- `bb_live_…` key prefixes and raw scopes in the Agents list while the create form uses friendly names. Use the same labels in both.
- Raw ISO timestamps in the import history; truncated plan ids (`01a1af68…`) in Admin; offer expiry in Eastern time without a zone label.
- Webhook list shows no active/inactive state.
- API keys pile up: six "Lab MCP / Lab tools" keys, all never used, accumulated in the Owner's list as I switched personas. Probably the persona switch mints a key every time; look in `web/app/actions/session/` and `lab/` to reuse or revoke the previous key.
- Error text leaks internal action names: "update org careers:", "issue agent token:", "create token:" (composed in `web/app/data/api.ts` error handling).

**Noise to cut**

- Today page (`web/app/actions/today/page.tsx`): "Your schedule · remaining today", "Visible applicants · awaiting initial review", "Visible offers · displayed queue", "Your scorecards · displayed tasks", and the "0 shown" / "50 shown" badges.
- "initial review" repeated on every row of the applicant queue.
- Stage history open by default and saying "No stage changes yet." on a new applicant.
- The move error rendered twice (popover and banner); see 2.3.
- "Offer sent" screen: a lone "Previous · Ingrid Moreau" pill with no Next.
- Scheduling form: "In the demo, calendar invitations stay local".
- Settings landing and page subtitles that repeat the link title.
- Admin subtitle "…over the same REST API."; "No policies configured (consent gates are open)."; prefilled raw-JSON example in Config as code; "No config plans yet."
- Careers branding: "Customize the careers page for Big Buck (big-buck-lab-ui)." exposes the sandbox slug.
- Calendar: "Connect an authorized calendar to coordinate interviews" above a list with no way to do it.
- Plan notice "Applied plan → applied" (tautology; fixed by 1.3).

---

## 5. Permission inconsistencies

These are not one bug but one missing pattern: **there is no common way for a page to say "you can't use this"**. Pages do one of four things: crash (500), render a banner above a live form, render empty fields with a Save button, or hide data silently. A single approach should cover all of them.

| Page / persona | What happens | Where |
|---|---|---|
| `/admin`, Hiring manager | HTTP 500 | `admin/controller.tsx:40-45`, see 2.4 |
| `/settings/import`, Hiring manager | Banner "imports: This action needs the import.manage permission." above a fully live CSV form and Import button | `settings/sections-controller.tsx` |
| `/settings/careers`, Hiring manager | Form renders with **blank** fields and a Save button | `careers/settings-controller.tsx`, `settings-page.tsx` |
| `/settings/keys`, Hiring manager | Lists the org's keys with Revoke buttons and a create form with scope checkboxes | `settings/sections*.tsx` |
| Webhooks, Recruiter | Shows "No webhooks yet" although three exist (read forbidden is treated as empty) | `settings/sections-controller.tsx`, `admin/controller.tsx` |
| Offer compensation, Admin | "No field payload on the current version."; compensation hidden, and no approve or override control | `offers/pages.tsx:205`, `offers/controller.tsx` |

- **Layer:** Both. **Evidence:** Observed for all rows.
- **Approach.**
  1. Introduce one FE helper, for example `requirePermission(context, 'import.manage')` in `web/app/data/session.ts` (which already exposes `signedIn()?.permissions`, used throughout `applications/pages.tsx`). On failure it renders a shared "No access" page. Use it in every controller above. Nav entries are already filtered by permission (`nav.ts`, e.g. `settings.manage`); route handlers must match.
  2. Treat an API 403 as "no access", not as an empty list. In `web/app/data/api.ts` surface a typed `ForbiddenError` so controllers can't mistake it for empty data.
  3. Hide mutating forms when the viewer lacks the write permission (read-only view with a note).
  4. Decide Admin's offer-compensation visibility deliberately. If compensation should be visible to Admin, fix the permission; if not, say "Compensation is restricted" instead of "No field payload", which reads like missing data.
- **Unsure.** Whether Recruiter should have `webhook.read`; the seeded roles in `lib/big_buck_demo/content.rb` (`ROLES`) were chosen by me and may be the cause. Check against `web/docs/permissions.md` before treating it as a bug.

---

## 6. Feature gaps (not bugs)

Recorded so they aren't mistaken for defects. Each has an API or model behind it unless noted; these need product decisions and design, not a mechanics fix.

| Gap | What the UI shows today | Note |
|---|---|---|
| **Users, roles and permissions** | `/settings/users` and `/settings/roles` return a bare, unstyled 404 | Backend roles and scopes exist. The 404 page itself *is* a mechanics bug: use the app's not-found page |
| **Pipeline and stage editing** | "Edit pipeline" only scrolls to a read-only table, and the editor note points at raw JSON in Admin | The label is misleading; rename it even if the editor ships later |
| **Pipeline-template picker on a job** | New job and edit have no template field | Blocks 1.3's output from being used |
| **Scorecard rubric and interview-plan editing** | None | |
| **Hiring-team editing on a job** | "No hiring team on this job yet." with no control | |
| **Link job to requisition** | "No requisition linked." with no control | |
| **Sequence step authoring** | Create form is key, name and template flag only | |
| **Job description** | None anywhere | |
| **Resume/CV upload on the public apply form** | Name, email, phone, screening and posting questions only | `web/app/actions/careers/pages.tsx` has no file input. Needs a public upload endpoint with scanning (documents already have `scan_status`) |
| **Edit "Life at Big Buck" careers blocks** | Read-only | |
| **Interviewer hours, rooms, holidays and panels** | None | |
| **Mailbox connect, disconnect, caps** | Read-only list | |
| **Message template body view or edit, type, locale** | List and create only | A German template exists in the seed but can't be created from the UI |
| **Person custom fields** | New person is name and email only; no inputs for custom fields on person details | |
| **Webhook event-type selection** | All-events only | |
| **Offer editing, letter preview, equity, start date** | Single salary field | See 3.3 |
| **Offer approver reassign, remind** | None | See 2.1 |

---

## 7. Untested and sandbox limits

So no one assumes more was verified than was:

- **Sandbox blocks** archive, revoke, delete, identity and org-settings writes, and roles/permissions (`DemoPolicy`). I saw the forms and error messages but **could not confirm that these writes persist**: archive, revoke, agent and key issue, org settings and the careers branding save.
- **Not driven:** Calendar "Connect calendar" (takes a secret reference), Pools create, Companies edit, sequence and compliance-policy edits (there are no policies to edit), self-scheduling by a candidate, reject or archive-application, the sourcing-pool path.
- **Not reachable:** the `big-buck` org's full seed through the UI (demo sign-in is limited to the `big-buck-lab-*` tenants).
- **Worked end to end** (saved, reloaded, verified): template create; question-template edit (v1→v2); application-form required fields (appear on the public form); webhook add; custom-field add; import with correct headers; job publish (appears on the careers page) and openings; posting question template attach; requisition create; company add; sequence create and enroll; config plan create and apply; stage move, scheduling and feedback; offer create and submit; offer send (on an already-approved offer).
- **Mobile and accessibility** were not part of either pass.
- The test data from both passes lives in the sandbox until its hourly reset (admin test template, webhook, custom field, job, requisition, sequence and so on).

## 8. Suggested order

1. **One PR, small and independent:** 1.2 (sample CSV + honest result banner), 2.4 (`/admin` try/catch), 3.7 (hidden default submit button), 2.2 (pill styling). These need no decisions.
2. **Needs a short decision, then small:** 1.1 (webhook secret model), 1.4 (future-dated feedback), 1.5 (feedback attribution rule), 2.1 (approver override + lab personas).
3. **Investigate before coding:** 1.6 (which layer drops the duration), 2.3 (popover cause), 3.9 (slot failure).
4. **Then the cross-cutting work:** the permission helper in [5](#5-permission-inconsistencies), the shared submit-busy behavior (3.2), the scheduling flow (3.1), the settings navigation (3.4).
5. **Cleanup PR** from [4](#4-cleanup-list-raw-value-leaks-and-copy-noise), which can run in parallel with everything.
