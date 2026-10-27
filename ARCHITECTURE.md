# Architecture and operations: Daily Game Challenge

Status: draft 2, from a research report of 2026-10-27; the owner's decisions of the same day are recorded in section 3. This is the technical companion to `SPEC.md` (product and games) and `CONTRACTS.md` (the seam between the two repos). Everything here is **[proposed]** until the owner decides it; decisions are copied into `SPEC.md` section 2 as numbered decisions.

How to read the evidence: repo findings were checked in the code by the research agent, and I re-ran four of them myself (marked "checked"). Library versions, licenses and prices are as the agent read them on 2026-10-27. "(estimate)" is a design guess or arithmetic, "(unverified)" is something the agent could not confirm. This is general information, not legal advice.

## 1. Where the two repos are today

Both repos are early scaffolds (auth only). Both are **public** on GitHub (checked), which has two consequences: GitHub environments, rulesets, secret scanning and Actions minutes are free, and **puzzle answers and unreleased puzzle data must never be committed** (section 9).

| Area | Backend `my-list-be` | Frontend `my-list-fe` |
|---|---|---|
| Stack | FastAPI 0.141.1, Starlette 1.6.0, SQLAlchemy 2.0.52, bcrypt 5.0.0, redis 8.1.0 | React 19.2.8, Vite ^8.2.2, TypeScript ~6.0.2, TanStack Router and Query, axios, Tailwind 4 |
| Latest versions today | FastAPI 0.162.0, Starlette 1.10.0, SQLAlchemy 2.1.6 | Vite 8.3.5, TypeScript 7.0.2 |
| CI, Dockerfile, pre-commit | none | none |
| Lockfile | `requirements.txt` pins, no hashes | `package-lock.json` |
| Tests | 9 tests (password flows); none for register, login, logout, `/auth/me`; the schema is built with `create_all`, so migrations are never tested | no test runner |
| Lint and format | ruff: 5 errors, 2 files unformatted | ESLint: 0 errors, 14 warnings; prettier fails on 10 vendored shadcn files |
| README | empty | the Vite template |
| API types | n/a | hand-written (`src/features/auth/types.ts`), although `CONTRACTS.md` says Orval generates them |

`SPEC.md`, `CONTRACTS.md` and the parent `CLAUDE.md` sit in a folder that is **not a git repo**, so they are not versioned.

### Defects to fix now (before any deploy)

1. **Passwords over 72 bytes cause a 500.** bcrypt 5.0.0 raises `ValueError` above 72 bytes, and the schema allows 128 characters. Checked: 73 ASCII bytes and 37 Cyrillic letters (74 bytes) both fail. This hits Russian-speaking users first.
2. **Reset links are logged.** `app/core/email.py` logs the email address and the live reset link (checked). Outside local this puts account-takeover tokens and personal data into logs.
3. **Redis has no persistence setting.** `docker-compose.yml` mounts `/data` but does not enable append-only mode (checked), so a crash loses recent sessions.
4. **No health endpoints and no shutdown handling.** `/health` and `/healthz` return 404 (checked), and nothing closes the database engine or Redis client on shutdown.
5. **Errors are English text.** The backend returns `{"detail": "<English>"}` and FastAPI's default 422 array, which echoes the submitted `input` (including passwords). The frontend shows `detail` as is, which contradicts the English and Russian requirement (SPEC 3.8). There is no handler for unhandled exceptions and no request id.
6. **Unknown email returns instantly on login**, which leaks whether an account exists through response time.
7. **Test cleanup wipes the dev sessions.** The `clean_redis` fixture deletes `session:*` keys on the same Redis database the dev server uses.
8. **Open configuration.** CORS allows all methods and headers with credentials, `/docs` is public, there are no security headers, `ENVIRONMENT` is a free string, and `SECRET_KEY` is required but never used.

## 2. Target shape (proposed)

One small VPS (Hetzner-class, Helsinki or Falkenstein) running Docker Compose; no Kubernetes (two services and two data stores do not need it).

```
Browser
  |  https (Caddy: TLS, security headers, CSP)
  v
Caddy  --/-->        static SPA files (hashed assets: immutable; index.html: no-cache)
       --/api/*-->   FastAPI (uvicorn, 2 workers; Caddy strips /api; routes under /v1)
                       |-- Postgres 16 (not published)
                       |-- Redis (append-only, noeviction; sessions, rate limits, caches)
                       |-- worker (background jobs; replay verifier later, in its own container)
                       '-- S3-compatible object storage (private bucket, short-lived signed URLs)
```

- **Same origin.** The SPA and the API share one origin in production, as the Vite dev proxy already does. That removes CORS from production, keeps the host-scoped session cookie simple, and lets the frontend build once and be promoted (no per-environment URL in the bundle).
- **Environments.** local (Compose for Postgres, Redis, MinIO; uvicorn `--reload`; Vite dev server), ci (ephemeral), staging (the same images and compose file as production with its own domain, database, Redis and bucket; it can start as a second compose project on the same VPS), production.
- **Cost** (estimate, unverified): about 12 to 25 euros a month for the VPS, object storage and backups together. Hetzner's docs page lists the CX23 at 5.49 euros a month; Hetzner Object Storage lists 6.49 euros a month including 1 TB.

## 3. Decisions for the owner

Recommended option first. These are asked in batches and recorded in `SPEC.md` section 2.

| # | Decision | Recommended | Main alternative |
|---|---|---|---|
| 1 | Hosting | One Hetzner VPS with Compose and Caddy | Railway or Fly.io (more cost, less ops) |
| 2 | Object storage and CDN | Hetzner Object Storage, no CDN at first | Cloudflare R2 (cheap, but see Russia reachability, section 11) or Bunny |
| 3 | Postgres | Self-hosted on the VPS with nightly encrypted dumps, WAL archiving later | Neon or Supabase (more cost, built-in point-in-time recovery) |
| 4 | Error tracking | Sentry free cloud plan, or self-hosted Bugsink or GlitchTip for privacy | Sentry paid |
| 5 | Branching | Trunk-based with pull requests and a ruleset on `main` | Gitflow (unneeded here) |
| 6 | Repo model | Keep two repos, add a third small "platform" repo for the integration compose file, end-to-end tests, deploy workflows, `CONTRACTS.md`, ADRs and runbooks; put `SPEC.md` there too | Merge into one repo |
| 7 | Background jobs | Keep arq behind a thin interface | Procrastinate (Postgres only, one fewer service) or taskiq |
| 8 | Password hashing | argon2id | Keep bcrypt with a 72-byte cap |
| 9 | Bot protection | ALTCHA (self-hosted, no tracking) | Cloudflare Turnstile (poor for Russian users) |
| 10 | Translation library | react-i18next | Lingui (needs a Vite 8 compatibility spike) |
| 11 | Deployment tool | SSH plus `docker compose pull && up -d` from GitHub Actions | Kamal |
| 12 | API versioning | `/v1` prefix from day one | Unversioned until a mobile app exists |
| 13 | Analytics | None now (SPEC decision 12) | Self-hosted Plausible or Umami later |

