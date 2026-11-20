# Big Buck UI — Ledger & Canopy

**Status:** Waves 0–1 merged. Parity wave adds offers/comms/scheduling + careers branding admin.

## Direction

Mist `#EEF2EF` · Canopy `#0F3D32` · Ink `#1A2420` · Birch `#F7FAF8` · Copper `#B85C38` (CTA only).

Remix bets: progressive forms, CSS motion, Frames for timeline.

## Careers hero = org config

| Setting | Default |
|---|---|
| `careers_hero_image_url` | `/careers-canopy.avif` (bundled AVIF + WebP + JPG fallback via `<picture>`) |
| `careers_headline` | `Open roles` |
| `careers_subcopy` | `Build with us.` |

- Public read: `GET /v1/public/careers/:slug`
- Admin write: `PATCH /v1/organizations/:id` + `/settings/careers` UI
- Big Buck seed sets the defaults

## Waves

| Wave | Status |
|---|---|
| 0 Mockups | Approved |
| 1 Shell + command + careers photo config | Done |
| 2 Pipeline board + dossier Frames | Done |
| 3 Offer / comms / scheduling parity | In progress |
