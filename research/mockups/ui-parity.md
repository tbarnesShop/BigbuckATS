# UI parity checklist (Big Buck bar)

Lightweight screen list for the Remix client. The visual bar is the live Big Buck app at <https://bigbuck.tbarnesbuilds.fyi/> (sidebar shell, seven-item nav, shared classes). This repo stays native Remix 3 on Rails. Do not port Big Buck's Next.js code or its permission rules.

The Big Buck git tree was not available from this workspace (the GitHub repo returned 404). Stills were not copied. If you have a checkout, prefer `docs/demo/stills` (or a fresh sign-in on the live app) over the wave-0 JPGs in this folder. Those JPGs are the older Ledger editorial comps, not the sidebar.

Compare class names with Big Buck's stylesheet: `page-head`, `chip` / `chip-ok` / `chip-warn` / `chip-bad` / `chip-info`, `pill`, `tab`, `section-card`, `table`, `queue`, `split` / `side-col` / `main-col`, `btn` / `btn-primary` / `btn-ghost`. Colors stay on `web/app/ui/tokens.ts`. The kit is `web/app/ui/kit.ts`.

## Recruiter surfaces

| Surface | Bar | This repo |
|---|---|---|
| Shell | Brand, 232px sidebar, role lens, sign out, theme, mobile menu, table-width content | Done in the shell PR |
| Today | Action queue plus pipeline health | Pipeline-health card links to analytics. Action queue is later |
| Jobs | Table, then job tabs and board | Index is a table. Board on the job page is unchanged. Tabs later |
| People | Directory, pools, referrals, companies | Directory, pools, referrals in the People fold. Companies jump to Admin `#companies` until they have their own page |
| Interviews | Upcoming interviews and scorecards | Stub hub at `/interviews`. Scorecards stay on the application |
| Offers | Offers by status | Stub hub at `/offers`. Offer detail stays at `/offers/view/:id` |
| Careers | Public page | Existing careers page. Polish is later |
| Settings | Users, templates, branding, mail, admin | Agents, API keys, custom fields, sequences and templates, branding, admin |
| Create | `+ Create` for job, person, pool | `details` menu. Forms live at `/jobs/new`, `/people/new`, `/pools/new` |
| Command palette | Jump anywhere | Later (plan 1.4) |
| Demo landing | Marketing sign-in | Later (plan 1.6). `/` is the in-app home; `/session` is still the demo sign-in |

## How to check

Sign in on the live app and on this client as the same kind of role. Walk Today, Jobs, People (including a pool), Interviews, Offers, Careers, Settings. Parent nav should stay highlighted on folded routes (`/pools` → People, `/requisitions` → Jobs, `/sequences` and `/admin` → Settings, `/analytics` → Today).
