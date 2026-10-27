# Milestone 1: a production-ready site with one game (the game guesser)

Status: draft 1, 2026-10-27. Plan only; nothing in it is built yet unless it says "done". Effort numbers are estimates for one developer working with Claude, in working days. `SPEC.md` has the product decisions (cited as "decision N"), `ARCHITECTURE.md` the production practice, `CONTRACTS.md` the boundary between the two app repos.

## 1. Definition of done

Milestone 1 is done when all of this is true on the real domain:

1. The site is public over HTTPS. A visitor opens it and sees today's game guesser puzzle on the main screen, with no account (decisions 3 and 5).
2. The nav lists the games (one entry for now) and the site is called "Daily Game Challenge" everywhere (decisions 1, 4).
3. A guest can play today's puzzle and past puzzles, see the end screen, stats and a share text; progress survives a reload (decisions 7, 16, 20).
4. Login is optional. An account keeps progress, stats and streak across devices, and a guest's local progress merges in on first login (decisions 3, 15, 51).
5. The site works in English and Russian for the interface; the game itself is English (decisions 27, 32).
6. Answers never reach the browser before the game ends; images of later steps are only served once earned (SPEC section 6).
7. At least 30 reviewed puzzles are scheduled ahead, and a script adds more.
8. Production practice from `ARCHITECTURE.md` section 15 is in place: error tracking, uptime alert, tomorrow's-puzzle alert, backups with one tested restore, rate limits, CSRF check, real email, account deletion and export, privacy policy and legal footer, load test of the 00:00 UTC spike, accessibility and mobile smoke tests.

Out of scope for Milestone 1: the other games, leaderboards, community stats, the language saved on the account, the React Native app, monetization, analytics.

## 2. What exists today

- Backend: auth (register, login, logout, me, password reset and update), `/v1` routes, error contract, health endpoints, OpenAPI snapshot, CI, uv lockfile. No game code.
- Frontend: auth pages, English and Russian interface, generated API client, error screens, CI and tests. The app is still "MyList": a sidebar with Home and Lists, a login-required layout, a profile page.
- Platform: specs and contracts in a local git repo (no GitHub remote yet).

## 3. Decisions needed from you (these block tasks)

| # | Decision | Recommended | Blocks |
|---|---|---|---|
| D1 | Layout: a top nav bar with the games (SPEC says "nav bar") or the current sidebar | Top bar: game tabs scroll sideways on phones, login or profile on the right | M1-02, M1-06 |
| D2 | Game data and screenshots: IGDB (needs a free Twitch developer account made by you) | IGDB for metadata and screenshots, free tier is non-commercial, attribution shown; check its terms at signup | M1-20 to M1-23 |
| D3 | Hosting and the domain | Decided later by you; the plan assumes one VPS with Docker Compose and Caddy | M1-40 to M1-47 |
| D4 | Email provider for password reset (needs the domain first) | Resend free tier or Amazon SES | M1-33 |
| D5 | Who reviews the puzzles (the owner approves the first 30; SPEC section 7 asks for a human review for this game) | You, in a review queue of 10 minutes a day | M1-24 |
| D6 | Who checks the Russian texts and the legal pages | A Russian speaker you trust; a lawyer for the legal text | M1-50, M1-51 |

## 4. Phases and tasks

Repos: BE = `my-list-be`, FE = `my-list-fe`, PL = platform repo. "Done when" is the check that closes the task.

### Phase 0: the site we have becomes Daily Game Challenge (about 3 days)

| ID | Task | Repo | Est. | Depends | Done when |
|---|---|---|---|---|---|
| M1-01 | Rename in the UI: product name in `index.html`, `package.json` name, catalogues (`app.name`, profile text), sidebar or bar title, favicon text; remove the "MyList" wording | FE | 0.3 | none | no "MyList" left in the app; tests pass |
| M1-02 | Optional login: the app layout no longer requires a session. A guest sees the shell; login and sign-up are buttons in the nav; profile and password change stay behind login | FE | 0.7 | D1 | a signed-out visitor reaches `/` and the nav; `/profile` redirects to login |
| M1-03 | New nav: game entries (one now) from a `GET /v1/games` list, archive link, language switcher, theme toggle, login or profile menu; responsive for phone, tablet, laptop | FE (+ BE for M1-10) | 1.0 | D1, M1-10 | works at 360, 768 and 1280 px; keyboard reachable |
| M1-04 | Remove the Lists feature: routes, nav item, quick-action cards, catalogue keys | FE | 0.3 | none | no `/lists` route; build passes |
| M1-05 | MyList leftovers in docs and skills: both `CLAUDE.md` files, the two `dynamic-category-schema` skills, READMEs (short real ones), the `item-list` names in `.env.example` and compose | BE, FE, PL | 0.5 | none | no field_schema or item-list text; READMEs say how to run |
| M1-06 | Home page becomes the game screen: `/` shows today's puzzle of the default game; `/games/{slug}` and `/games/{slug}/{date}` are the same screen with another puzzle | FE | 0.5 | M1-10, M1-30 | route structure agreed in the shell spec |
| M1-07 | Site shell spec (`SPEC.md` part (a), (b)): nav, routing, game module contract, in a short feature spec | PL | 0.5 | D1 | spec written and agreed |

