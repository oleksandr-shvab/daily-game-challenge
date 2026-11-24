# M1-40: Docker images, production Compose and Caddy — Implementation Plan

Status: draft, 2026-11-24. Scope: a production setup the owner can run on this laptop today and launch from whenever they decide. It has one Dockerfile in each app repo (each built in that repo's CI, never pushed), a production Compose file in the platform repo, a Caddyfile in the frontend repo, a smoke script, and a launch runbook. **Nothing in this plan deploys anything, buys anything or creates a cloud resource.** Line numbers were checked against backend `main` at `f156751`, frontend `main` at `9165fb8` and platform `main` at `3046897`. There is no feature spec. The milestone row and the owner's brief are the requirements.

## Source requirements

- Task row: `MILESTONE-1.md:105`. "Dockerfiles for both apps (multi-stage, non-root), production Compose, Caddy (same origin, security headers, CSP with `wasm-unsafe-eval` only if needed, `index.html` no-cache, hashed assets immutable, `/healthz` and `/readyz` hidden)". Repos: PL, BE, FE. Estimate: 1.5 days. Done when "the whole site runs from Compose on this laptop".
- Target shape: `ARCHITECTURE.md:37-51` (one VPS, Compose, Caddy in front, `/api/*` proxied with `/api` stripped, Postgres and Redis not published, same origin). Headers and CSP: `ARCHITECTURE.md:171`. Caching: `ARCHITECTURE.md:179`. Health and uvicorn: `ARCHITECTURE.md:163`. Redis: `ARCHITECTURE.md:165`. Container hardening: `ARCHITECTURE.md:255`. Migrations as their own step: `ARCHITECTURE.md:156`. Version skew: `ARCHITECTURE.md:125`. Logs: `ARCHITECTURE.md:188`. Runbooks in `docs/runbooks/`: `ARCHITECTURE.md:194`. First-deploy checklist: `ARCHITECTURE.md:96`.
- From the brief, for later and not built here: a short launch runbook covering a server, a domain and secrets; `ENVIRONMENT=production` validation; the IGDB image gate (`IGDB_IMAGES_CLEARED_BY`, decision 73, `SPEC.md:87`); promote from local (M1-24c); backups; and what M1-52 adds (`MILESTONE-1.md:119`).
- Owner decisions from the brief, not reopened:
  - One implementer per PR, then plan-verifier, then the owner merges.
  - Code review high and a test-writer pass for the risky PRs.
  - A small test budget, and every test must be able to fail.
  - CI builds the images and pushes nothing.
  - Learning project (2026-11-20): the simplest setup that would really work in production.
  - Agents never read `.env` files. Every value comes from an example or vars file with dummy values.
- Parallel security plan (hacksplaining classes): this plan owns every HTTP response header and the CSP, all in Caddy. Rate limits (M1-42) and the rest of "Coordination with the security plan" below belong to that plan.

**State of the code (checked 2026-11-24):**
- No Dockerfile, `.dockerignore` or `compose.prod.yml` exists in any of the three repos. `my-list-be/docker-compose.yml` is the dev compose file: Postgres 16 on host port 5433, and Redis 7 with append-only and `noeviction` (`:1-27`).
- Backend runtime dependencies are `[project].dependencies` (`pyproject.toml:6-18`). Pillow, PyAV and httpx sit in the `content` group (`:30-34`). `uv sync --no-default-groups` installs the runtime only (`my-list-be/CLAUDE.md:20`). "The repo has no Dockerfile yet, so whatever builds the server image must sync that way to keep the content libraries out of it" (`my-list-be/CLAUDE.md:156`). Python 3.12 (`.python-version`). CI uses uv `0.13.6` (`ci.yml:19`).
- Production validation (`app/core/config.py:163-236`). In `staging` and `production` the backend refuses:
  - a weak `SECRET_KEY`: a placeholder or fewer than 32 characters (`:169-173`);
  - a non-https `FRONTEND_URL` (`:174-175`);
  - any `BACKEND_CORS_ORIGINS` entry containing `localhost` (`:176-178`). The default is `["http://localhost:5173"]` (`:126`), and `env_ignore_empty=True` (`:98`) keeps that default when the value is empty, so production must set `BACKEND_CORS_ORIGINS=[]` explicitly;
  - a dev, weak or `SECRET_KEY`-equal `MEDIA_SIGNING_KEY`, and a non-https `MEDIA_LOCAL_BASE_URL` (`:223-235`).
- With `is_deployed`, `/docs` and `/redoc` are off (`app/main.py:40-41`). CORS middleware is added only when `BACKEND_CORS_ORIGINS` is non-empty (`:51`). The cookie is `Secure` outside `local` and `test` (`config.py:154-155`). The only allowed origin is `FRONTEND_URL`'s (`:160`).
- `/healthz` and `/readyz` are mounted outside `/v1` (`app/api/health.py`; `app/main.py:63`). `CONTRACTS.md:460-462`: "the proxy must not expose them publicly".
- Local media: links are `{MEDIA_LOCAL_BASE_URL}/v1/media/{key}?exp&sig`. The route reads files from `MEDIA_LOCAL_DIR`, which defaults to `var/media` and resolves from the repo root (`config.py:129-147`). It answers single ranges with 206 (`CONTRACTS.md:404-428`). Production with local storage is an accepted fallback (`my-list-be/CLAUDE.md:283`).
- The server never writes media. Only the content scripts and the dev seed write it (`my-list-be/CLAUDE.md:176`, `:227-231`, `:259-271`).
- `index.html:8-21` has an **inline theme script**. A CSP of `script-src 'self'` blocks it, so the page would flash the wrong theme. `src/lib/version-skew.ts` already reloads once on `vite:preloadError`. The share button uses the clipboard (`end-screen.tsx`).
- Both repos' CI pin actions to commit SHAs with `permissions: contents: read` (`my-list-be/.github/workflows/ci.yml:10-34`, `my-list-fe/.github/workflows/ci.yml:8-27`). Ubuntu runners have Docker preinstalled, so the image build needs no new third-party action.
- The platform repo has no remote and no CI (decision 78, `SPEC.md:92`). Its `.gitignore` excludes the two app folders.
- Deny rules block reading `**/.env` and `**/.env.*`, and block `cat`, `grep` and similar commands on `*.env*` (`.claude/settings.local.json:3-23`). New vars files therefore get names without `.env` in them, so agents and the owner can both read them.

## Clarifications & recommendations

No questions could be asked (this planner runs as a subagent). The brief's open points each get a default below (**R-1** onward). The five that need the owner's yes are repeated, recommended option first, under "Open questions".

- **R-1. Where each piece lives.**
  - The backend `Dockerfile` goes in `my-list-be/`.
  - The frontend `Dockerfile` and `deploy/Caddyfile` go in `my-list-fe/`. The frontend image *is* Caddy with the built SPA inside it, so the file that sets headers and CSP ships with the HTML it protects. It is also validated in the frontend CI on every PR, during the image build.
  - `compose.prod.yml`, `compose.admin.yml`, the vars files, the smoke script and the runbook go in the platform repo. Decision 59 (`SPEC.md:73`) puts the integration Compose file and the runbooks there.
  - Cost: the platform pieces get no CI until that repo has a remote. Their check is the local run plus `deploy/smoke.sh` (Open question 1).
- **R-2. One Caddy service with the frontend inside.** Compose services:
  - `web`: the frontend image, which is Caddy;
  - `backend`;
  - `migrate`: a one-shot service from the backend image;
  - `db`: `postgres:16-alpine`, as in dev and CI;
  - `redis`: `redis:7-alpine` with the dev file's flags.

  No static-file volume and no separate frontend server. Assets come out of Caddy and never pass through Python (`ARCHITECTURE.md:191`).
- **R-3. The local production-like run uses `https://dgc.localhost`, with `ENVIRONMENT=production`.**
  - Caddy gives any `*.localhost` name a certificate from its own internal CA, with no domain and no ACME. Chrome, Firefox and systemd-resolved send `*.localhost` to loopback. The smoke script uses `curl --resolve` so it does not depend on that.
  - The backend's production checks pass for real: https `FRONTEND_URL` and `MEDIA_LOCAL_BASE_URL`, a `Secure` cookie, `/docs` off, no CORS. The run therefore tests the production code paths, not `local` ones.
  - **Not plain `localhost`.** The `Secure` `session_id` cookie and the HSTS header would land on host `localhost`. That would break login on the dev server at `http://localhost:5173`: a browser will not let an http page overwrite a Secure cookie with the same name, and HSTS would upgrade the dev URL. A separate host name keeps the two apart (Open question 2).
  - The owner either accepts the certificate warning once, or imports Caddy's local root certificate (the runbook gives the command).
- **R-4. Headers and CSP, all in Caddy, on every response.**
  - `Content-Security-Policy`: `default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data: {$MEDIA_ORIGIN}; media-src 'self' {$MEDIA_ORIGIN}; font-src 'self'; connect-src 'self'; object-src 'none'; base-uri 'self'; form-action 'self'; frame-ancestors 'none'`.
  - `{$MEDIA_ORIGIN}` is a Caddy environment placeholder. It is empty with local storage and set to the bucket origin with S3 (`CONTRACTS.md:388-392`).
  - **No `'wasm-unsafe-eval'`.** Nothing uses WebAssembly yet. It arrives with the playable challenge (`ARCHITECTURE.md:171`, `:199`).
  - `style-src 'unsafe-inline'`, if needed at all: the implementer first tries `style-src 'self'` in the browser check. If a library injects a `<style>` tag (sonner is the likely one), the implementer adds `'unsafe-inline'` and names the library in the PR and in a Caddyfile comment (Open question 4).
  - `Strict-Transport-Security: max-age=31536000`, without `includeSubDomains` or `preload`. Those are one-way choices for a domain the owner has not bought yet. The launch runbook (PL-D2) adds `includeSubDomains` once the real domain is set (plan 07, P06-1); `preload` stays out until the site has run a few weeks on HTTPS.
  - TLS stated explicitly: `tls { protocols tls1.2 tls1.3 }` in the site block, no custom cipher list (plan 07, P06-3).
  - Request bodies under `/api/*` capped with `request_body { max_size 1MB }` (plan 07, P06-11; the largest legal body, a 500-entry merge, is about 200 KB). Smoke check 9 also posts a 2 MB body and expects 413.
  - Access logging stays off. If it is ever turned on, a log filter must drop the `token` query parameter, because `/reset-password?token=...` is an account-takeover token (plan 07, P06-14).
  - `X-Content-Type-Options: nosniff`; `Referrer-Policy: strict-origin-when-cross-origin`; `X-Frame-Options: DENY` (for old browsers; `frame-ancestors` is the real rule); `Cross-Origin-Opener-Policy: same-origin`.
  - `Permissions-Policy: camera=(), microphone=(), geolocation=(), payment=(), usb=()`. It leaves fullscreen and the clipboard alone, because the larger clue view (decision 77) and the share button may use them.
  - `Server` is removed from Caddy's own responses and from the backend's (`header_down -Server`).
  - The inline theme script moves to `public/theme-init.js`, loaded by a plain `<script src>` in `<head>`. It stays blocking, so there is still no theme flash. This avoids a CSP hash that would have to change with every edit of the script.
- **R-5. Caching and SPA routing in Caddy.**
  - `/assets/*` (hashed by Vite) gets `Cache-Control: public, max-age=31536000, immutable`. A missing asset is a real **404, never `index.html`**: an old tab must see the failed chunk so `vite:preloadError` fires, and must not get HTML served as JavaScript.
  - Every other static path (`index.html`, `favicon.svg`, `theme-init.js`, and any SPA route that falls back to `index.html`) gets `no-cache`.
  - `/api/*` responses with no `Cache-Control` of their own get `no-store`, through Caddy's set-if-absent form `?Cache-Control`. Explicit backend values pass unchanged (`public, max-age=300` on the game list and titles, `private, max-age=<n>` on media, `CONTRACTS.md:443-456`). This covers `/auth/me` and the other auth responses (`ARCHITECTURE.md:171`).
  - Compression (`encode zstd gzip`) only on static files, never on `/api`, so a media `Range` answer reaches the browser byte for byte.
  - Old assets are not kept across a release, because each image holds only its own build. `version-skew.ts` reloads once. The runbook notes this cost.
- **R-6. `/api` routing, health and the client address.**
  - `handle_path /api/*` strips `/api` and proxies to `backend:8000`, as the Vite proxy does in dev (`CONTRACTS.md:16`).
  - `/api/healthz` and `/api/readyz` answer 404 at Caddy, so the bare paths never reach the backend either (`MILESTONE-1.md:105`).
  - Caddy sets `X-Request-ID` to its own request UUID (`header_up`), replacing any value the client sent, so the id in Caddy's log matches the backend's (`CONTRACTS.md:129`).
  - The `Origin` and `Referer` headers pass through unchanged, as the CSRF check requires (`CONTRACTS.md:36-56`). The smoke script checks this.
  - uvicorn runs with `--proxy-headers --forwarded-allow-ips '*'`. That is safe only because the backend port is not published and only Caddy shares its network (R-7). The client address the backend sees is then the real one, which per-IP rate limits (M1-42, security plan) will need (`ARCHITECTURE.md:163`).
  - Caddy by default ignores `X-Forwarded-For` from untrusted clients and writes its own (check this in the docs at the pinned version).
- **R-7. Compose shape.**
  - Project `name: dgc-prod`, so its volumes never mix with the dev project's.
  - Two networks: `edge` (`web`, `backend`) and `data` (`backend`, `migrate`, `db`, `redis`). Caddy cannot reach Postgres or Redis. `data` is a plain bridge network, not `internal: true`, because Docker does not publish ports for a container that sits only on an internal network, and `compose.admin.yml` needs to publish one.
  - No `db` or `redis` port is published in `compose.prod.yml`. Only `web` publishes `80` and `443` (`443/udp` too, for HTTP/3).
  - Named volumes: `db_data`, `redis_data`, `caddy_data` and `caddy_config`.
  - Media is a **read-only bind mount** of `${MEDIA_HOST_DIR:-./var/prod-media}` to `/app/var/media`. The backend never writes media. Content arrives from the workstation (R-10), and backing up a plain folder is simple.
  - Settings are interpolated from one vars file passed with `--env-file`. Required values use `${VAR:?message}`, so a missing secret stops `docker compose` before anything starts.
  - `backend` and `migrate` share one YAML anchor for their environment.
  - Every service: `restart: unless-stopped` (except `migrate`), the `json-file` log driver with `max-size: 10m` and `max-file: 3` (`ARCHITECTURE.md:188`), and `security_opt: [no-new-privileges:true]`.
  - `backend` and `web` also get `cap_drop: [ALL]`, `read_only: true` and a `tmpfs` for `/tmp`.
  - The official Postgres and Redis images keep their default capabilities, because their entrypoints change file owners and users. This is a deliberate gap against `ARCHITECTURE.md:255`.
- **R-8. Migrations on deploy: the one-shot `migrate` service.**
  - It runs the backend image with `alembic upgrade head`, after `db` is healthy.
  - `backend` waits on `migrate: condition: service_completed_successfully`. A failed migration therefore stops the start, and the old containers keep running (`ARCHITECTURE.md:156`).
  - Separate migrator and app database roles are left out (see Coordination). The Postgres user is the database owner, so `CREATE EXTENSION pg_trgm` works (`my-list-be/CLAUDE.md:101`).
- **R-9. Health checks.**
  - `db`: `pg_isready`. `redis`: `redis-cli ping`.
  - `backend`: Python's `urllib` against `http://127.0.0.1:8000/readyz` (the slim image has no curl), interval 10 s, start period 20 s.
  - `web`: busybox `wget` against Caddy's admin endpoint `http://127.0.0.1:2019/config/`, which stays bound to the container's loopback.
  - `web` starts after `backend` is healthy.
  - The public uptime check is M1-52's job; the runbook names what it should poll.
- **R-10. Content in the local run: the dev seed, run from the host into the production stack.**
  - `seed_dev.py` refuses to run unless the `ENVIRONMENT` variable is `local`, the database host is on this machine and storage is local (`app/content/target.py:104-112`). An `ENVIRONMENT=local` seed run against the prod stack's Postgres meets all three. That Postgres is published on `127.0.0.1:5434` by `compose.admin.yml`, and the run sets `MEDIA_LOCAL_DIR` to the absolute path of the media bind folder.
  - The server itself stays in `production`. No backend change is needed.
  - The content database is never touched. Promoting real puzzles into the local stack is a runbook rehearsal for the owner, not a step of this plan.
- **R-11. Images in CI: build and three one-line checks, push nothing.**
  - One `docker` job in each repo's `ci.yml`, using the `docker build` that ships on the runner. No buildx action, no layer cache and no registry.
  - Backend checks: the image's user is not root (`id -u`); `import PIL` **fails** (no content libraries); `import app.main` succeeds with dummy `ENVIRONMENT=test` settings (catches a runtime import of a dev-only package).
  - Frontend checks: the Dockerfile runs `caddy validate` before the `USER` line, so a broken Caddyfile fails the build; the image's user is not root; `/srv/index.html` contains no `<script>` tag without `src` (a new inline script would silently break under the CSP).
- **R-12. Non-root Caddy on ports 80 and 443.**
  - The final stage adds a `caddy` user with uid `10001`, owning `/data` and `/config`.
  - Compose sets `sysctls: net.ipv4.ip_unprivileged_port_start=0` on `web`, so a non-root process may bind low ports inside its own network namespace. Docker 20.10+ already defaults to this; it is made explicit here.
  - **Known trap:** the official image gives `/usr/bin/caddy` a file capability (`setcap cap_net_bind_service`). With `cap_drop: ALL`, running such a binary as non-root fails with "operation not permitted". The Dockerfile removes it (`setcap -r`, from `libcap`, installed and used in the build stage).
  - Not chosen: high internal ports (8080/8443). Caddy's automatic HTTP-to-HTTPS redirect could then carry the internal port, and ACME needs more config.
- **R-13. Frontend build stage on `node:24-slim` (glibc), not Alpine.** Node 24 matches CI. The lockfile was made on glibc, and npm has a known gap with platform-specific optional packages (rolldown, lightningcss, Tailwind's oxide) on musl. The stage runs `npx vite build`, not `npm run build`: the CI `build` job already type-checks, and `tsc -b` would also type-check `e2e/`.
- **R-14. Backend image.**
  - Build stage: `python:3.12-slim` with the uv binary copied from `ghcr.io/astral-sh/uv:0.13.6`. It runs `uv sync --locked --no-default-groups` with `UV_COMPILE_BYTECODE=1` and `UV_LINK_MODE=copy`, and a cache mount for the uv cache (the uv Docker guide, `ARCHITECTURE.md:235`).
  - Final stage: the same base, the `.venv`, `app/`, `alembic.ini` and `scripts/`. `scripts/` is there so the buffer check can run on the server for M1-52 (`my-list-be/CLAUDE.md:249-256`).
  - It runs as user `app` (uid `10001`) with `PYTHONDONTWRITEBYTECODE=1`. `/app/var/media` is created in the image so the mount point exists.
  - Command: `uvicorn app.main:app --host 0.0.0.0 --port 8000 --workers 2 --proxy-headers --forwarded-allow-ips '*' --timeout-graceful-shutdown 20`, with Compose's `stop_grace_period: 30s` (`ARCHITECTURE.md:163`).
  - Base images are pinned by tag plus digest (`ARCHITECTURE.md:255`). The implementer looks the digests up. Dependabot (M1-53) keeps them current later.
  - `.dockerignore`: `.env`, `.env.*`, `.venv`, `var/`, `tests/`, `.git`, `.github`, `.claude`, caches, `specs/`, `openapi/`, `scripts/seed_media/`. The `.env` lines are a security rule: the image must never contain a developer's secrets.
- **R-15. Vars files without `.env` in their names.**
  - `deploy/localhost.vars`, committed: the dummy values for the `dgc.localhost` run. Its secrets are 40-character strings that say "local only, not a secret", so they pass the length check (`config.py:21-22`). The file header and the runbook say never to deploy them.
  - `deploy/production.vars.example`, committed: every key with `CHANGE_ME` placeholders, which the backend rejects because they are too short. Each key has a one-line comment with the command that generates its value.
  - On a server, the real file lives outside the repo, root-owned and mode 600 (`ARCHITECTURE.md:93`).
  - Neither name matches the deny patterns, so agents can read and write them.
- **R-16. Image builds on the server for the first launch.** The runbook's first launch clones the three repos on the server and runs `docker compose build`, so no registry is needed. Pushing to a registry (GHCR) and pulling by digest is M1-52's deploy workflow (`ARCHITECTURE.md:154`). The brief rules out a push in this plan.
- **R-17. Media storage at launch: the server's disk, mirrored from the workstation.**
  - With `MEDIA_STORAGE=local`, `promote_puzzles.py` writes files into the `MEDIA_LOCAL_DIR` of whatever machine runs it, which is the owner's workstation (`specs/04-phase-3-content.md:35`).
  - The runbook's flow: promote and schedule from the workstation through an SSH tunnel to the server's Postgres (`compose.admin.yml` publishes it on the server's loopback only), with `MEDIA_LOCAL_DIR` set to a workstation mirror folder. Then `rsync` the mirror to the server's media folder.
  - The buffer check, run on the server (M1-52), reports `missing_file` if an rsync was forgotten.
  - S3 (decision 62, `SPEC.md:76`) needs no rsync, but costs money and needs the AC-72c check first (Open question 3).
- **R-18. A smoke script, not a test suite.** `deploy/smoke.sh` (bash, `set -euo pipefail`, curl) runs 11 numbered checks against the running stack. Each check maps to one Caddyfile or Compose rule and fails when that rule is removed (list under PL-D1). The browser check for CSP violations is a one-off by the implementer, not committed (Open question 5).

**Coordination with the security plan.** This plan owns:
- every response header and the CSP (R-4);
- the Caddyfile and Compose themselves;
- TLS and the HTTPS redirect;
- the trusted-proxy setup that gives the backend the real client address (R-6);
- hiding the health endpoints;
- container hardening (non-root, read-only, dropped capabilities, no published data ports, the two networks);
- `.dockerignore` keeping `.env` out of the images.

Left to the security plan:
- rate limits (M1-42), which can rely on the client address from R-6;
- a `__Host-` cookie prefix (a boundary change);
- Redis AUTH and separate database roles (migrator and app), each a later edit of `compose.prod.yml` and the vars files;
- a CSP `report-to` endpoint;
- XSS, SQL injection, open redirect, enumeration, SSRF and session reviews of app code;
- dependency and secret scanning (M1-53).

If the security plan needs a header changed, it edits `my-list-fe/deploy/Caddyfile` after FE-D1 merges. It never adds headers in the backend, so there is one owner per header.

## Execution mode

- **Owner's choice (already decided, not asked again):** one `implementer` per PR, then `plan-verifier`; the owner merges. Commits and PRs only when the owner asks. The platform repo has no remote, so its "PRs" are local commits on a branch that the owner merges.
- **Extra passes (owner's brief: code review high and test-writer for risky PRs):**
  - BE-D1: `plan-verifier` only. No migration and no route; the image checks run in CI.
  - FE-D1: **code-review high**. The Caddyfile is the security edge: headers, CSP, routing and caching.
  - PL-D1: **code-review high**, then **test-writer**, which checks only that each smoke check can fail (one mutation per check). It adds no checks.
  - PL-D2: `plan-verifier` only. It is documentation.
- **Paired wave:** BE-D1 and FE-D1 share no files and no code dependency, so they run together. Scratch prefixes: `m140be_` and `m140fe_`. Never run a scratch script another agent wrote. PL-D1 builds both images, so it waits for both merges.
- **Test budget:** the 3 backend image checks, the 3 frontend image checks (R-11) and the 11 smoke checks (R-18). No pytest or Vitest tests are added, because no app logic changes. The theme script moves unchanged, and the e2e suite still loads it on every page.

## Order and estimates

Agent minutes are estimates, calibrated on Phases 1 to 3 and M1-50. Owner review time is separate.

| Step | PR | Repo | Waits for | Implementer | Checks | Agent total | Owner review |
|---|---|---|---|---|---|---|---|
| wave 1 | **BE-D1** Backend Dockerfile and CI image build | BE | nothing | 20 | plan-verifier 5 | ~25 min | 10 min, plus one CI run (~3 min wall clock) |
| wave 1 | **FE-D1** Frontend image with Caddy, Caddyfile, theme script out of `index.html`, CI image build | FE | nothing (runs alongside BE-D1) | 35 | plan-verifier 8, code-review high 10 | ~53 min | 20 min, plus one CI run (~4 min) |
| wave 2 | **PL-D1** `compose.prod.yml`, admin override, vars files, smoke script, the local run | PL | BE-D1 and FE-D1 merged | 45 | plan-verifier 10, code-review high 10, test-writer 12 | ~77 min | 20 min review, plus 15 min to try the local run |
| wave 3 | **PL-D2** Launch runbook, docs, decision 79 | PL | PL-D1 merged | 15 | plan-verifier 4 | ~19 min | 15 min |

Total: about 3 hours of agent time, mostly in two waves, and about 1.5 hours of owner time. `MILESTONE-1.md:105` gives 1.5 days of human-equivalent work; this plan does not change that figure. If a first CI image build fails where the local build passed, the fix goes back to the same implementer as a second round (budget ~10 min).

## Modules affected

| Where | Why | PR |
|---|---|---|
| `my-list-be/Dockerfile`, `.dockerignore` (new) | Multi-stage, runtime-only, non-root image (R-14) | BE-D1 |
| `my-list-be/.github/workflows/ci.yml` | New `docker` job: build and three checks (R-11) | BE-D1 |
| `my-list-be/CLAUDE.md`, `README.md` | Replace "the repo has no Dockerfile yet" (`CLAUDE.md:156`). Add a short "Docker image" note: what is in it, what is left out, the user, the command, and that Compose lives in the platform repo | BE-D1 |
| `my-list-fe/Dockerfile`, `.dockerignore` (new) | `node:24-slim` build, then Caddy with `/srv` and the Caddyfile, non-root (R-12, R-13) | FE-D1 |
| `my-list-fe/deploy/Caddyfile` (new) | R-4, R-5, R-6 | FE-D1 |
| `my-list-fe/index.html`, `public/theme-init.js` (new) | The theme script moves out (R-4) | FE-D1 |
| `my-list-fe/.github/workflows/ci.yml` | New `docker` job (R-11) | FE-D1 |
| `my-list-fe/.prettierignore` | Only if Prettier tries to format `deploy/Caddyfile` | FE-D1 |
| `my-list-fe/CLAUDE.md`, `README.md` | `:35` (`public/` now holds the theme script too); a short "Production image" section: the Caddyfile owns every header and the CSP, no inline scripts, `/assets` immutable and the rest no-cache, and changes to headers go here (the coordination rule) | FE-D1 |
| `compose.prod.yml`, `compose.admin.yml` (new, platform) | R-2, R-7 to R-10 | PL-D1 |
| `deploy/localhost.vars`, `deploy/production.vars.example` (new, platform) | R-15 | PL-D1 |
| `deploy/smoke.sh` (new, platform) | R-18 | PL-D1 |
| `.gitignore` (platform) | `var/` (the local media bind folder) | PL-D1 |
| `CLAUDE.md` (platform) | Workspace layout: the new files and the one-line local run | PL-D1 |
| `CONTRACTS.md` | "API base and routing" (`:14-19`): the production proxy is Caddy (`my-list-fe/deploy/Caddyfile`), the site is same-origin, and `/api` is stripped. "Health" (`:460-462`): Caddy answers 404 for both paths. "Clue media" (`:388-392`): production with local storage uses `MEDIA_LOCAL_BASE_URL=https://<site>/api`, and the CSP takes the bucket origin from `MEDIA_ORIGIN` | PL-D1 (boundary rule: same pass) |
| `docs/runbooks/launch.md` (new, platform) | The launch runbook | PL-D2 |
| `MILESTONE-1.md`, `ARCHITECTURE.md`, `SPEC.md` | M1-40 status; a progress line; decision 79 with the owner's answers to the open questions below | PL-D2 |

Not touched: any file under `my-list-be/app/`, `my-list-be/tests/`, `my-list-fe/src/`, `src/api/generated/`, `e2e/`, `e2e.yml`, the content database, and every `.env` file.

## Facts found (file:line)

- Allowed origin in production: only `FRONTEND_URL`'s (`config.py:157-161`; `CONTRACTS.md:42-45`). The Vite proxy keeps `Origin` (`my-list-fe/vite.config.ts:20-22`), and Caddy's `reverse_proxy` must too.
- The `/v1` routes and health endpoints sit at the backend root (`app/main.py:63-64`). The frontend calls `/api/v1/...` (`my-list-fe/CLAUDE.md`, "This repo").
- Media links in production with local storage: `https://<site>/api/v1/media/<key>?exp&sig`, `private, max-age=<n>`, `nosniff`, and 206 for a single range (`CONTRACTS.md:404-428`; `my-list-be/CLAUDE.md:278-280`).
- Redis flags to copy: `--appendonly yes --appendfsync everysec --maxmemory-policy noeviction` (`my-list-be/docker-compose.yml:19`; `ARCHITECTURE.md:165`).
- The seed's guards: `target.py:52-89` (`check_target`) and `:104-112` (`refusal_reason`). The seed refuses when `CI` is set (`:42-43`, `:66-67`).
- Production promote commands and flow: `my-list-be/CLAUDE.md:260-264`. Image gate: `target.py:92-101`, `my-list-be/CLAUDE.md:267`. Gate value: decision 73 names itself (`SPEC.md:87`), and also says it is revisited "before any real public launch".
- A non-local target skips the database-host check, so an SSH tunnel on `localhost` works for promote to production (`target.py:76-88`). Source and target on the same host but different ports count as different servers (`my-list-be/CLAUDE.md:266`).
- Pinned CI actions to reuse: `actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1` (both repos).

## Architectural constraints

- Platform: a boundary change updates the backend, the frontend and `CONTRACTS.md` in one pass. Use `localhost`, never `127.0.0.1` (root `CLAUDE.md`, "Working across both repos"). The `dgc.localhost` host name (R-3) is a separate site and does not touch the dev rule.
- `ARCHITECTURE.md:51`: same origin, with no per-environment URL in the bundle. The image is built once with no `VITE_*` values.
- `ARCHITECTURE.md:255`: non-root, slim, digest-pinned bases; read-only root filesystem; `cap_drop: ALL`; `no-new-privileges`; health checks; no published database ports. The deviations are listed in R-7 (the official data images).
- `my-list-be/CLAUDE.md:156`: the server image installs runtime dependencies only.
- `my-list-be/CLAUDE.md:227`, `:165`: the seed deletes the game's puzzles, so it never targets the content database (`daily_game_challenge_content`). R-10 targets only the prod stack's throwaway local database.
- `my-list-fe/CLAUDE.md:125`: comments only where the reason is not obvious from the code.
- Workflows: every third-party action pinned to a full SHA with the version in a comment, and `permissions: contents: read` (both `ci.yml` files).
- Owner rule: agents never read `.env` files (`.claude/settings.local.json`). R-15's names avoid the pattern.

## Approach

Every PR branches from a fresh `main` (`m1-40-be-docker`, `m1-40-fe-docker`, `m1-40-compose`, `m1-40-runbook`). Check every Docker, Caddy, Compose and uv detail against the docs of the pinned version (`docs` skill), not from memory. That covers in particular: Caddy `handle_path`, `header` with `?` and `-`, `try_files`, `encode`, env placeholders, `caddy validate`, the internal CA for `.localhost`, and `X-Forwarded-For` handling; Compose `depends_on` conditions, `sysctls` and `--env-file` interpolation; and the uv Docker guide.

### BE-D1. Backend Dockerfile and CI image build

1. `.dockerignore` as in R-14.
2. `Dockerfile`: two stages as in R-14. Create the user and `/app/var/media` before `USER`. Set `EXPOSE 8000` and the uvicorn command as `CMD`, so `migrate` can override it with `alembic upgrade head`. No `HEALTHCHECK` in the image, because Compose owns health checks (R-9).
3. `ci.yml`: job `docker` on `ubuntu-latest` with `timeout-minutes: 10`. Steps:
   - checkout (pinned SHA);
   - `docker build -t dgc-backend:ci .`;
   - one step with the three checks of R-11: `test "$(docker run --rm dgc-backend:ci id -u)" != 0`; `! docker run --rm dgc-backend:ci python -c "import PIL"`; `docker run --rm -e ENVIRONMENT=test -e DATABASE_URL=postgresql+asyncpg://u:p@db/x -e SECRET_KEY=ci-only-secret-key-not-used-anywhere-0000 dgc-backend:ci python -c "import app.main"`.
4. Docs: `CLAUDE.md:156` gets a new last sentence: "`Dockerfile` syncs that way; CI's `docker` job checks the image is non-root and has no Pillow." Add a short "Docker image" paragraph under Commands. Add one README line.

Mutations, each run once locally and reverted:
- delete `USER app`: the `id -u` check goes red;
- change the sync to plain `uv sync --locked`: the `PIL` check goes red;
- add `import httpx` at the top of `app/main.py`: the import check goes red.

### FE-D1. Frontend image with Caddy

1. `public/theme-init.js`: the body of `index.html:9-20`, unchanged apart from dropping the `<script>` wrapper. `index.html` gets `<script src="/theme-init.js"></script>` in the same place. It must not use `type="module"` (modules are deferred and would flash) and must not be `async`.
2. `deploy/Caddyfile`, in this order:
   - Global options: `email {$ACME_EMAIL}` (may be empty), and `admin` left on its default loopback address.
   - One site block for `{$SITE_ADDRESS}`. In it, a `header` block for every response with R-4's headers, CSP included, plus `-Server`.
   - `@health` matching `/api/healthz*` and `/api/readyz*`, which responds 404.
   - `handle_path /api/*`: `reverse_proxy {$BACKEND_UPSTREAM:backend:8000}` with `header_up X-Request-ID {http.request.uuid}` and `header_down -Server`, plus `header ?Cache-Control "no-store"`.
   - A final `handle` with `root * /srv` and `encode zstd gzip`. `/assets/*` gets the immutable header and a plain `file_server`, so a miss is 404. Everything else gets `try_files {path} /index.html`, `Cache-Control "no-cache"` and `file_server`.
   - Short comments only where the reason is not obvious: why a missing asset is a 404, why `/api` is not compressed, why `?Cache-Control`, and where `{$MEDIA_ORIGIN}` comes from.
3. `.dockerignore`: `node_modules`, `dist`, `.git`, `.github`, `.claude`, `.e2e`, `test-results`, `playwright-report`, `.env`, `.env.*`, `*.local`.
4. `Dockerfile`:
   - Stage `build`: `node:24-slim` pinned by digest, then `npm ci` (with an npm cache mount), then `npx vite build`.
   - Stage `final`: `caddy:2-alpine` at the current 2.x minor, pinned by digest. Remove the file capability (R-12). Add user `caddy` with uid `10001` owning `/data` and `/config`. Copy `dist/` to `/srv` and `deploy/Caddyfile` to `/etc/caddy/Caddyfile`.
   - Then `RUN SITE_ADDRESS=localhost caddy validate --config /etc/caddy/Caddyfile`. If validate at that version needs network access or writes outside `/data`, use `caddy adapt` with its validate flag and say so in the PR.
   - Then `USER caddy`, `EXPOSE 80 443 443/udp`, and the image's default `CMD`.
5. `ci.yml`: job `docker` as in BE-D1. Build `dgc-web:ci` (this runs `caddy validate`), then check that `id -u` (run with `--entrypoint id`) is not 0. Then copy `/srv/index.html` out with `docker create` and `docker cp`, and fail if it contains a `<script` tag with no `src=`.
6. Docs as in Modules affected.

Mutations, each reverted:
- put a typo in a Caddyfile directive: the build fails at validate;
- delete `USER caddy`: the `id -u` check goes red;
- put the inline theme script back: the index check goes red.

The e2e suite (dev server) still passes without changes, which shows `theme-init.js` loads.

### PL-D1. Production Compose, local run and smoke script

1. `compose.prod.yml` (`name: dgc-prod`) as in R-2 and R-7 to R-9.
   - `web` builds `./my-list-fe` and `backend` builds `./my-list-be`. Both also get `image: dgc-web:local` and `dgc-backend:local`, so `migrate` reuses the backend image without a second build.
   - The backend and migrate environment: `ENVIRONMENT`, `DATABASE_URL` (built from `POSTGRES_PASSWORD`, host `db`, database `daily_game_challenge`), `REDIS_URL=redis://redis:6379/0`, `SECRET_KEY`, `MEDIA_SIGNING_KEY`, `FRONTEND_URL`, `BACKEND_CORS_ORIGINS=[]`, `MEDIA_STORAGE`, `MEDIA_LOCAL_BASE_URL`, and the S3 keys passed through when set.
   - The `web` environment: `SITE_ADDRESS`, `ACME_EMAIL`, `MEDIA_ORIGIN`.
   - Postgres: `POSTGRES_USER=dgc`, `POSTGRES_DB=daily_game_challenge`, `POSTGRES_PASSWORD`.
2. `compose.admin.yml`: an override that only publishes `db` on `127.0.0.1:${DB_ADMIN_PORT:-5434}:5432`. A header comment says: for seeding the local run, and on a server for promote through an SSH tunnel. Never on `0.0.0.0`.
3. `deploy/localhost.vars`:
   - `SITE_ADDRESS=dgc.localhost`, `FRONTEND_URL=https://dgc.localhost`, `MEDIA_LOCAL_BASE_URL=https://dgc.localhost/api`;
   - `ENVIRONMENT=production`, `MEDIA_STORAGE=local`, `MEDIA_ORIGIN=` (empty);
   - `POSTGRES_PASSWORD` as hex, and dummy `SECRET_KEY` and `MEDIA_SIGNING_KEY` that differ, are at least 32 characters, and contain `local-only-not-a-secret`.

   `deploy/production.vars.example`: the same keys with `CHANGE_ME`, plus the generator commands in comments: `openssl rand -hex 32` for each secret (hex, so `DATABASE_URL` needs no escaping).
4. `deploy/smoke.sh <site> [<https port>]`. Defaults: `dgc.localhost` and `443`. It copies Caddy's local root certificate out of the `web` container into a temp folder for `--cacert`. On a real domain a flag skips that step. Every request uses `--resolve`. Checks, each printed as `ok N` or `FAIL N: <what>`, with exit 1 on any failure:
   1. `GET /` is 200 with `Cache-Control: no-cache` and the exact CSP string of R-4 (with `MEDIA_ORIGIN` empty).
   2. The same response has `Strict-Transport-Security`, `X-Content-Type-Options: nosniff`, `Referrer-Policy`, `Permissions-Policy`, `X-Frame-Options: DENY`, and no `Server` header.
   3. One `/assets/*.js` file named in `index.html` is 200 with `public, max-age=31536000, immutable`.
   4. `/assets/does-not-exist.js` is 404 and is not HTML.
   5. `/games/game-guesser/2020-01-01` (an SPA route) is 200 with `index.html` and `no-cache`.
   6. `/api/healthz` and `/api/readyz` are 404.
   7. `GET /api/v1/clock` is 200 JSON with `Cache-Control: no-store` and an `X-Request-ID`.
   8. `http://<site>/` redirects (308) to `https://<site>/` with no port in `Location` (skipped when a custom https port is given).
   9. `POST /api/v1/auth/login` with a JSON body for an unknown email: `Origin: https://<site>` gets 401, and `Origin: https://evil.example` gets 403 `csrf_origin_mismatch`. This shows Caddy keeps `Origin`.
   10. `POST /api/v1/auth/register` with a random email: its `Set-Cookie` has `Secure`, `HttpOnly` and `SameSite=Lax`.
   11. Today's puzzle view (`/api/v1/games/game-guesser/puzzles/today`) gives a step-1 media URL under `https://<site>/api/v1/media/`. `Range: bytes=0-1` on it is 206 with `Content-Range: bytes 0-1/<size>`, exactly 2 bytes and no `Content-Encoding`. If there is no puzzle, this fails with "seed the stack first".
5. Local run, done by the implementer and written into the platform `CLAUDE.md` and the runbook's "Try it on this laptop" section:
   - `mkdir -p var/prod-media`
   - `docker compose -f compose.prod.yml -f compose.admin.yml --env-file deploy/localhost.vars up -d --build`
   - wait for `docker compose ... ps` to show everything healthy and `migrate` exited 0
   - seed (R-10), from `my-list-be`: `CI= ENVIRONMENT=local DATABASE_URL=postgresql+asyncpg://dgc:<POSTGRES_PASSWORD from localhost.vars>@localhost:5434/daily_game_challenge SECRET_KEY=<dummy from localhost.vars> MEDIA_STORAGE=local MEDIA_LOCAL_DIR="<abs path>/var/prod-media" uv run --no-sync python scripts/seed_dev.py`
   - `deploy/smoke.sh`
   - stop with `docker compose -f compose.prod.yml --env-file deploy/localhost.vars down`; add `-v` to also drop the data.
6. Browser check (one-off, not committed; Open question 5). Open `https://dgc.localhost` in Chromium (a scratch Playwright script with `ignoreHTTPSErrors`, or the `run` skill). Collect `securitypolicyviolation` events and console errors while doing these:
   - load the game as a guest, skip to step 6 and see the clip play;
   - open the larger clue view;
   - use the share button on the end screen;
   - register;
   - switch to Russian;
   - open the archive.

   The result must be zero violations, no theme flash on reload in dark mode, and every font loaded from `/assets`. Settle `style-src` here (R-4) and put the outcome in the commit message.
7. `CONTRACTS.md` edits (Modules affected). Platform `CLAUDE.md`: list `compose.prod.yml`, `compose.admin.yml` and `deploy/` in "Workspace layout", plus the local run command.

### PL-D2. Launch runbook and docs

`docs/runbooks/launch.md`, short, with numbered steps and owner actions marked "(owner)". Nothing in it is run by this plan.

1. **Try it on this laptop.** The PL-D1 local run, how to trust Caddy's local root certificate (`docker compose cp web:/data/caddy/pki/authorities/local/root.crt .`, then import it into the browser), and what the first visit looks like without seeded content.
2. **What a launch needs** (owner, when ready; D3 at `MILESTONE-1.md:32` and decision 62):
   - one small x86 VPS with 2 vCPU and 4 GB. ARM (Hetzner CAX) needs a test build first (R-13);
   - a domain with an A/AAAA record;
   - a firewall allowing only 22, 80 and 443 (Docker publishes ports past ufw, which is why nothing but `web` is published);
   - key-only SSH;
   - automatic security updates;
   - Docker Engine with the Compose plugin.
3. **Secrets.** Copy `deploy/production.vars.example` to `/etc/dgc/production.vars` (root-owned, 600) and fill it with `openssl rand -hex 32` values: `SITE_ADDRESS` is the domain, `FRONTEND_URL=https://<domain>`, `MEDIA_LOCAL_BASE_URL=https://<domain>/api`, `ACME_EMAIL`. Never reuse `localhost.vars`.
4. **Preflight: `ENVIRONMENT=production` validation.** Run `docker compose ... run --rm --no-deps backend python -c "from app.core.config import settings"`. It prints the refusals of `config.py:163-236`, or nothing. List what the check covers (the secrets, https URLs, CORS, the media key) and what it does not: the database password strength, Redis access, and the DNS record.
5. **First start.**
   - Clone the three repos side by side (the platform repo needs a remote or an `scp` first).
   - Run `docker compose -f compose.prod.yml --env-file /etc/dgc/production.vars up -d --build`.
   - Caddy gets a certificate on the first request.
   - Run `deploy/smoke.sh <domain>` with the real-domain flag, minus check 11 until content exists.
6. **Content: promote from local (M1-24c).** The order follows `my-list-be/CLAUDE.md:260`:
   - On the server: `import_titles.py` and `manage_game.py`, run from the workstation through the tunnel.
   - **IGDB image gate (owner):** decision 73 allows IGDB screenshots for the learning project, but says it is revisited before any real public launch. Before setting `IGDB_IMAGES_CLEARED_BY` on the workstation for a public target, the owner records that review as a new decision, and the value names it.
   - Then promote and schedule with `ENVIRONMENT=production`, `--confirm-target production`, the tunnel `DATABASE_URL`, and `MEDIA_LOCAL_DIR` set to the workstation mirror (R-17).
   - Then `rsync -a` the mirror to the server's media folder.
   - Then run the buffer check in the backend container.
7. **Backups (built by M1-52).** Nightly `pg_dump -Fc` from the `db` container, encrypted (age or gpg), copied off the server to another provider. The media folder is copied too. It can also be rebuilt by re-running promote from the workstation, whose content database and media folder are a second copy. Redis is not backed up, so losing it only logs users out. One restore is tested before launch (`ARCHITECTURE.md:173`).
8. **Updating.** `git pull` in both app repos, then `up -d --build`. `migrate` runs first and a failed migration stops the start. Old asset files disappear with the old image, and open tabs reload once (`version-skew.ts`). Rollback means checking out the previous commit and running `up -d --build`. It is safe only with expand-and-contract migrations (`ARCHITECTURE.md:156`).
9. **What M1-52 adds** (`MILESTONE-1.md:119`): GHCR push from CI and pull by digest instead of building on the server; GitHub Actions deploy over SSH with a required approval; staging as a second Compose project; a rehearsed rollback; the nightly encrypted backup with an off-site copy and a tested restore; an uptime monitor on `https://<domain>/` and `https://<domain>/api/v1/games` (`/readyz` stays hidden); the buffer check on a schedule with its alert.
10. **Before a real public launch, also:** M1-42 rate limits; M1-43 real email (the reset link is not logged in production, so password reset needs it); M1-45 error tracking; M1-46 legal pages; M1-51 load test; the security plan; `ARCHITECTURE.md:96`'s first-deploy checklist.

Also in PL-D2:
- `MILESTONE-1.md:105` status: done, with the files and the local run;
- an `ARCHITECTURE.md` progress line;
- decision 79 in `SPEC.md` already holds the owner's answers (recorded 2026-11-24 at planning); PL-D2 only amends it if the build changed one of them.

## Skills for implementer

Backend project skills: `my-list-be/.claude/skills/` (`fastapi-service-patterns`). Frontend: `my-list-fe/.claude/skills/` (React only). No project has a Docker, Compose or Caddy skill.

| Files | Load | Why |
|---|---|---|
| Every change | `shvab:karpathy-guidelines` | Small, surgical diffs. No app code changes in any PR |
| `my-list-be/Dockerfile`, `.dockerignore`, `ci.yml` | `docs` | **Gap:** no Docker or uv-in-Docker skill. Follow uv's Docker guide and Docker's docs at the versions used |
| `my-list-be/**` anything else | `fastapi-service-patterns` (read `SKILL.md`), for awareness only | No route or service changes. Note its test budget: no new pytest here |
| `my-list-fe/deploy/Caddyfile`, `Dockerfile`, `ci.yml` | `docs` | **Gap:** no Caddy skill. Every directive is checked against Caddy's docs at the pinned 2.x version |
| `my-list-fe/index.html`, `public/theme-init.js` | none | **Gap:** plain JavaScript, not React. Move it unchanged |
| `compose.prod.yml`, `compose.admin.yml`, `deploy/*` | `docs` | **Gap:** Compose spec and Caddy local CA paths from current docs |
| `CLAUDE.md` files, `README.md`, `CONTRACTS.md`, `docs/runbooks/launch.md`, `SPEC.md`, `MILESTONE-1.md` | `shvab:no-ai-slop` | The owner wants plain, short sentences |

`shvab:react-best-practices`, `shvab:react-testing-library`, `shvab:zod` and the React project skills do not apply: no component, hook, schema or unit test changes.

## Verification

**BE-D1**, in `/home/alexandr/Developer/MyList project/my-list-be`:
- `docker build -t dgc-backend:ci .` succeeds. The image is under about 250 MB (`docker image ls`); report the figure.
- The three checks of R-11, as in CI, pass. Each of the three mutations turns its own check red, then the mutation is reverted.
- `uv run ruff check . && uv run ruff format --check .` (nothing Python changes; this is a guard).
- After the owner opens the PR: CI's `docker` job is green and the other jobs are unchanged.

**FE-D1**, in `/home/alexandr/Developer/MyList project/my-list-fe`:
- `npm run lint`, `npm run format:check`, `npm run build`.
- `npm test` (no test changes; a guard for `index.html`).
- `docker build -t dgc-web:ci .` succeeds, including `caddy validate`. The three checks pass, and the three mutations each turn red, then are reverted.
- `npm run e2e`, with ports 8000 and 5173 free (else ask the owner): 15 passed. This shows the external theme script loads on the dev server.
- After the PR opens: `docker` and `e2e` jobs green.

**PL-D1**, in `/home/alexandr/Developer/MyList project`:
- Prerequisites: both app repos on a fresh `main` including BE-D1 and FE-D1, and ports 80, 443 and 5434 free (if not, ask the owner; never stop a process this run did not start).
- `docker compose -f compose.prod.yml --env-file deploy/localhost.vars config -q` passes. Then remove `SECRET_KEY` from a scratch copy of the vars file: `config` fails with the `:?` message.
- The local run of PL-D1 step 5: every service healthy, `migrate` exited 0, `deploy/smoke.sh` prints `ok 1` to `ok 11`.
- From the host: `nc -z localhost 6379` fails, and a connection to 5432 fails. Only 5434 on `127.0.0.1` answers, and only with the admin override.
- `docker compose ... exec backend id -u` and `... exec web id -u` both print `10001`.
- The browser check of step 6: zero CSP violations, with the result in the commit message.
- test-writer mutations, one per smoke check, each red and reverted: drop the CSP line (1); drop `-Server` (2); drop the immutable header (3); give `/assets` the SPA fallback (4); remove `try_files` (5); remove the `@health` block (6); remove `?Cache-Control` (7); force a non-default https port in the redirect (8); add `header_up Origin` set to the upstream (9); set `ENVIRONMENT=local` in a scratch vars copy (10); add `encode` to the `/api` handle, or else remove `:ro` and point `MEDIA_HOST_DIR` at an empty folder (11). The Caddyfile mutations are made in the frontend working tree and rebuilt with `--build`, then reverted (`git -C my-list-fe diff` empty at the end).
- `docker compose -f compose.prod.yml --env-file deploy/localhost.vars down -v` at the end, and `rm -rf var/prod-media`. Ask the owner first if they want to keep the stack running to try it.

**PL-D2:** a read-through by plan-verifier. Every command in the runbook names a file, service or flag that exists after PL-D1 (`grep` each one). No real domain, IP or secret appears. Nothing is run against a server.

## Risks

- **Caddy as non-root** (R-12). The file-capability trap and low-port binding are the two known failure points. The `id -u` checks and a healthy `web` container prove both are handled.
- **The CSP breaks a feature only a browser sees.** curl cannot see CSP violations. The one-off browser check covers today's pages. A later library that injects inline scripts or styles is caught only by the next manual check, unless Open question 5 (b) is taken.
- **The local CA certificate warning.** Expected on `dgc.localhost`. The runbook shows how to trust the root certificate. Never use `-k` in the smoke script, because the extracted root makes the TLS chain part of the check.
- **Build on the server.** A 2 vCPU box builds the frontend in a few minutes, and on ARM the npm optional-package gap may appear (R-13). Both go away with M1-52's registry images.
- **Media on the server's disk.** It is a single copy until M1-52's backups exist. The workstation's content database and media folder are the second copy (promote can repair lost files, decision 72).
- **Committed dummy secrets.** `localhost.vars` passes the length check. The runbook and the file header forbid deploying it, and its values carry `local-only-not-a-secret`. A check that refuses that marker in production is a one-line idea for the security plan, not added here.
- **Old tabs after an update** lose old chunks and reload once (R-5). That is accepted until M1-52 decides whether to keep old assets around.
- **`localhost` vs `dgc.localhost`.** A browser that does not resolve `*.localhost` needs a hosts entry. The runbook says so.

## Rollback

- Each app PR is one squash commit; revert it with a revert PR. Reverting FE-D1 restores the inline theme script and removes the image. Nothing in production depends on it yet.
- Platform commits are local. `git revert` them, then run `docker compose ... down -v` and remove `var/prod-media`.
- Nothing outside this laptop and the two repos' CI is created, so there is nothing else to undo.

## Open questions for the owner

**Answered 2026-11-24: the owner chose (a) on all five (SPEC.md decision 79).**

Each has a recommended option first. The plan follows it unless the owner says otherwise.

1. **Where the files live (R-1).** (a) **Recommended:** Dockerfiles in each app repo, the Caddyfile in the frontend repo (validated in its CI), and Compose, the vars files, the smoke script and the runbook in the platform repo. (b) Everything deploy-related in the platform repo, which gets no CI check until it has a GitHub remote.
2. **Host name of the local production-like run (R-3).** (a) **Recommended:** `https://dgc.localhost`, which keeps its Secure cookie and HSTS away from the dev server on `localhost:5173`. (b) `https://localhost`, which can block dev logins until the cookie is cleared.
3. **Media storage at launch (R-17).** (a) **Recommended:** the server's disk, with promote writing to a workstation mirror that is rsynced to the server. No extra service. (b) An S3 bucket (Hetzner Object Storage, about 6.49 euros a month, decision 62). No rsync, but it needs the AC-72c Range check and `MEDIA_ORIGIN` in the CSP.
4. **`style-src` (R-4).** (a) **Recommended:** try `'self'` only, and add `'unsafe-inline'` only if the browser check shows a library needs it, naming it. (b) Use `'unsafe-inline'` from the start, as `ARCHITECTURE.md:171` expected.
5. **Browser check against the production stack (R-18).** (a) **Recommended:** a one-off check by the implementer now, with a committed Playwright run against the Compose stack added when the e2e suite moves to the platform repo (decision 78). (b) Add a `prod-like` project to the frontend e2e suite now: about 25 more agent minutes, and a CI job that builds and starts the whole stack (several more minutes per run).