**Decided on 2026-10-27** (copied to `SPEC.md` decisions 59 to 63): decisions 2, 3, 4, 5, 6, 7, 8, 10, 11 and 12 as recommended; decision 1 (hosting) is left open until the owner is ready, with the aim of the free or cheapest option (the design stays portable and a search for free and cheapest options waits until then); decision 9 (bot protection): none for now, rate limits only; decision 13 (analytics): none. The repos stay public. The API error format is the problem-details superset of section 5. The first technical tasks (section 15, tasks 1 to 4) are started now.

**Progress, 2026-10-27: tasks 1 to 4 of section 15 are done in the working trees (nothing committed or pushed).**
- Backend (`my-list-be`): lint and format fixed; `.github/workflows/ci.yml` with `lint`, `test` (Postgres and Redis service containers) and `migrations` (empty-database upgrade, one head, `alembic check`) jobs, with Actions pinned to commit SHAs; passwords on argon2id off the event loop, with a dummy-hash check for unknown emails (defects 1 and 6); the reset link and email are logged only in `local` and `test` (defect 2); Redis in `docker-compose.yml` with append-only and `noeviction` (defect 3); `/healthz`, `/readyz`, a lifespan that closes the engine and Redis, pool settings and a statement timeout (defect 4); the problem-details error body, request ids and handlers for validation, HTTP and unhandled errors, with the submitted input never echoed (defect 5); a separate test Redis database that the suite flushes (defect 7); `ENVIRONMENT` as a literal, `SecretStr` for the secret key, a startup check that refuses unsafe staging and production settings, no `/docs` and no CORS outside local development, narrower CORS methods and headers (defect 8). 26 tests pass against throwaway Postgres and Redis containers (the usual port 5433 is held by another project's database), and the migrations checks pass.
- Frontend (`my-list-fe`): `ApiError` mirrors the new body (`code`, `params`, `requestId`, `fieldErrors`); a temporary English text catalogue keyed by code (`src/lib/error-messages.ts`, replaced by translation keys when react-i18next lands); form errors map from `fieldErrors`; the root error screen tells a network error from other errors and shows the request id. Type check passes and lint has the same 14 warnings as before.
- Platform: `CONTRACTS.md` has new "Errors" and "Health" sections and no longer has the stale `field_schema` and image sections; the parent folder is now a local git repo (no commit yet, no remote) whose `.gitignore` excludes the two app repos.
- Not done yet (still in the plan): the `/v1` route prefix (a boundary change for a later pass), uv lockfile (task 5), frontend CI and Vitest (task 6), Orval and the drift checks (task 7), i18n and the Query retry policy (task 8), Dockerfiles, Caddy and staging (task 9), Playwright and the load test (task 10), CSRF Origin check, rate limits and real email sending.

**Progress, 2026-10-27 (later): tasks 5, 6 and 7 are open as pull requests.** Backend PR #4 (uv lockfile) and frontend PR #7 (CI and Vitest) are merged. Backend PR #5 mounts the API under `/v1`, commits `openapi/openapi.json`, documents errors as `ProblemDetails`, and adds an `openapi` CI job (snapshot is current; `oasdiff` against main, skipped with the `breaking-change` label). Frontend PR #8 generates the API client and types with Orval into `src/api/generated/` and adds an `api-types` CI job. Merge order: backend #5, then frontend #8. Still open from section 15: i18n and the Query retry policy (task 8), Dockerfiles, Caddy and staging (task 9), Playwright and the load test (task 10), CSRF Origin check, rate limits, real email sending, the `npm audit` findings.

**Progress, 2026-10-27 (evening): task 8 is open as frontend PR #9; PRs #5 (backend) and #8 (frontend) are merged.** react-i18next with English and Russian (typed keys, language from the saved choice, then the browser, then English, a switcher on every page), backend errors translated by code with Russian plurals, router error and not-found screens, the Query retry policy, one error-reporting function for the future Sentry hook, and a one-time reload after a failed lazy chunk. Checked in a browser against the real backend. Still open: saving the language on the account (needs a backend field), Dockerfiles, Caddy and staging (task 9), Playwright and the load test (task 10), CSRF Origin check, rate limits, real email sending, Sentry, `npm audit`.

## 4. Configuration, secrets and environments

- **Backend config.** pydantic-settings is already in use. Make `ENVIRONMENT` a `Literal["local","test","staging","production"]`, use `SecretStr` for secrets, remove `TEST_DATABASE_URL` from production settings, and add a startup check that refuses to boot outside local on a placeholder `SECRET_KEY`, on non-HTTPS cookies or on localhost origins. `.env` files are for local only; real environments get variables from Compose.
- **Frontend config.** Vite bakes `VITE_*` values into the bundle at build time and says not to put secrets there. With same-origin deployment the bundle has no per-environment URL; derive any environment tag (for example for the error tracker) from `location.hostname` at runtime.
- **Secrets.** GitHub Environments with per-environment secrets for deploy credentials (they work on public repos on the free plan; on a free private repo they would not). Runtime secrets live on the server in a root-owned env file or Docker secrets. Pin third-party Actions to full commit SHAs, make `GITHUB_TOKEN` read-only by default, and use OIDC where a target supports it. (There was a reported 2026-03-19 compromise of the `trivy-action` tags; I have only secondary reports, unverified, which is exactly why pinning matters.)
- **Test and seed data.** Never copy production personal data. A `scripts/seed_dev.py` makes fake users and 10 to 20 generated puzzles from the real generator with fixed seeds. Staging gets generated puzzles and synthetic accounts only.
- **Skipped on purpose.** Preview environments per pull request (an ephemeral stack inside the end-to-end job gives most of the value) and a feature-flag service (use settings booleans, and let a game appear in `GET /games` only when its puzzles exist).
- **First-deploy checklist.** Domain and DNS; firewall allows only 22, 80 and 443 and SSH is key-only; fresh secrets and the placeholder check passes; migrations run on an empty database as a separate step; Postgres and Redis are not published; the backup job runs and one restore was tested; `/readyz` is green and an uptime monitor is attached; a deliberate test error reaches the error tracker from both sides; email sends from the real domain with SPF, DKIM and DMARC passing; a rollback was rehearsed on staging; 2 to 3 weeks of puzzles are already scheduled; legal pages and the contact address are live.

## 5. Error handling

**One error shape for the whole API**, an RFC 9457 (problem details) compatible superset, because the frontend needs a stable machine code, not English text:

```json
{
  "type": "about:blank",
  "status": 409,
  "title": "Conflict",
  "code": "email_already_registered",
  "params": {},
  "request_id": "...",
  "errors": [{"field": "password", "code": "too_short", "params": {"min": 8}}]
}
```

`title` and `detail` are English, for developers and logs only. The frontend maps `code` to a translation key (`errors.<code>`) with a per-status fallback.

- **Handlers:** one for the app's own exceptions, one for request validation (map the Pydantic error type and context to codes, and drop `input`), one for HTTP exceptions, and a catch-all that logs with the request id and returns the same JSON with a generic message (otherwise Starlette returns a plain-text 500).
- **Status codes:** 401 no or invalid session; 403 authenticated but forbidden; 404 also for things that must not be revealed (a puzzle for a future date, another user's data); 409 duplicate; 422 validation; 429 with `Retry-After`; 503 a dependency is down.
- **Request ids:** accept `X-Request-ID` from the proxy, return it, put it in every log line and error body. The frontend shows the id on its error screen so a player can report it.
- **Frontend:**
  - Normalise errors in the API client to `{status, code, params, requestId, fieldErrors}`; remove the hard-coded English strings.
  - Pass React 19's `onCaughtError`, `onUncaughtError` and `onRecoverableError` to `createRoot` and send them to the error tracker.
  - Set TanStack Router's `defaultErrorComponent` and `defaultNotFoundComponent`; today the root `errorComponent` says "Couldn't reach the server" for every error. Tell network errors, server errors and chunk-load failures apart.
  - Wrap each game module in its own error boundary, so one crashing game leaves the nav bar working.
  - TanStack Query: today `new QueryClient()` retries every error three times. Retry only network errors and 5xx, at most twice, never 4xx except 408 and 429, never mutations. Add global `QueryCache` and `MutationCache` error callbacks.
- **Deploys with open tabs (version skew).** Vite emits `vite:preloadError` when a lazy chunk is gone after a deploy: reload once (guarded by a `sessionStorage` flag, after saving game state), keep the previous release's assets on disk for a week, serve `index.html` with `no-cache`, and keep the backend compatible with the previous frontend (expand and contract).

## 6. CI/CD

GitHub Actions in both repos (standard runners are free for public repos).

**Backend `ci.yml` (pull request and main):**

| Job | What it does |
|---|---|
| lint | `ruff check`, `ruff format --check` (fails today: fix once) |
| typecheck | mypy or pyright, non-strict at first |
| test | pytest with `postgres:16` and `redis:7` service containers, coverage |
| migrations | `alembic upgrade head` on an empty database; exactly one head (`alembic heads`); `alembic check` for model and migration drift; optionally downgrade one and upgrade again. Needed because the tests use `create_all`. |
| openapi | export `openapi.json` from the app object, compare with a committed snapshot, run `oasdiff breaking` against main |
| contract-fuzz | Schemathesis against the app (ASGI support not confirmed: spike it) |
| audit | `pip-audit` and a license report |
| secrets | gitleaks (GitHub push protection also covers public repos) |
| docker | build, scan, SBOM, push to GitHub Container Registry on main |

**Frontend `ci.yml`:** lint (ESLint, prettier; format the vendored shadcn files once or ignore them), `tsc -b` and `vite build` with `npm ci`, Vitest and Testing Library (not installed yet), a types-drift job (fetch the backend's `openapi.json` at a pinned ref, run Orval, `git diff --exit-code`), bundle budgets (size-limit on the initial JS and per-game chunks), Playwright end-to-end tests with axe accessibility checks against a Compose stack (desktop Chromium, a phone-size Chromium, an iPhone-class WebKit, a tablet), Lighthouse (run it directly; `@lhci/cli` looks stale), and `npm audit` with a license check.

**The contract between the repos** (the highest drift risk in `CONTRACTS.md`):
1. The backend owns the spec: it commits `openapi/openapi.json`, CI fails when the file is stale, and stable operation ids are set so Orval names do not change.
2. A backend pull request runs `oasdiff breaking` against main; a breaking change needs an explicit label.
3. A cross-repo check in the backend CI: check out the frontend `main` (public, so no token), point Orval at the pull request's `openapi.json`, run `tsc -b` and Vitest. A backend change that breaks the frontend turns red before merge. This is the strongest cheap contract test.
4. The frontend's types-drift job guards the other direction.
5. Make `CONTRACTS.md` honest: delete the stale `field_schema` and image sections, move machine-checkable claims (cookie flags, 204 on reset, 400 on a bad token) into pytest, check that every endpoint named in it exists in the OpenAPI snapshot, add a pull request template checkbox "boundary change, `CONTRACTS.md` updated", and put it under git.

**Release flow:** build once, tag the image with the git SHA, and promote the same digest through staging to production. Staging deploys on merge to main. Production deploys through a GitHub Environment with a required reviewer (as a solo developer this is a deliberate pause). Rollback is redeploying the previous digest, which is only safe with expand and contract migrations. The frontend ships static files; rollback flips `index.html`.

**Migrations (expand and contract):** release N adds nullable columns or tables and writes both shapes; N+1 reads the new shape; N+2 drops the old one. Run `alembic upgrade head` as its own deploy step before the new app version starts. Use `lock_timeout`, `statement_timeout` and `CREATE INDEX CONCURRENTLY`. Postgres DDL is transactional, so a failed migration normally leaves the schema unchanged: fix forward and restore from backup only for data damage.

**Workflow rules:** trunk-based, short branches, squash merge, a ruleset on `main` (required checks, no force push, linear history), self-review through a pull request template while solo, CODEOWNERS when a second person joins. Dependabot (zero infrastructure; supports npm, pip, GitHub Actions, Docker and Compose; uv support has had gaps) with grouped updates and a cooldown. Pre-commit hooks (ruff, gitleaks) in the backend, lefthook or husky in the frontend; CI is the authority.

## 7. Backend readiness

- **Already good (checked):** per-domain layering and thin routers; httpOnly, SameSite=Lax, Secure-outside-local cookie; 256-bit opaque session tokens with TTL; a fresh token on every login; revoke-all on reset and revoke-others on password change; a generic 202 on forgot-password; single-use reset tokens; timezone-aware timestamps; unique email index; test isolation by savepoint; async Alembic.
- **Health:** `/healthz` (liveness, no dependencies) and `/readyz` (Postgres `SELECT 1`, Redis `PING`), not public. A lifespan handler that closes the engine and Redis client. Uvicorn with `--workers` equal to the vCPU count (2) behind Caddy, `--proxy-headers` with the proxy's address (otherwise per-IP limits see only the proxy), `stop_grace_period` and `--timeout-graceful-shutdown` set to the longest request. Gunicorn only if `max-requests` recycling is needed.
- **Database pool:** SQLAlchemy defaults are `pool_size=5`, `max_overflow=10`, no pre-ping. Proposal: `pool_size=5`, `max_overflow=5`, `pool_pre_ping=True`, `pool_timeout=10`, and a server-side `statement_timeout`. Skip PgBouncer at this scale (prepared statements with asyncpg need care). Add a naming convention on `Base.metadata` before more tables, unique constraints `(game, variant, date)` on puzzles and `(user, game, variant, date)` on progress, a leaderboard index `(puzzle_id, score, finished_at)`, `ON DELETE CASCADE` from users, CHECK constraints for status values, and separate database roles (migrator with DDL, app with DML only).
- **Redis:** production with `--appendonly yes --appendfsync everysec` and `maxmemory-policy noeviction` on the instance that holds sessions (eviction would log users out silently). A real cache gets another database or instance with `allkeys-lru`.
- **Passwords:** switch to argon2id now, while there are no users (OWASP: at least 19 MiB, 2 iterations, parallelism 1; bcrypt is "legacy only" with a 72-byte limit), through argon2-cffi or pwdlib. If bcrypt stays, cap at 72 bytes and say so in the validation error. Hash in a thread (`asyncio.to_thread`). On login, verify against a dummy hash when the email is unknown. Registration returns 409 for a duplicate email, which also reveals existence; rate-limit it.
- **Email:** a provider (Resend free tier is 3,000 a month and 100 a day; Amazon SES about 0.10 dollars per 1,000), a dedicated sending subdomain, SPF, DKIM and DMARC, sending through the job queue and not inline. Deliverability to Russian mailboxes (mail.ru, Yandex) is unverified: test with real accounts.
- **Rate limiting:** the `limits` library with Redis storage behind a small dependency. Starting values (estimate): per IP on login and register about 10 a minute; per email on login and forgot-password about 5 an hour; per account on mutating routes; stricter on guest verification endpoints.
- **Bot protection:** ALTCHA (MIT, self-hosted, proof-of-work, no cookies or tracking) on sign-up, behind a setting. Cloudflare Turnstile works without the Cloudflare CDN but Cloudflare is throttled from Russia (section 11).
- **CSRF:** `SameSite=Lax` is defense in depth, not a replacement (OWASP). Layer: reject unsafe methods whose `Origin` (or `Sec-Fetch-Site`) is not allowed; require `Content-Type: application/json` plus a custom header such as `X-Requested-With`; never change state on GET. A signed double-submit token is optional on top. A React Native client with bearer tokens needs none of this, so keep it at the cookie-auth layer.
- **Headers and CORS:** production is same-origin, so drop CORS or use an exact list. Caddy adds `X-Content-Type-Options: nosniff`, `Referrer-Policy`, `Permissions-Policy`, `Strict-Transport-Security` and `frame-ancestors 'none'`, and `Cache-Control: no-store` on auth responses. Disable `/docs` in production, keep `/openapi.json` for the Orval flow. Consider a `__Host-` cookie prefix. CSP proposal: `default-src 'self'; script-src 'self' 'wasm-unsafe-eval'; img-src 'self' data: <object-storage origin>; connect-src 'self'; object-src 'none'; base-uri 'self'; frame-ancestors 'none'`. `'wasm-unsafe-eval'` is the narrow permission for WebAssembly (the playable challenge needs it). The inline theme script in `index.html` needs a hash or an external file, and shadcn and Tailwind will need `style-src 'unsafe-inline'` for now.
- **API shape:** mount under `/v1` now, because a React Native app cannot be force-updated. Keyset pagination for the archive and leaderboards. A puzzle's public part (step 1) can be `Cache-Control: public` with an ETag; progress-dependent responses are `private, no-store`; images are content-addressed with immutable caching.
- **Backups:** nightly `pg_dump`, encrypted, copied to a different provider; WAL archiving once real user data exists (check pgBackRest's current status before choosing, reports of its archiving and revival in 2026 are unconfirmed; WAL-G is the alternative). A monthly job that restores the latest backup into a throwaway container and runs sanity queries: an untested backup is not a backup. Redis backups are a copy of the RDB file.
- **Privacy features (GDPR):** `DELETE /me` (re-authenticate, cascade delete, revoke sessions), `GET /me/export` (JSON), a backup retention window stated in the privacy policy, and an audit-log table (login, password change, reset, deletion, export; user id, time, hashed IP) kept about 90 days.

## 8. Frontend readiness

- **Error tracking:** `@sentry/react`, which also works with the self-hosted tools. Sentry's free cloud plan is small (5k errors, 1 user, 30-day lookback); self-hosting Sentry itself is heavy (4 cores, 16 GB RAM) and its license is FSL, so for self-hosting prefer GlitchTip (MIT backend; hosted free tier 1,000 events a month) or Bugsink (hosted free 15K events; license unconfirmed). Upload source maps from CI with the git SHA as the release and do not serve `.map` files publicly. No personal data by default.
- **Performance:** `autoCodeSplitting` is already on in the router plugin. Lazy-load each game through the registry (the emulator loads only on its route). Budgets with size-limit and Lighthouse thresholds for mobile. Hashed assets `public, max-age=31536000, immutable`; `index.html` `no-cache`; content-hash names for wasm, ROMs and start states.
- **PWA and offline:** skip the service worker for now: answers are checked on the server, so offline play is not meaningful, and a service worker adds its own version-skew problem. A web app manifest can come later.
- **Translations (English and Russian):** react-i18next unless a Lingui spike on Vite 8 is clean. Russian plurals have `one`, `few`, `many` and `other` forms (`Intl.PluralRules`). Use `Intl.DateTimeFormat` and `Intl.NumberFormat` with the active locale; show puzzle days with `timeZone: 'UTC'`. Update `<html lang>` (static `en` today). CI fails when a key is missing in either language. The Geist font already ships Cyrillic subsets.
- **Accessibility testing:** axe through Playwright on every key page and viewport, keyboard-only tests, a manual pass with VoiceOver and NVDA before launch. Automated checks catch only part of the problems.
- **Sharing and SEO:** Google renders JavaScript, social crawlers generally do not, so link previews of a pure SPA are blank. Now: static meta tags and one static share image in `index.html`. Later: a tiny route such as `/share/{game}/{date}` that returns minimal HTML with Open Graph tags and redirects browsers to the SPA (it must never reveal answers). Skip prerendering and a framework switch for the MVP.
- **Web Vitals:** lab measurement only (Lighthouse, Playwright), because SPEC decision 12 says no analytics.

## 9. Operations

- **Logs:** JSON to stdout (structlog or python-json-logger), Docker `json-file` with a size limit. Log user ids (UUID) and not emails; hash IPs if kept; never log bodies, cookies or reset tokens; never log 422 bodies.
- **Minimal stack, about 0 to 10 euros a month (estimate):** uptime checks with UptimeRobot (free: 50 monitors at 5-minute interval, 1 status page) or self-hosted Uptime Kuma; cron heartbeats with healthchecks.io (free: 20 checks) for the backup job and the nightly puzzle check; error tracking (section 8); Prometheus metrics through `prometheus-fastapi-instrumentator`; optional Grafana Cloud free tier (50 GB logs, 14-day retention). Traces (OpenTelemetry's FastAPI instrumentation is still beta) are "later".
- **SLOs for a daily game (estimate):** 99.5% monthly availability for reading today's puzzle (about 3.6 hours of budget); today's puzzle served correctly within 5 seconds of 00:00 UTC on 99.9% of days; guess submit p95 under 300 ms; **tomorrow's puzzle exists by 22:00 UTC every day** (a content SLO and the most valuable alert). Page only for: site down, `/readyz` failing, tomorrow's puzzle missing, backup failed, disk over 85%. Everything else goes to a digest.
- **The 00:00 UTC spike:** everyone plays the new puzzle at once. What is hit: the SPA shell, today's puzzle metadata and the step-1 image. Mitigations in order of value: serve shell and assets from Caddy or a CDN, never through Python; pre-build the day's public puzzle view and warm it in Redis at about 23:55 UTC under a key that includes the date; give step-1 images long-cache public URLs and later steps short-lived signed URLs (they must be earned); a client-side random delay of 0 to 3 seconds after the countdown reaches zero (safe because the server clock owns timed games); per-IP limits and `503 Retry-After`. Back-of-envelope (estimate): 5,000 daily players with 20% arriving in the first 5 minutes is about 17 requests a second on average and maybe 10 times that at peak, which a 2-vCPU box should handle if the hot path avoids the database. Measure it: one k6 test (k6 is AGPL-3.0, which does not affect our own license when used as a tool) with a ramp to about 5 times the expected peak.
- **Scheduling.** Puzzles are rows keyed by `(game, variant, date)`, so nothing has to run at 00:00: the day's puzzle is a query on the current UTC date. A job at about 23:30 UTC only warms caches and alerts if tomorrow's puzzle is missing. Publishing is idempotent: unique constraint on the key, `INSERT ... ON CONFLICT DO NOTHING`, a status flow `draft, in_review, approved, scheduled, published`, and a Postgres advisory lock so two workers never run the same job.
- **Background jobs:** arq 0.28.0 (released 2026-04-16) says "In maintenance only mode" in its README; critical security fixes continue. It is not installed yet, so keep job code behind a thin interface. Procrastinate 3.10.0 (MIT) keeps jobs in Postgres: no extra service, and enqueue can be transactional. Do not install arq or the S3 client until a real job needs them (replay verification and email will be first).
- **Runbooks** in `docs/runbooks/`: rollback, restore from backup, Postgres disk full, Redis lost (everyone logged out), tomorrow's puzzle missing (publish from a pool of spare puzzles), certificate problem, suspected secret leak. The owner is on call; alerts go to Telegram or email; short blameless postmortems. Recovery targets to start with: RPO 24 hours (nightly dump) improving to about 15 minutes with WAL archiving; RTO 2 to 4 hours by rebuilding from the Compose files and the latest backup.

## 10. Needs that come from the games

- **Replay verifier for the playable challenge (untrusted input).** The input is data (ticks and buttons), not code; the attack surface is the replay parser, the C emulator and CPU or memory exhaustion. Layered defenses: (1) validate the replay in Python first (cap at about 64 KB, monotonic ticks, a maximum tick count equal to the time cap times 4,194,304 ticks a second, which bounds the runtime); (2) run the native runner as a child process with an empty environment, a non-root user, CPU and memory limits and a wall-clock kill, no database or Redis credentials; (3) a dedicated container with `--network none`, read-only filesystem, dropped capabilities, `no-new-privileges`, memory and CPU limits; (4) strongest: gVisor `runsc`, which does not pass container syscalls to the host kernel (the emulator is CPU-bound with few syscalls, so it should fit). A separate low-concurrency queue, one attempt per day per account (SPEC decision 54) as the natural cap, a per-user pending limit and a global queue depth limit that returns a "pending" state. The guest-verification path is the DoS-prone one: rate-limit it per IP and protect it with ALTCHA. Hardening is a launch gate for that game, after the spike.
- **WebAssembly and ROMs:** serve `.wasm` as `application/wasm` (`.gb` and `.gbc` default to `application/octet-stream`), content-hash file names with `immutable`, brotli for the wasm, same-origin hosting, `nosniff`. COOP and COEP only if a threaded emulator is ever used (binjgb has no threads).
- **Server-measured timing (click game):** take timestamps from one clock authority, the database (`clock_timestamp()`) or Redis `TIME`, not from each worker's clock. Keep the host on chrony or systemd-timesyncd and alert on drift above 0.5 seconds. The client countdown uses an offset from the response `Date` header, for display only. Network noise of tens to hundreds of milliseconds is acceptable against 20 to 60 second solves; document it. Guest tokens: HMAC-SHA256 over attempt id, game, date, start time, miss count, sequence number and key id, with expiry, compared with `hmac.compare_digest`; a `kid` field allows key rotation.
- **Content pipelines:** a CLI with `--dry-run`, `--game`, `--from`, `--to`; a deterministic seed equal to a hash of `(game, variant, date, generator version)` **plus a secret salt kept in the environment, never in the repo** (the repos are public, so a seed made only from public inputs would let anyone compute future puzzles; tests use a fixed test salt); content-addressed image keys (SHA-256) so re-runs do not duplicate objects; EXIF stripped; random, never date-based, image keys; a manifest per puzzle with license and source URL (SPEC 3.7); private buckets with short-lived signed URLs issued only when a step is earned; answer lists never in the JS bundle (the word game's guess list is fine, answers are not). Run generation from a scheduled GitHub Action with environment secrets or from a workstation, and alert when the scheduled buffer drops below 7 days. **Because the repos are public, keep puzzle data in the database and the private bucket only; keep only generator code and anonymised test fixtures in Git.**
- **Leaderboards:** Postgres is the source of truth (index `(puzzle_id, score, finished_at)` gives exact order and the tie rules). Cache the top 100 per puzzle for 5 to 10 seconds in Redis; a player's rank is one indexed count; freeze a board once its day ends.
- **Images:** process puzzle images offline in the generator (Pillow 13.0.0; pyvips 3.2.0 for low-memory work and deep-zoom tiles), cap pixel counts, strip EXIF, emit WebP and sizes. No request-time thumbnail worker is needed (the app keeps no item or user images).

## 11. Hosting, privacy and reachability

| Option | Evidence | Notes |
|---|---|---|
| Hetzner Cloud VPS plus Compose and Caddy | CX23 5.49 euros a month, CX33 8.49, CAX11 5.99 (Hetzner docs, from 2026-06-15); object storage 6.49 euros a month with 1 TB | Cheapest and portable; you patch and back up. Total about 12 to 25 euros a month (estimate) |
| Cloudflare R2 | 0.015 dollars per GB-month, free egress | Cheap, but Cloudflare reachability from Russia is a problem |
| Fly.io | no free tier; Managed Postgres from 38 dollars a month | Whole stack about 50 dollars or more (estimate) |
| Railway | Hobby 5 dollars, usage-based | About 20 to 40 dollars a month (estimate); spikes cost money |
| Neon, Supabase | Neon free scales to zero after 5 minutes idle; Supabase Pro from 25 dollars | Scale-to-zero is a poor fit when the first request of the day is the busiest |
| Upstash Redis | free 250 MB, 500K commands a month | Sessions alone would burn the free command budget: run Redis in Compose |
| AWS, GCP, Azure | not priced | Overkill; 30 to 100 dollars or more (estimate) |
| Render | pricing page returned no figures | unverified |

Caddy gets and renews TLS certificates automatically. Infrastructure as code: Compose files plus cloud-init are enough for one VPS; add OpenTofu when staging and production must be recreated reproducibly. Kubernetes is overkill.

**Reachability from Russia (important for a Russian-speaking audience).**
- Cloudflare confirmed on 2025-06-30 that Russian ISPs have throttled sites it protects since 2025-06-09 (the measured effect is a cut-off after about 16 KB, so small pages load while scripts and images stall). Reports of Hetzner and DigitalOcean throttling exist without dates or figures. Reports of further restrictions through August 2026 come from search summaries only and are unverified.
- Consequence: some Russian users will not reach a foreign-hosted site at certain times, outside our control. Do not depend on Cloudflare for the page, fonts or CAPTCHA; self-host fonts (already bundled) and the emulator; keep the first load small; test from a Russian vantage point (a volunteer or a probe service) before launch; Helsinki is probably closer than Falkenstein (assumption).
- **Data protection (general information, not legal advice).** GDPR applies to a non-EU site that offers the service to people in the EU, paid or not (Art. 3(2)); plan for a privacy notice, a lawful basis, deletion and export rights, and a 72-hour breach notification (Art. 33). Russia's data-localization rule (Federal Law 152-FZ, Art. 18(5)) is described in secondary sources as applying to operators collecting personal data of Russian citizens, which on its face includes foreign sites; how it applies to a small non-commercial foreign site is unverified. Get counsel before launch. Cheap mitigation already in the spec: guests are stateless (decision 16), so only account holders have personal data (email and password hash). Keep it that way and do not add analytics identifiers.

## 12. Testing

- **Backend:** keep the real-Postgres, real-Redis pytest pattern; use service containers in CI. Add a separate `TEST_REDIS_URL` on another database. Add the migrations job, and tests for register, login, logout and `/auth/me`. Hypothesis for generators and filters, for example: the two-pass letter colouring never marks more letters than the answer holds; the word filter is idempotent and the answer list is a subset of the guess list; a generated geometry puzzle has exactly one answer under the engine and matches the numeric check. Every generator takes a seeded `random.Random` and never global state; keep golden-file snapshots of generated puzzles at pinned generator versions; inject `now()` so UTC day-boundary tests are exact. Coverage floor about 80% overall and about 90% on scoring and rules modules (estimate); do not chase 100%. Mutation testing (mutmut) only occasionally on small pure modules.
- **Frontend:** Vitest, React Testing Library and MSW (Orval can generate the mocks). Playwright for critical journeys only: a guest plays a game, register and login, password reset, language switch, the archive; with mobile and tablet projects and axe.
- **Load:** one k6 scenario for 00:00 UTC.
- **Flaky tests:** no automatic retries for unit tests; Playwright `retries: 1` in CI only, and a test that passes on retry is reported as flaky; a flaky test is quarantined with an issue and fixed within a week, or deleted; no sleeps; inject time and randomness.

## 13. Repository and workflow

- **Repo model.** SPEC.md, CONTRACTS.md and the parent CLAUDE.md are not under version control today; fix that regardless of the repo count. If two repos stay, a third small "platform" repo holds the integration compose file (frontend, backend, Postgres, Redis, MinIO), the Playwright tests, deploy workflows and infrastructure code, `CONTRACTS.md`, `SPEC.md`, ADRs and runbooks. The main alternative is the backend repo; the other is one monorepo (atomic cross-boundary pull requests, one CI run, a trivial drift check).
- **Backend lockfile:** uv (`uv.lock`, `uv sync --locked`, Docker pattern with cache mounts and multi-stage builds, CycloneDX SBOM export in preview). Add a `[project]` table and `requires-python` to `pyproject.toml` (absent today) and a `.python-version`. pip-tools is the smaller step; Poetry has no advantage here.
- **Other:** a Makefile or `justfile` (`up`, `test`, `e2e`, `types`, `lint`); Architecture Decision Records as one short markdown file each in `docs/adr/NNNN-title.md` (status, context, decision, consequences), seeded from `SPEC.md` section 2; GitHub Releases with generated notes (release-please or git-cliff if Conventional Commits are adopted); pull request template (migration included? contract changed? `CONTRACTS.md` updated? mobile screenshots?) and issue forms (bug, puzzle problem report, rights takedown request); real READMEs (the backend's is empty); dev containers are skipped until a second developer joins.

## 14. Security baseline

| OWASP Top 10:2025 | Status here |
|---|---|
| A01 Broken access control | Few routes today; each future per-user route needs an owner check and a test with another user's id |
| A02 Security misconfiguration | Open: public `/docs`, no security headers, wide CORS headers, Redis without append-only |
| A03 Supply chain failures | Open: no backend lockfile hashes, no audit, no CI (so no pinned Actions yet) |
| A04 Cryptographic failures | bcrypt 72-byte crash; argon2id recommended; cookie is Secure outside local |
| A05 Injection | SQLAlchemy parameterises; keep raw SQL out of generators and search |
| A06 Insecure design | Server-side answers, server clock and signed tokens are good; keep them |
| A07 Authentication failures | Open: no login throttling, timing leak on unknown email, no bot protection |
| A08 Software or data integrity failures | Replay verification covers game results; sign any client-held state |
| A09 Logging and alerting failures | Open: reset link and email in logs, no structured logs, no alerts |
| A10 Mishandling of exceptional conditions | Open: plain-text 500s; the bcrypt error becomes a 500 |

API-specific points: object-level authorization on every object route; explicit response models (`UserRead` already limits fields); request size caps, pagination limits and the verifier limits; limits on sign-up, forgot-password, guess submission and guest verification; allow-list hosts for any fetch-by-URL in the puzzle scripts; validate third-party data (game and movie APIs) in scripts; an exported OpenAPI snapshot as the inventory.

Also: lockfiles in both repos with `npm ci` and `uv sync --locked`; `pip-audit` and `npm audit`; build attestations and an SBOM per image; containers run as non-root from slim base images pinned by digest, with a read-only root filesystem, `cap_drop: ALL`, `no-new-privileges`, health checks and no published database ports; least-privilege database roles; rotate the database password yearly and on suspected exposure; encrypt backups and keep a copy at another provider. Analytics later: self-hosted Plausible (AGPL, cookieless) or Umami (MIT); the privacy policy is updated first, and whether a consent banner is needed is jurisdiction-dependent. Incident plan: detect, contain (delete `session:*` and `sessions_user:*`, rotate secrets, take the affected route down), assess whether personal data was involved, notify the authority within 72 hours if required, notify users, write a postmortem.

## 15. Prioritised plan (efforts are estimates for one developer)

**MUST before the first public launch**

| Practice | Effort | Reason |
|---|---|---|
| Minimal CI in both repos (lint, types, tests, build, migrations job) | 1 day | Nothing runs automatically; migrations are untested |
| Fix the bcrypt 500, switch to argon2id, hash in a thread | 3 h | Live bug, hits Russian passwords |
| Error contract: handlers, `code`, `params`, `request_id`, catch-all, strip `input`; frontend `ApiError` and translation mapping | 2 days | Required for a Russian UI and safe 500s |
| Production settings validators; secure cookie, CORS, `/docs` off, trusted proxy | 4 h | Prevent booting with placeholder config |
| Dockerfiles for both; production Compose; Caddy with headers and CSP; same-origin routing | 1.5 days | Needed to deploy at all |
| `/healthz`, `/readyz`, lifespan shutdown, pool settings | 3 h | Safe deploys and restarts |
| CSRF Origin check; rate limits on auth and forgot-password | 1 day | Gap acknowledged in `CONTRACTS.md` |
| Real email sending with SPF, DKIM, DMARC; remove link logging | 1 day | The stub logs live reset tokens |
| Backups, one tested restore, Redis append-only and `noeviction` | 1 day | Data loss otherwise |
| Error tracking and an uptime check with alerts | 0.5 day | You find out when it breaks |
| uv lockfile in the backend | 2 h | Reproducible builds |
| Orval plus OpenAPI snapshot plus drift check | 1 day | The contract flow does not exist yet |
| Staging environment, deploy workflows with approval, a rehearsed rollback | 1.5 days | Safe first deploy |
| Account deletion and export; a privacy policy that matches reality | 1 to 1.5 days | GDPR |
| Load test of the 00:00 UTC scenario | 0.5 to 1 day | The main operational risk |
| Playwright smoke tests on mobile and desktop plus axe | 1 day | Responsive and accessible are decided requirements |
| `vite:preloadError` handling and no-cache HTML | 2 h | Version skew on the first deploy |

**SHOULD soon after launch:** Dependabot with grouping and a cooldown; pre-commit hooks; gitleaks; image scan, SBOM and attestation; Schemathesis and `oasdiff`; a Hypothesis suite for the first generator; the audit-log table; ALTCHA on sign-up; size-limit and Lighthouse budgets; runbooks; pull request and issue templates; ADRs; database roles; a separate test Redis; WAL archiving; Grafana Cloud logs and metrics; a status page; the share-card route.

**LATER:** OpenTelemetry traces; OpenTofu; preview environments; a feature-flag service; a service worker and PWA; mutation testing; the gVisor-level sandbox (a MUST for the playable challenge before ranked verification goes live); multi-region; React Native token auth; real-user monitoring.

**The first 10 tasks, in order**
1. Backend: run `ruff format`, fix the 5 lint errors, add `ci.yml` with lint, tests with Postgres and Redis services, and the migrations job.
2. Backend: fix passwords (argon2id, thread, validation); add tests for register, login, logout and `me`; add a separate test Redis.
3. Both: put `CONTRACTS.md` and `SPEC.md` under git (platform repo or backend `docs/`) and delete the stale MyList sections.
4. Backend: error contract, handlers and request id; `/healthz`, `/readyz`, lifespan; production settings validators.
5. Backend: move to uv with `uv.lock`; add `[project]` metadata.
6. Frontend: CI (lint, `tsc -b`, build), fix prettier on vendored files, set up Vitest and the first tests.
7. Both: Orval with an `openapi.json` snapshot, `oasdiff`, and the frontend drift job; replace the hand-written auth types.
8. Frontend: `ApiError` with codes, react-i18next with English and Russian, the `QueryClient` retry policy, `createRoot` error hooks, `defaultErrorComponent`.
9. Platform: Dockerfiles, production Compose with Caddy (same-origin, CSP), Redis append-only, the backup job, a staging deploy workflow with environments.
10. Both: a Playwright smoke test with mobile projects and axe, then a k6 test of the 00:00 path.

## 16. Not verified

Current Render pricing; Hetzner's own page for CX specs; whether GitHub artifact attestations are available on the free plan; the current state of Russian throttling of Cloudflare and Hetzner after August 2026; how Russia's data-localization rule applies to a small non-commercial foreign site; Bugsink's license; Sentry's data-scrubbing page; Lingui with Vite 8; Schemathesis with FastAPI's ASGI app; whether Dependabot security updates now cover uv; deliverability to Russian mailboxes; the pgBackRest status; the `trivy-action` incident details (secondary reports only).

## 17. Sources

The agent's report cited the primary pages below (opened 2026-10-27); registry data came from the PyPI and npm JSON APIs.
- Code and repo evidence: files in both repos, `git` and `gh api` metadata, local runs of ruff, eslint, prettier, bcrypt and an in-process HTTP probe.
- Frameworks: [FastAPI server workers](https://fastapi.tiangolo.com/deployment/server-workers/), [uvicorn deployment](https://uvicorn.dev/deployment/) and [settings](https://uvicorn.dev/settings/), [SQLAlchemy pooling](https://docs.sqlalchemy.org/en/20/core/pooling.html), [Alembic commands](https://alembic.sqlalchemy.org/en/latest/api/commands.html), [Redis persistence](https://redis.io/docs/latest/operate/oss_and_stack/management/persistence/), [bcrypt on PyPI](https://pypi.org/project/bcrypt/), [arq](https://github.com/python-arq/arq), [Procrastinate](https://procrastinate.readthedocs.io/en/stable/), [uv Docker guide](https://docs.astral.sh/uv/guides/integration/docker/).
- Standards and security: [RFC 9457](https://www.rfc-editor.org/rfc/rfc9457.html), OWASP [password storage](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html), [CSRF prevention](https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html), [Top 10:2025](https://top10.owasp.org/2025), [API Top 10:2023](https://api-security.owasp.org/editions/2023/en/0x11-t10), [CSP script-src (MDN)](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Content-Security-Policy/script-src), [gVisor](https://gvisor.dev/docs/), [Docker resource limits](https://docs.docker.com/engine/containers/resource_constraints/), [ALTCHA](https://altcha.org/), [Cloudflare Turnstile](https://developers.cloudflare.com/turnstile/), [GDPR Art. 3](https://gdpr-info.eu/art-3-gdpr/) and [Art. 33](https://gdpr-info.eu/art-33-gdpr/).
- GitHub and CI: [environments](https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/manage-environments), [secure use](https://docs.github.com/en/actions/reference/security/secure-use), [artifact attestations](https://docs.github.com/en/actions/concepts/security/artifact-attestations), [Dependabot ecosystems](https://docs.github.com/en/code-security/dependabot/ecosystems-supported-by-dependabot/supported-ecosystems-and-repositories), [Orval](https://github.com/orval-labs/orval), [Schemathesis](https://schemathesis.readthedocs.io/en/stable/), [oasdiff](https://github.com/oasdiff/oasdiff), [k6](https://github.com/grafana/k6).
- Frontend: [Vite env and mode](https://vite.dev/guide/env-and-mode), [Vite build](https://vite.dev/guide/build), [React createRoot](https://react.dev/reference/react-dom/client/createRoot), [TanStack Router data loading](https://tanstack.com/router/latest/docs/framework/react/guide/data-loading), [TanStack Query retries](https://tanstack.com/query/latest/docs/framework/react/guides/query-retries), [Intl.PluralRules (MDN)](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Intl/PluralRules), [Google JavaScript SEO basics](https://developers.google.com/search/docs/crawling-indexing/javascript/javascript-seo-basics), [Lingui](https://lingui.dev/introduction), [Sentry](https://sentry.io/pricing/), [GlitchTip](https://glitchtip.com/), [Bugsink](https://www.bugsink.com/).
- Hosting and prices: [Hetzner price adjustment](https://docs.hetzner.com/general/infrastructure-and-availability/price-adjustment/), [Hetzner Object Storage](https://www.hetzner.com/storage/object-storage/), [Fly.io pricing](https://docs.fly.io/about/pricing), [Railway](https://railway.com/pricing), [Cloudflare R2](https://developers.cloudflare.com/r2/pricing/), [Neon](https://neon.com/pricing), [Supabase](https://supabase.com/pricing), [Upstash](https://upstash.com/pricing/redis), [Bunny](https://www.bunny.net/pricing/cdn/), [Caddy automatic HTTPS](https://caddyserver.com/docs/automatic-https), [Kamal](https://kamal-deploy.org/), [Resend](https://resend.com/pricing), [Amazon SES](https://aws.amazon.com/ses/pricing/), [UptimeRobot](https://uptimerobot.com/pricing/), [healthchecks.io](https://healthchecks.io/pricing/), [Grafana](https://grafana.com/pricing/).
- Russia: [Zona on Cloudflare](https://en.zona.media/article/2025/06/19/cloudflare), [The Record](https://therecord.media/cloudflare-russia-restricting-access-crackdown), [Zona on 2026 censorship](https://en.zona.media/article/2026/04/07/russian_internet_censorship_2026).