### Phase 1: backend core for games (about 5 days)

| ID | Task | Repo | Est. | Depends | Done when |
|---|---|---|---|---|---|
| M1-10 | Game registry and puzzle model: tables `game`, `puzzle (game, variant, date)` with a status flow (draft, in_review, approved, scheduled), Alembic migration, unique key; `GET /v1/games`, `GET /v1/games/{slug}/puzzles/today` returning only step 1 | BE | 1.0 | M1-07 | migration passes the CI migrations job; tests |
| M1-11 | Title table and autocomplete: `title` (name, franchise, year) with Postgres trigram search, `GET /v1/games/{slug}/titles?q=` returning up to 200 fuzzy matches (title and franchise only, no answers) | BE | 1.0 | M1-10 | typo "zlda" finds Zelda; 200-result cap |
| M1-12 | Guess endpoint: `POST /v1/games/{slug}/puzzles/{date}/guesses` checks a guess on the server, returns correct or not, the franchise flag, the next step's clue; a skip is a guess; the answer is returned only when the game ends | BE | 1.5 | M1-10, M1-11 | tests for win, lose, skip, franchise match; answer absent before the end |
| M1-13 | Guest and account progress: a guest sends earlier guesses with each request (stateless, decision 16); an account's progress is stored (`progress` table with a unique key) and authoritative | BE | 1.0 | M1-12 | same result either way; forged history cannot change an account |
| M1-14 | Stats and streak: played, wins, current and max streak with the 3-day grace and "finishing counts" rules (decisions 15, 51), guess distribution; archive plays count to stats only (decision 14) | BE | 1.0 | M1-13 | tests for streak grace and archive rules |
| M1-15 | Guest merge: one idempotent endpoint takes local results and merges them into the account | BE | 0.5 | M1-13 | replaying the request changes nothing |
| M1-16 | Archive endpoints: list past puzzles with the player's state per puzzle (paged), play a past puzzle | BE | 0.5 | M1-13 | past days only, never today or future |
| M1-17 | Clock endpoint or header for the countdown to 00:00 UTC | BE | 0.1 | none | the client can show hh:mm:ss |
| M1-18 | Clue images: storage interface (local folder in dev, S3-compatible in production), short-lived signed URLs issued only for earned steps | BE | 1.0 | M1-12 | step 3 image URL is not returned at step 1 |

### Phase 2: the game in the browser (about 5 days)

| ID | Task | Repo | Est. | Depends | Done when |
|---|---|---|---|---|---|
| M1-30 | Game module registry and the clue-ladder module: step tabs, image, hint overlay, wrong-guess list, skip, "N guesses left" | FE | 1.5 | M1-06, M1-12 | plays a full game against the real backend |
| M1-31 | Title search input with autocomplete and a "Loading" state, pick from the list then submit | FE | 0.7 | M1-11 | keyboard and touch usable; 200-result list |
| M1-32 | Guest progress in browser storage (per puzzle) and sending earlier guesses; survives reload and midnight rollover (date checked on load and on submit) | FE | 0.8 | M1-13 | reload keeps the game; day change shows a message |
| M1-33 | End screen: win or lose, the answer, the guess list, a share button (spoiler-free text), "play previous days" | FE | 0.7 | M1-30 | share text copies without spoilers |
| M1-34 | Stats dialog: played, win %, streak, guess distribution; guest stats from the browser, account stats from the server | FE | 0.5 | M1-14 | numbers match the backend |
| M1-35 | Archive screen: list of past days with state boxes, open one on the same screen | FE | 0.8 | M1-16 | opens `/games/{slug}/{date}` |
| M1-36 | Sign-up nudge after a first win, and merge of guest progress on login or register | FE | 0.5 | M1-15 | no progress lost on sign-up |
| M1-37 | Countdown to the next puzzle | FE | 0.2 | M1-17 | shows time to 00:00 UTC |

### Phase 3: content for the game (about 4 days, partly parallel with Phase 2)

| ID | Task | Repo | Est. | Depends | Done when |
|---|---|---|---|---|---|
| M1-20 | IGDB access and a client in the puzzle script (title list, franchise, year, platform, genre, developer, critic score, screenshots); terms checked at signup | BE (scripts) | 1.0 | D2 | script lists 5 games with all fields |
| M1-21 | Title list import: the searchable list of games (thousands) with clean franchise names, near-duplicates removed | BE (scripts) | 0.7 | M1-20, M1-11 | autocomplete returns clean titles |
| M1-22 | Puzzle builder: filters (popular enough, enough screenshots, not a recent answer or series), image processing offline (pixelated first crop, six clues, WebP sizes), content-addressed private storage, secret seed salt kept outside the repo (public repo) | BE (scripts) | 1.5 | M1-20, M1-18 | `--dry-run` and idempotent re-run; images in storage |
| M1-23 | Source credit per puzzle (image source URL kept) and the credits page after a game ends (SPEC 3.7) | BE, FE | 0.5 | M1-22 | credits visible after the game |
| M1-24 | Review queue: a CLI or a tiny local page to approve or reject drafts; schedule 30 or more puzzles | BE (scripts) | 0.6 | M1-22, D5 | 30 approved, scheduled puzzles |
| M1-25 | Alert when the scheduled buffer drops under 7 days and when tomorrow's puzzle is missing | BE | 0.3 | M1-24 | the check runs and exits non-zero |

