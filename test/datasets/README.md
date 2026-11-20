# Test datasets

## Big Buck

Canonical org used for permission and UI end-to-end coverage.

| Artifact | Path |
|---|---|
| Dataset builder | `lib/big_buck_dataset.rb` |
| Rake tasks | `lib/tasks/big_buck.rake` (`big_buck:seed`, `big_buck:export_fixture`) |
| DB seed entrypoint | `db/seeds.rb` |
| Backend e2e tests | `test/integration/big_buck_dataset_e2e_test.rb` |
| Web fixture (stable IDs) | `web/test/fixtures/bigbuck.json` |
| Mock Rails API for UI | `web/test/mock-rails-api.ts` |
| Browser UI e2e | `web/app/bigbuck-ui.test.e2e.ts` |

### Roster

- **100 people** — 25 named anchors (Ava…Zachary) plus 75 generated profiles (`c026`…`c100`)
- Spread across lifecycle (`prospect` / `candidate` / `employee` / `alumni`), visibility (`public` / `restricted` / `confidential` / `private`), departments, locations, job pipeline stages (`applied` / `onsite` / `offer`), and sourcing-pool stages
- Each person is seeded with contact points (email/phone/linkedin), company affiliation, resume document, custom fields, location/department tags, consent + notice receipt, timeline activity, and usually an application or pool membership
- **Careers openings.** Platform Engineer and Account Executive have published postings with `both` visibility, so they appear on public and internal careers. Internal careers requires an active member sign-in.
- **Interview loop.** Every application at `onsite` or `offer` gets a completed loop with submitted scorecards and real notes (not placeholders). Engineering: recruiter screen, coding, system design, onsite. Sales: recruiter screen, discovery, case study, onsite. Each step uses a scorecard rubric. Ben Ortiz's offer stays `draft` so the UI fixture can open that offer.
- **Offers.** Applications with an offer cover every status (`draft`, `pending_approval`, `changes_requested`, `approved`, `sent`, `accepted`, `declined`, `expired`, `rescinded`). Farah Khan's offer is waiting on the hiring manager. Priya Shah's offer has been sent.

### Roles / users

- **owner** — org owner
- **admin** — `person.read` + `person.read_restricted` (sees all 100, including restricted)
- **recruiter** — `person.read` only (public people); also on both interviewer pools
- **hiring_manager** — Engineering-scoped HM (Harper)
- **sales_hm** — Sales-scoped HM (Sasha)
- **interviewer_eng** / **interviewer_sales** — panel interviewers (Ivy / Owen)
- **non_user** — user with no membership (empty people list)

### User / scheduling seed

Each staff user (except outsider) gets an `InterviewerProfile` (timezone, working hours, limits) and a user `CalendarConnection`, plus a domain calendar. Interviewer pools: `eng-panel`, `sales-panel`. Hiring teams on both jobs with HM / recruiter / interviewer roles. Also rooms, holidays, one interviewer block, and a default offer approval step routed to `role:hiring-manager`.

Exact people-list counts live in `expectations` inside the web fixture / `BigBuckDataset.expectations`.

### Local seed

```bash
bin/rails db:seed
# or
bin/rails big_buck:seed

# Backfill existing published demo jobs without resetting people or applications:
bin/rails big_buck:seed_internal_openings
# BIGBUCK_ORG_SLUG selects another existing demo tenant.

# Refresh the committed UI fixture (stable IDs):
bin/rails big_buck:export_fixture
```