### Phase 4: production hardening (about 5 days)

| ID | Task | Repo | Est. | Depends | Done when |
|---|---|---|---|---|---|
| M1-40 | Dockerfiles for both apps (multi-stage, non-root), production Compose, Caddy (same origin, security headers, CSP with `wasm-unsafe-eval` only if needed, `index.html` no-cache, hashed assets immutable, `/healthz` and `/readyz` hidden) | PL, BE, FE | 1.5 | none | the whole site runs from Compose on this laptop |
| M1-41 | CSRF Origin check and a custom header on unsafe methods | BE, FE | 0.7 | none | cross-origin POST is refused |
| M1-42 | Rate limits (login, register, forgot-password, guess endpoints) with `limits` and Redis; `429` with `Retry-After` | BE | 0.8 | none | tests; limit values in settings |
| M1-43 | Real email sending through a queue (arq behind a thin interface), SPF, DKIM and DMARC on the sending subdomain | BE | 1.0 | D3, D4 | a reset email arrives in Gmail and a Russian mailbox |
| M1-44 | Account deletion and data export (`DELETE /v1/me`, `GET /v1/me/export`), audit-log table | BE, FE | 1.0 | none | deletion removes the account and sessions |
| M1-45 | Sentry free plan in both apps, source maps from CI, request id on the error screen; no personal data | BE, FE | 0.5 | none | a deliberate test error shows up |
| M1-46 | Legal footer and pages in English and Russian: rights notice, contact email, privacy policy (what is stored, browser storage), terms; takedown contact | FE, PL | 1.0 | D6 | pages live and linked from the footer |
| M1-47 | Static share image and meta tags in `index.html` | FE | 0.2 | none | link preview shows a card |

### Phase 5: launch readiness (about 3 days)

| ID | Task | Repo | Est. | Depends | Done when |
|---|---|---|---|---|---|
| M1-50 | Playwright smoke tests (guest plays a game, register and login, reset password, language switch, archive) on desktop, phone and tablet, with axe | FE, PL | 1.0 | Phase 2 | green in CI |
| M1-51 | k6 test of the 00:00 UTC spike at about 5 times the expected peak; fix what it finds | PL | 0.7 | M1-40 | p95 under 300 ms on guess submit |
| M1-52 | Staging and production deploy workflows (GitHub Actions over SSH with Compose, required approval, rehearsed rollback), backups (nightly encrypted dump, copy off-site, one tested restore), uptime monitor and the two alerts, runbooks | PL | 1.5 | D3 | rollback rehearsed; restore tested |
| M1-53 | Dependabot with grouping, secret scan in CI, `npm audit` findings looked at | BE, FE | 0.3 | none | PRs arrive; audit triaged |
| M1-54 | Launch checklist run (ARCHITECTURE.md section 4) and a Russian-reachability check from a Russian vantage point | PL | 0.5 | all | checklist signed off |

## 5. Order and the critical path

1. **Start now (no blockers):** Phase 0 (M1-01, M1-04, M1-05, M1-07), then M1-10 to M1-18 in the backend.
2. **In parallel:** M1-20 to M1-25 need D2 (IGDB account) and D5. Ask for the Twitch developer credentials early, because content is the slowest part.
3. **Then** the frontend game (Phase 2), then hardening and launch readiness.
4. The hosting decision D3 can wait until Phase 4; everything before it runs on this laptop.

Rough total, if tasks run one after another: about 25 working days (Phase 0: 3, Phase 1: 5, Phase 2: 5, Phase 3: 4, Phase 4: 5, Phase 5: 3). Phases 2 and 3 can overlap, so about 22 days is realistic. These are estimates.

## 6. Risks specific to Milestone 1

- **Content supply and rights (highest).** Screenshots belong to others (SPEC risk 1). Mitigations: no monetization, a visible takedown contact, source credits, and a human review before each puzzle goes live.
- **IGDB terms.** The free tier is non-commercial per what the research found; check the terms when the account is created. If they do not fit, the fallback is a hand-built list with screenshots you provide.
- **Answer leaks.** The repos are public. The seed salt and any puzzle data stay out of Git.
- **The midnight spike.** Mitigated by serving the shell from Caddy and pre-warming (M1-40, M1-51).
- **Russian reachability.** Outside our control; test before launch (M1-54).
- **One person.** The plan has no slack for illness or surprises; add 20% to any date you promise.

## 7. How we work through it

Each task is one pull request in the repo it belongs to (a boundary task is two PRs, merged backend first), with CI green before merge. After every few tasks I update `ARCHITECTURE.md` progress and this file's status column. The first feature specs (M1-07) are written before the tasks that depend on them.
