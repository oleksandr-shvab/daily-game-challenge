# Security audit (45 Hacksplaining lessons) and hardening plan — Implementation Plan

Status: draft, 2026-11-24. Scope: an audit of both app repos against the 45 lessons of https://www.hacksplaining.com/lessons, then small PRs for the gaps and partials that plan 06 (Docker, Compose, Caddy) does not cover, M1-42 (rate limits) included. Line numbers were checked against backend `main` at `f156751` and frontend `main` at `9165fb8`. Plan 06 (`plans/06-m1-40-docker-production.md`) did not exist when this was written, so section "Plan 06 checklist" lists what it must contain; check it against that list once it lands.

## Source requirements

- The owner's brief (2026-11-24): every lesson gets one verdict based on code, not docs; gaps and partials outside plan 06 become small PRs with agent-minute and owner-review estimates; M1-42 is part of this plan and its limits are settings-driven so the e2e config can raise them.
- `MILESTONE-1.md:106` (M1-42: login, register, forgot-password and guess, Redis, `429` with `Retry-After`, values in settings). `MILESTONE-1.md:113` (M1-53: Dependabot, secret scan, `npm audit` triaged) is folded into PRs DEP-FE and DEP-BE below.
- Related, not done here: M1-43 real email and SPF/DKIM/DMARC (`MILESTONE-1.md:107`), M1-44 audit-log table (`:108`), M1-45 Sentry (`:109`), M1-52 uptime monitor and alerts (`:116`).
- Owner rules, not asked again: one implementer per PR, then plan-verifier, then the owner merges; tests must be able to fail and stay small; learning project (2026-11-20), so the simplest fix that really works.

## The audit: 45 lessons

Status values: **handled**, **partial**, **gap**, **plan 06** (covered by plan 06; the exact item is in "Plan 06 checklist", `P06-n`), **ops** (outside the code), **n/a** (not applicable). Paths without a repo prefix: `be:` is `my-list-be/`, `fe:` is `my-list-fe/`.

| # | Lesson | How it applies to our stack | Status | Evidence (file:line) | What to do |
|---|---|---|---|---|---|
| 1 | slop-squatting | Agents write the code and can add a package by a guessed name | partial | Lockfiles: `be:uv.lock`, `fe:package-lock.json`; CI installs only from them (`be:.github/workflows/ci.yml` `uv sync --locked`, `fe:.github/workflows/ci.yml` `npm ci`); actions pinned to SHAs (both `ci.yml`). No rule on adding a dependency in either `CLAUDE.md` (only the command, `be:CLAUDE.md:32`) | DEP-FE, DEP-BE: a written rule in both `CLAUDE.md` files (an agent never adds a dependency without the owner's go-ahead; the name comes from the tool's official docs, and the registry page and source repo are checked) |
| 2 | ai-bias-and-unreliability | No AI in the product. Agents write the code, which is checked by plan-verifier, owner review and tests that must be able to fail | n/a | No LLM client in either `pyproject.toml` or `package.json` | Nothing |
| 3 | ai-data-extraction-attacks | No LLM in the product, so there is no model to extract data from | n/a | Same as 2 | Nothing |
| 4 | ai-prompt-injection | No LLM in the product reads untrusted text | n/a | Same as 2 | Nothing |
| 5 | css-injection | No user-controlled CSS. Inline styles come only from numbers; the review page's stylesheet is a constant | handled | `fe:src/features/games/game-guesser/clue-sources.tsx:40-50`, `:59` (aspect ratio from numbers); `fe:src/features/games/stats/stats-dialog.tsx:224` (width from counts); `be:app/content/review/html.py` `STYLESHEET` constant | Nothing. P06-4 keeps `style-src` to `'self' 'unsafe-inline'` |
| 6 | cross-origin-resource-sharing | CORS only in dev (Vite on another port); production is same-origin | handled | Exact origin list with credentials, no wildcard: `be:app/main.py:51-59`; staging and production refuse `*`, `localhost` and `127.0.0.1` origins: `be:app/core/config.py:176-178`; an unset list in production falls back to the localhost default and is refused at start, so it fails closed | P06-15: production sets `BACKEND_CORS_ORIGINS=[]`, so the middleware is not added at all |
| 7 | broken-access-control | Progress, stats and merge belong to a user; hidden puzzles; signed media; the review page | handled | Every progress query filters on the session's user: `be:app/crud/progress.py:24-27`, `:105-112`; no route takes a user or progress id (`be:app/games/router.py`); stats and merge need `CurrentUser`: `router.py:257`, `:271`; merge never changes an existing game and replays guesses server-side: `be:app/games/service.py` `merge_progress` docstring; hidden puzzles are one 404: `be:CLAUDE.md` "Game domain"; media needs a valid HMAC and a visible puzzle: `be:app/media/service.py:47-58`; review page: Host and Origin check, form token, `local` only, binds 127.0.0.1: `be:app/content/review/app.py:1-14`, `:100`, `:173`, `be:scripts/review_puzzles.py:32`, `:56` | Nothing |
| 8 | click-jacking | The SPA could be framed by another site | plan 06 | No frame header anywhere in the SPA path today (the review page has its own: `be:app/content/review/app.py:62-76`) | P06-5 |
| 9 | command-execution | No shell or subprocess anywhere; video and images are handled in-process (PyAV, Pillow) | handled | `grep subprocess\|os.system\|shell=` over `be:app` and `be:scripts` finds nothing (only a README mention of ffmpeg run by hand, `be:scripts/seed_media/README.md:14`) | Nothing |
| 10 | csrf | Cookie session, so every unsafe request must prove its origin | handled | `Origin` (or `Referer`) must be exactly an allowed origin on every non-GET/HEAD/OPTIONS, and bodies must be JSON: `be:app/core/csrf.py:14-21`, `:42-69`; registered innermost: `be:app/main.py:47`; staging and production allow only `FRONTEND_URL`: `be:app/core/config.py:158-161`; `SameSite=Lax`: `be:app/auth/router.py:29`; no state change on GET (`be:app/games/router.py`, `be:app/media/router.py:34`) | P06-7: production must **not** send `Referrer-Policy: no-referrer`, or same-origin POSTs carry `Origin: null` and are refused (the review page hit this: `be:app/content/review/app.py:70-73`) |
| 11 | directory-traversal | Media served from disk by key; storage keys written by the scripts | handled | The key must be 64 hex characters before any path is built: `be:app/media/signing.py:14-18`, checked at `be:app/media/service.py:47-54`, path at `:60` and `be:app/media/storage.py:43-45`; the writer checks the key too (`be:app/media/writer.py` `_checked_key`, `:74`); not a regular file is refused: `service.py:66-67`. Review page files: `is_media_key` (`be:app/content/review/app.py` imports it) | Nothing |
| 12 | downgrade-attacks | TLS is terminated by Caddy | plan 06 | No TLS in the app (uvicorn speaks plain HTTP behind the proxy) | P06-3 |
| 13 | file-upload | No upload route. Media files come only from the local content scripts | n/a | `be:app/api/main.py` routes; no `UploadFile` or multipart anywhere | Nothing |
| 14 | information-leakage | Error bodies, `/docs`, server headers, `/readyz` | plan 06 | Code side done: 500s say only `internal_error`, the cause goes to the log: `be:app/core/errors.py:203-212`; validation errors never echo values: `errors.py:186`; `/docs` and `/redoc` off when deployed: `be:app/main.py:40-41`; no source maps in the Vite build (`fe:vite.config.ts` has no `build.sourcemap`). Left: uvicorn and Caddy send `Server`; `/readyz` names failed dependencies (`be:app/api/health.py:15-21`) | P06-9, P06-10, P06-18 |
| 15 | insecure-design | A guest's guess is answered with no stored state, so a script can try every title against today's puzzle with `previous: []` until one is `correct`; a missing `ENVIRONMENT` means `local` | partial | Guest guesses store nothing (`be:CLAUDE.md` "Guess (M1-12)"); the guess route has no limit: `be:app/games/router.py:200-223`; `ENVIRONMENT` default: `be:app/core/config.py:100` | RL (guess limit per IP makes trying a catalogue slow); CFG (no default). Accept the rest as a known limit of guest play (open question 4) |
| 16 | lax-security-settings | Settings decide cookie security, docs, origins and the reset-link log | partial | Strong validator: weak or placeholder secrets, http `FRONTEND_URL`, bad CORS origins and weak media keys are refused when deployed: `be:app/core/config.py:164-236`. But `ENVIRONMENT` defaults to `local` (`config.py:100`), and with it the cookie is not `Secure` (`:154-155`), `/docs` is on (`be:app/main.py:40-41`), extra origins are allowed (`config.py:158-161`) and the reset link is logged (`be:app/core/email.py:10-13`): a deploy that forgets the variable fails open | CFG: `ENVIRONMENT` has no default. P06-15, P06-16 for the containers |
| 17 | logging-and-monitoring | Who logged in, failed, reset or was refused | gap | Request id on every log line: `be:app/core/logging.py:6`, `be:app/core/request_id.py`; 500s logged: `be:app/core/errors.py:157-167`, `:203-212`. No line for a failed login, a reset, a password change, a CSRF refusal or a 429 (`be:app/auth/service.py` logs only revoke failures, `:76-77`, `:89-91`); no error tracker (M1-45) or alerts (M1-52) yet | LOG: security event lines with no email, password or token. M1-45 and M1-52 stay in the milestone |
| 18 | mass-assignment | Pydantic request schemas | handled | Request models name only what the client may set: `be:app/auth/schemas.py:9-16`, `:28`, `:47-52`; `be:app/games/schemas.py:101-107`, `:122-145`; no `model_dump()` into a model and no `setattr` from a request (the one `setattr`, `be:app/crud/title.py:59`, is the content scripts' fixed field list); `is_active` and `progress.is_test` are never in a request (`be:app/models/progress.py:54`) | Nothing |
| 19 | open-redirects | The login and register `redirect` parameter; the backend sends no redirects to the SPA | handled | Same origin, http(s) only, not an auth page, exactly one leading slash: `fe:src/features/auth/redirect.ts:23-48`, used by `fe:src/routes/login.tsx:12` and `fe:src/routes/register.tsx:11`; external links only http(s): `fe:src/features/games/game-guesser/source-link.ts:7-17` | Nothing (its ReDoS is row 23) |
| 20 | password-mismanagement | Hashing, length limits, reset tokens | partial | argon2id in a thread: `be:app/core/security.py:6`, `:23-28`; 8 to 128 on register and new passwords: `be:app/auth/schemas.py:11`, `:33-34`. Gaps: no `max_length` on the login password, `old_password` or the reset `token` (`schemas.py:16`, `:48`, `:52`), so a multi-megabyte password is hashed; reset tokens are stored in plain text as Redis keys (`be:app/crud/password_reset.py:17-26`), live 2 days (`:8`), and are read then deleted in two steps, so two parallel resets can both pass (`be:app/auth/service.py:66-73`) | AUTH: length caps, store the token's SHA-256, `GETDEL`, 1-hour lifetime |
| 21 | privilege-escalation | There are no roles yet; nothing a user sends can raise their rights | handled | `User` has no role column: `be:app/models/user.py:11-23`; no route changes `is_active`; the admin hook `is_test` is never set from a request (`be:app/models/progress.py:53-54`) | When roles arrive (SPEC section on admin MFA), plan them with their own tests |
| 22 | prototype-pollution | Guest records and settings read from `localStorage` | handled | Records parsed with `JSON.parse` then a Zod object, which drops unknown keys such as `__proto__`: `fe:src/features/games/guest-records.ts:18-31`, `:105-113`; language and theme are compared to fixed strings: `fe:src/i18n/language.ts:39-43`, `fe:src/hooks/use-theme.ts:11`; no deep merge of parsed data anywhere | Nothing |
| 23 | regex-injection | No regex is built from input. ReDoS: server patterns are anchored and bounded; one frontend pattern is quadratic | partial | Backend patterns: `be:app/core/request_id.py:8`, `be:app/games/schemas.py:13`, `:26`, `be:app/media/signing.py:14`, `be:app/media/ranges.py:13-19` (all linear). Frontend: `/\/+$/` on the decoded `redirect` path, `fe:src/features/auth/redirect.ts:18`; measured with Node 24: a 60,000-slash path takes about 1 s and the time grows with the square, so a crafted login link can freeze a victim's tab | REDIR: cap `redirect` at 2,048 characters before parsing and strip trailing slashes without a backtracking pattern |
| 24 | remote-code-execution | No `eval`, `pickle`, `yaml.load` or dynamic import of input | handled | Grep over `be:app`, `be:scripts` and `fe:src` finds no `eval(`, `new Function`, `pickle` (except a guard that refuses pickling, `be:app/content/seed.py:137`) or YAML | Nothing |
| 25 | session-fixation | The session id must change when privilege changes | partial | Login and register always mint a new token: `be:app/auth/service.py:37-50`; reset revokes every session: `:75`. But a password update keeps the current token (`:87`, `CONTRACTS.md:95-99` "no cookie changes"), and login leaves the browser's previous token alive in Redis (`be:app/auth/router.py:40-44`) | AUTH: update-password revokes all sessions and sets a new cookie; login and register delete the incoming token |
| 26 | sql-injection | Postgres through SQLAlchemy | handled | Only bound expressions; the one raw-looking call binds its value: `be:app/core/db.py:29-31`; search uses operators with bound parameters: `be:app/crud/title.py:149-173`; `text(` appears nowhere outside migrations | Nothing |
| 27 | ssl-stripping | First visit over http | plan 06 | The cookie is `Secure` when deployed (`be:app/auth/router.py:28`, `be:app/core/config.py:154-155`) and `FRONTEND_URL` must be https (`config.py:174-175`); the redirect and HSTS are Caddy's | P06-1, P06-2 |
| 28 | ssrf | The content scripts fetch from IGDB and Steam; the API fetches nothing | handled | One client: https only, five allowed hosts, no redirects, size cap, deadline: `be:app/content/fetch.py:18-31`, `:56-71`, `:78-98`; Steam playlist URLs checked again: `be:app/content/steam.py:122-146`; IGDB query text cannot add `sort`/`limit`/`fields`: `be:app/content/igdb.py:65`. The API signs S3 links locally, no request (`be:app/media/storage.py:88-105`) | Nothing |
| 29 | toxic-dependencies | npm and PyPI packages, GitHub Actions | gap | `npm audit` on 2026-11-24: 28 findings (1 critical `proxy-addr`, 11 high, 16 moderate), every one with a fix available, nearly all under the `shadcn` CLI, which is a runtime dependency (`fe:package.json` `dependencies`) although the app only imports its CSS (`fe:src/index.css:3`); runtime ones: `seroval` 1.6.4 (TanStack Router) and `follow-redirects` (axios, Node only). No Dependabot, no `npm audit` or `pip-audit` in CI (both `ci.yml`) | DEP-FE, DEP-BE (M1-53) |
| 30 | unencrypted-communication | Browser to Caddy, Caddy to the API, the app to S3 | plan 06 | S3 endpoint must be https when deployed: `be:app/core/config.py:215-216`; media base URL too: `:234-235`. Browser traffic is Caddy's | P06-1 to P06-3, P06-16 |
| 31 | user-enumeration | Register, login, forgot-password | partial | Login: one error for an unknown email, a wrong password and an inactive account, and a dummy hash for unknown emails: `be:app/crud/user.py:27-34`, `be:app/auth/service.py:45-49`, `be:app/core/security.py:9`. Forgot: one 202 text: `be:app/auth/router.py:68-71`; its timing differs only by two Redis writes and a log line today (`be:app/auth/service.py:57-62`). Register: 409 `email_already_registered` (`service.py:37-39`) and no hash on that path, so both the code and the timing say the email exists; accepted in `ARCHITECTURE.md:166` with "rate-limit it" | RL (limits on all three); M1-43 must send the email from the queue, not inline, or forgot-password gets a timing oracle (noted in Risks) |
| 32 | weak-session | Token entropy, cookie flags, lifetime | handled | 256-bit `secrets.token_urlsafe(32)`: `be:app/crud/session.py:12`; server-side store with TTL: `:11-20`; `HttpOnly`, `Secure` when deployed, `SameSite=Lax`, `Path=/`: `be:app/auth/router.py:21-30`; 14 days: `be:app/core/config.py:119`; revocation lists per user: `session.py:39-58` | Nothing (a `__Host-` prefix is optional, see recommendation R-9) |
| 33 | xml-bombs | No XML is parsed anywhere (Steam trailers are HLS text, not DASH). The image equivalent, a decompression bomb, is bounded | n/a | No `xml`, `lxml`, `ElementTree`, `defusedxml` or `DOMParser` in `be:app`, `be:scripts`, `fe:src` or `be:uv.lock`; HLS parsing: `be:app/content/steam.py:218-292`; downloads capped at 20 MB: `be:app/content/fetch.py:31`; Pillow keeps its default pixel limit (`MAX_IMAGE_PIXELS` is not changed anywhere) | Nothing |
| 34 | xml-external-entities | No XML | n/a | Same as 33 | Nothing |
| 35 | xss-dom | SPA rendering of server data and URL values | handled | No `dangerouslySetInnerHTML` or `innerHTML` in `fe:src`; i18n `escapeValue: false` is safe because React escapes text: `fe:src/i18n/index.ts:13`; the one `<Trans>` has no interpolated values: `fe:src/features/games/game-guesser/clue-sources.tsx:125-135`; links only http(s): `source-link.ts:15`; the reset token from the URL is only sent in a JSON body: `fe:src/routes/reset-password.tsx:15-17` | P06-4 as defense in depth |
| 36 | xss-reflected | The API returns JSON only; no server-side HTML from input | handled | Problem bodies are `application/problem+json` with `nosniff`: `be:app/core/errors.py:106-118`; media with `nosniff`: `be:app/media/router.py:20`, `:58`; the review page escapes every value: `be:app/content/review/html.py:69-71` | P06-6: `nosniff` on every response, success JSON included |
| 37 | xss-stored | IGDB names, franchises and source URLs are stored and shown | handled | React text rendering on the SPA; review page `esc` and `link_target`: `be:app/content/review/html.py:69-80`, plus a no-script CSP: `be:app/content/review/app.py:62-65` | Nothing |
| 38 | buffer-overflows | Python and TypeScript are memory-safe; native code is argon2, asyncpg and, in the local scripts only, Pillow and FFmpeg (PyAV) | handled | Decoders run only in the local scripts, on files from the five allowed hosts, capped at 20 MB: `be:app/content/fetch.py:18-31`; `av` and `pillow` are in the `content` group only (`be:pyproject.toml:31-33`) | DEP-BE keeps them updated |
| 39 | denial-of-service-attacks | Search, guesses, login hashing, body sizes | gap | Some bounds exist: `q` at most 100: `be:app/games/router.py:192-194`; `previous` at most 20: `be:app/games/schemas.py:89-98`; merge at most 500 entries: `:112`, `:144-145`; statement timeout: `be:app/core/db.py:54`. Missing: any rate limit (`CONTRACTS.md:85-86` admits it for forgot-password), any body size limit, and a length cap on the login password (row 20), so each login can cost an argon2 hash of an arbitrary size | RL (M1-42), AUTH (caps); P06-11 (body size) |
| 40 | dns-poisoning | The domain's DNS (not bought yet, D3) | ops | Nothing in code | Ops list O-1 |
| 41 | email-spoofing | Reset emails from our domain (M1-43), and spoofed mail in our name before that | ops | No sender yet: `be:app/core/email.py:8-15` | Ops list O-2; M1-43 |
| 42 | host-header-poisoning | Reset links and media links | handled | Built only from settings, never from `Host`: `be:app/auth/service.py:61` (`FRONTEND_URL`), `be:app/media/storage.py:38`, `:54` (`MEDIA_LOCAL_BASE_URL`, checked by `is_clean_base_url`, `be:app/core/config.py:48-58`); no `request.base_url` or `Host` read in `be:app` | P06-13: Caddy serves only the real host names |
| 43 | malvertising | No ads, no analytics (SPEC decision 13), no third-party script | n/a | `fe:index.html` loads only its own inline theme script and `/src/main.tsx` | Keep it so; Sentry (M1-45) will be the first third-party script, add its origin to the CSP then |
| 44 | subdomain-squatting | Records that point at things we may delete (object storage bucket, a staging host) | ops | Nothing in code | Ops list O-3 |
| 45 | xssi | JSON responses read by a cross-site `<script>` | handled | Every JSON response is an object, never a top-level array (checked over `be:openapi/openapi.json`); the cookie is `SameSite=Lax`, so a cross-site script tag carries no session (`be:app/auth/router.py:29`) | P06-6 (`nosniff`) |

**Counts:** handled 20, partial 7, gap 3, plan 06 5, ops 3, n/a 7 (total 45).

## Gaps and partials by severity

- **High**
  - Denial of service and brute force (rows 39, 15, 31): no rate limit on any route; login guessing, register spam, forgot-password floods (an email per request once M1-43 lands), and a guest script that tries every title until one is correct. PR **RL**.
- **Medium**
  - Toxic dependencies (29): 28 open npm advisories, 1 critical; no Dependabot or audit in CI. PRs **DEP-FE**, **DEP-BE**.
  - Logging and monitoring (17): no security events in the log. PR **LOG**.
  - Password mismanagement (20): plain-text reset tokens in Redis, 2-day lifetime, a double-use race, unbounded login password. PR **AUTH**.
  - Lax settings (16, 15): a missing `ENVIRONMENT` silently means `local`. PR **CFG**.
- **Low**
  - Session fixation (25): password update keeps the session id; login leaves the old token alive. PR **AUTH**.
  - User enumeration (31): register's 409 and its timing; accepted by design, limited by **RL**.
  - Regex ReDoS (23): crafted login link freezes the victim's own tab. PR **REDIR**.
  - Slopsquatting (1): no written rule for agents adding packages. PRs **DEP-FE**, **DEP-BE**.

## Plan 06 checklist

What `plans/06-m1-40-docker-production.md` must contain for rows 8, 10, 12, 14, 27, 30, 36, 39, 42, 45 of the table. Check it item by item.

- **P06-1 HSTS.** `Strict-Transport-Security: max-age=31536000; includeSubDomains` on every HTTPS response. No `preload` yet (a commitment that is slow to undo; add it once the site has run a few weeks on HTTPS).
- **P06-2 HTTP to HTTPS.** Caddy's automatic HTTPS stays on (no `auto_https off`, no plain `http://` site block that serves content); port 80 only redirects.
- **P06-3 TLS versions.** TLS 1.2 and 1.3 only (Caddy's default; state it with `protocols tls1.2 tls1.3` so a later edit cannot lower it). No custom weak cipher list.
- **P06-4 CSP** (from `ARCHITECTURE.md:171`, adjusted to the code today): `default-src 'self'; script-src 'self' 'sha256-<hash of the theme script>'; style-src 'self' 'unsafe-inline'; img-src 'self' data: <object storage origin>; media-src 'self' <object storage origin>; font-src 'self'; connect-src 'self'; object-src 'none'; base-uri 'self'; form-action 'self'; frame-ancestors 'none'`. The inline theme script is `fe:index.html:8-21`: hash it in the build or move it to a file. No `'wasm-unsafe-eval'` until the playable game exists (`MILESTONE-1.md:105`).
- **P06-5 Clickjacking.** `frame-ancestors 'none'` in the CSP plus `X-Frame-Options: DENY` for old browsers.
- **P06-6 nosniff.** `X-Content-Type-Options: nosniff` on every response (SPA, assets, API success JSON; the backend sets it only on errors and media).
- **P06-7 Referrer-Policy.** `strict-origin-when-cross-origin` (or `same-origin`). **Never `no-referrer`**: with it a browser sends `Origin: null` on same-origin POSTs, and the CSRF check refuses every login and guess (`be:app/content/review/app.py:70-73` documents the same effect on the review page).
- **P06-8 Permissions-Policy.** `camera=(), microphone=(), geolocation=(), payment=(), usb=()`.
- **P06-9 Server headers.** Caddy `header -Server`; uvicorn runs with `--no-server-header`.
- **P06-10 Hidden endpoints.** `/readyz` and `/healthz` are not routed from the internet; `ENVIRONMENT=production` turns `/docs` and `/redoc` off (`be:app/main.py:40-41`); `/openapi.json` may stay public (the repos are public).
- **P06-11 Body size.** `request_body { max_size 1MB }` for `/api/*` (the largest legal body, a 500-entry merge, is about 200 KB).
- **P06-12 Client IP for rate limits.** uvicorn runs with `--proxy-headers --forwarded-allow-ips=<Caddy's address on the Compose network>`, the API port is not published on the host, and Caddy sets `X-Forwarded-For` itself (it ignores a client's value unless `trusted_proxies` is set; keep it unset). Without this every user shares Caddy's address and PR RL's per-IP limits lock out everyone at once.
- **P06-13 Host names.** Site blocks only for the real names (apex and `www` redirect); no catch-all `:443` or `:80` block that proxies any `Host`.
- **P06-14 Access logs.** If Caddy logs requests, drop the `token` query parameter (`/reset-password?token=...` is an account-takeover token) with a log filter, or keep access logging off.
- **P06-15 Production environment.** `ENVIRONMENT=production`, `BACKEND_CORS_ORIGINS=[]`, real `SECRET_KEY` and `MEDIA_SIGNING_KEY` (different), no `--reload`.
- **P06-16 Internal services.** Postgres and Redis not published on the host; Redis with append-only and `noeviction` (`ARCHITECTURE.md:165`; eviction would also drop rate-limit counters); containers non-root (M1-40).
- **P06-17 Static files.** `index.html` `no-cache`, hashed assets immutable (M1-40); no `.map` files served.
- **P06-18 Error pages.** Caddy's own error responses (502 while the API restarts) carry no version or stack; the SPA already maps a non-JSON error body to `http_error` (`fe:src/lib/api-client.ts:81-91`).

## Ops list

- **O-1 DNS poisoning.** Turn on DNSSEC at the registrar if it offers it; add a CAA record that allows only the CA Caddy uses (`0 issue "letsencrypt.org"`, plus ZeroSSL if Caddy's fallback is kept); 2FA on the registrar account.
- **O-2 Email spoofing.** Before any email is sent: `v=spf1 -all` on the apex and `_dmarc` with `p=reject`, so nobody can send as the domain. With M1-43: SPF, DKIM and DMARC on the sending subdomain.
- **O-3 Subdomain squatting.** Keep a list of DNS records; delete a CNAME before deleting what it points at (object storage bucket, staging host); no wildcard records.
- **O-4 GitHub settings** (for rows 1 and 29): secret scanning with push protection and Dependabot alerts on both repos (the secret-scan part of M1-53).

## Clarifications & recommendations

No questions could be asked (this planner runs as a subagent). Judgment calls, each marked as a recommendation:

- **R-1. Rate limits without a new library.** A fixed window in Redis: `INCR` the key, `EXPIRE ... NX` with the window, in one pipeline; over the limit gives 429 with `Retry-After` from the key's TTL. About 30 lines in `app/core/rate_limit.py`, no new dependency (which also fits row 1). `MILESTONE-1.md:106` and `ARCHITECTURE.md:168` name the `limits` library; this departs from that (open question 1).
- **R-2. The limits** (counts in settings, windows in code). Keys are hashed where they hold an email (SHA-256 of the lower-cased email), so Redis holds no addresses. IPv6 addresses are keyed by their /64.

  | Rule | Route | Key | Default | Window | Setting |
  |---|---|---|---|---|---|
  | `login_ip` | `POST /v1/auth/login` | IP | 10 | 1 min | `RATE_LIMIT_LOGIN_PER_IP` |
  | `login_email` | `POST /v1/auth/login` | email hash | 10 | 15 min | `RATE_LIMIT_LOGIN_PER_EMAIL` |
  | `register_ip` | `POST /v1/auth/register` | IP | 10 | 1 hour | `RATE_LIMIT_REGISTER_PER_IP` |
  | `forgot_ip` | `POST /v1/auth/forgot-password` | IP | 10 | 1 hour | `RATE_LIMIT_FORGOT_PER_IP` |
  | `forgot_email` | `POST /v1/auth/forgot-password` | email hash | 3 | 1 hour | `RATE_LIMIT_FORGOT_PER_EMAIL` |
  | `guess_ip` | `POST .../guesses` | IP | 60 | 1 min | `RATE_LIMIT_GUESS_PER_IP` |
  | `search_ip` | `GET .../titles` | IP | 120 | 1 min | `RATE_LIMIT_SEARCH_PER_IP` |
  | `password_user` (recommendation) | `POST /v1/auth/update-password`, `POST /v1/auth/reset-password` (IP) | user id / IP | 10 | 1 hour | `RATE_LIMIT_PASSWORD_CHANGE` |

  The last row is beyond the brief: `update-password` checks the old password, so a stolen session could otherwise guess it without limit. Plus `RATE_LIMITS_ENABLED: bool = True`, which the backend test suite turns off in `conftest.py` and the rate-limit tests turn back on. The forgot-password per-email limit returns the same 202 when exceeded (a 429 there would tell an attacker the email was tried before, not that it exists, but a silent drop is simpler to reason about); every other rule answers 429. A per-email login limit lets someone lock a known email out for 15 minutes; accepted at this size.
- **R-3. Redis down: fail open.** If the limiter's Redis call raises, log it and let the request through. Sessions need Redis anyway, but guest search and guesses do not; a limiter must not be the thing that takes the site down.
- **R-4. Session on password update: revoke all, issue new.** `update_password` revokes every session of the user and creates a fresh one; the route sets the new cookie. Simpler than "revoke others, then rotate mine". Changes `CONTRACTS.md:95-99` (the FE needs no change: the cookie is httpOnly and set by the response).
- **R-5. Reset tokens: SHA-256 at rest, `GETDEL`, 1 hour.** The e2e reads the link from the log, which still has the raw token (`be:app/core/email.py:10-13`), so the suite is unaffected. 1 hour is the common choice (open question 3).
- **R-6. `ENVIRONMENT` required.** No default, so a deploy without it refuses to start. Every place that runs the backend already sets it (backend CI `ci.yml` env, the e2e `fe:e2e/support/backend-env.ts`); the owner's own `.env` needs `ENVIRONMENT=local` (agents cannot read or check it).
- **R-7. Security events in the normal log, not a table.** One `logger.info`/`warning` per event with a fixed `event=<name>` prefix and only the user id, never email, password or token. The audit table is M1-44; Sentry M1-45.
- **R-8. Guest answer oracle accepted.** Guest play stores nothing by design (AC-37), so a guest's guess must say whether it is right. The guess limit makes trying a few thousand titles take an hour per IP; accept the rest (open question 4).
- **R-9. No `__Host-` cookie prefix now.** It would make the cookie name differ between dev (http) and production and touch the e2e and docs; the cookie already has `Path=/`, no `Domain` and `Secure` when deployed, which is what the prefix enforces.
- **R-10. `shadcn` to devDependencies.** The app imports only `shadcn/tailwind.css` (`fe:src/index.css:3`), resolved at build time, so it does not need to be a runtime dependency; this removes most of the audit findings from the production install.

## Execution mode

- **Owner's choice (already decided):** one `implementer` per PR, then `plan-verifier`; the owner merges. Commits and PRs only when the owner asks.
- **Extra passes, by the owner's rule "any route or auth change":** `code-review` at `high` plus `test-writer` for **RL**, **AUTH**, **LOG** and **REDIR**. Plan-verifier only for **CFG**, **DEP-FE**, **DEP-BE**, **FE-RL**, **PL**.
- **Paired waves** only across repos (two PRs in one repo would both touch `config.py`, `CLAUDE.md` or `CONTRACTS.md`). Scratch prefixes in the shared scratchpad: `sec07<pr>_`; never run another agent's scratch script.

## Order and estimates

Agent minutes, calibrated on plan 05 (8 + 3 minutes for a one-test BE PR, 45 + 12 for the e2e suite). Owner review is separate.

| Wave | PR | Repo | Waits for | Implementer | Review high | test-writer | plan-verifier | Agent total | Owner review |
|---|---|---|---|---|---|---|---|---|---|
| 1 | **RL** Rate limits (M1-42) | BE (+ `CONTRACTS.md`) | nothing | 40 | 10 | 15 | 10 | ~75 min | 25 min |
| 1 | **DEP-FE** npm audit fixes, `shadcn` to dev, Dependabot, audit job, dependency rule | FE | nothing | 20 | none | none | 6 | ~26 min | 10 min |
| 2 | **FE-RL** e2e limits raised, API types regenerated | FE | RL merged | 5 | none | none | 2 | ~7 min | 3 min |
| 2 | **AUTH** Session rotation, reset tokens, length caps, `no-store` | BE (+ `CONTRACTS.md`) | RL merged | 35 | 10 | 12 | 10 | ~67 min | 20 min |
| 3 | **REDIR** Redirect length cap, no backtracking (+ API types if AUTH changed them) | FE | AUTH merged | 8 | 5 | 5 | 4 | ~22 min | 5 min |
| 3 | **LOG** Security event lines | BE | AUTH merged | 25 | 8 | 10 | 8 | ~51 min | 12 min |
| 4 | **CFG** `ENVIRONMENT` required | BE | LOG merged | 12 | none | none | 5 | ~17 min | 5 min, plus adding `ENVIRONMENT=local` to the owner's `.env` |
| 5 | **DEP-BE** Dependabot, `pip-audit` job, dependency rule | BE | CFG merged | 20 | none | none | 6 | ~26 min | 10 min |
| last | **PL** Milestone and architecture notes | PL | all | 5 | none | none | none | ~5 min | 5 min |

Total: about 5 hours of agent time, about 1 h 35 min of owner review, plus reviewing the first Dependabot PRs. RL is the `MILESTONE-1.md:106` row (0.8 days human-equivalent; not changed here).

## Modules affected

| Where | Why | PR |
|---|---|---|
| `my-list-be/app/core/rate_limit.py` (new) | The limiter (R-1 to R-3) and `TooManyRequestsError` handling | RL |
| `my-list-be/app/core/config.py` | Rate-limit settings (RL); no default for `ENVIRONMENT` (CFG) | RL, CFG |
| `my-list-be/app/core/exceptions.py`, `app/core/errors.py` | `TooManyRequestsError` (429, `too_many_requests`, already in `HTTP_STATUS_CODES`, `errors.py:52`) and a handler that adds `Retry-After`, like `range_not_satisfiable_handler` (`errors.py:170-180`) | RL |
| `my-list-be/app/auth/router.py`, `app/games/router.py` | Call the limiter; 429 in `responses=`; auth responses get `Cache-Control: no-store` (AUTH) | RL, AUTH |
| `my-list-be/app/auth/service.py`, `app/auth/schemas.py`, `app/crud/session.py`, `app/crud/password_reset.py` | R-4, R-5, length caps | AUTH |
| `my-list-be/app/auth/service.py`, `app/core/csrf.py`, `app/core/rate_limit.py` | Event lines | LOG |
| `my-list-be/tests/conftest.py`, `tests/test_rate_limit.py` (new), `tests/test_auth.py`, `tests/test_password_reset.py`, `tests/test_password_update.py`, `tests/test_config.py`, `tests/test_security_events.py` (new) | Tests below | RL, AUTH, LOG, CFG |
| `my-list-be/openapi/openapi.json` | Regenerated (429 responses; `maxLength` on three fields) | RL, AUTH |
| `my-list-be/.github/dependabot.yml` (new), `.github/workflows/ci.yml`, `pyproject.toml`, `uv.lock` | Dependabot (`uv`, `github-actions`); a `pip-audit` job | DEP-BE |
| `my-list-be/CLAUDE.md` | Rate limits and settings; session rotation and reset-token storage; event lines; `ENVIRONMENT` required; dependency rule | each BE PR, its own lines |
| `my-list-fe/e2e/support/backend-env.ts` | Raise every `RATE_LIMIT_*` to 1000 | FE-RL |
| `my-list-fe/src/api/generated/` | `npm run api:generate` after RL and after AUTH, only if it shows a diff | FE-RL, REDIR |
| `my-list-fe/src/features/auth/redirect.ts`, `redirect.test.ts` | Length cap and slash stripping | REDIR |
| `my-list-fe/package.json`, `package-lock.json`, `.github/dependabot.yml` (new), `.github/workflows/ci.yml`, `CLAUDE.md` | Audit fixes, `shadcn` to dev, Dependabot (`npm`, `github-actions`), `npm audit --omit=dev --audit-level=high` job, dependency rule | DEP-FE |
| `CONTRACTS.md` | 429 and `Retry-After` on the limited routes; drop "no rate limiting" (`:85-86`); update-password sets a new cookie (`:95-99`); reset TTL 1 hour (`:61-63`) | RL, AUTH (boundary rule: same pass) |
| `MILESTONE-1.md`, `ARCHITECTURE.md` | M1-42 and M1-53 status; the `limits` departure if the owner accepts R-1 | PL |

Not touched: the content scripts and the review page (handled), the content database, any `.env` file, `my-list-fe/src/` apart from `redirect.ts` and generated code.

## Architectural constraints

- Platform `CLAUDE.md`, "Working across both repos": a boundary change updates backend, frontend and `CONTRACTS.md` in one pass; frontend types are regenerated with Orval, never hand-patched.
- `my-list-be/CLAUDE.md` "Architecture" (`:79-90`): router, service, query layer, models, one way; cross-cutting code in `app/core/`; Redis key code in `app/crud/` (`session.py`, `password_reset.py`). Layering and test style: the `fastapi-service-patterns` project skill (`CLAUDE.md:298-299`).
- `my-list-be/CLAUDE.md` "Commands": commit `uv.lock` with every dependency change, CI runs `uv sync --locked` (`:44`); regenerate `openapi/openapi.json` with `scripts/export_openapi.py` (`:39`), CI fails on a stale snapshot and on a breaking change without the `breaking-change` label (`.github/workflows/ci.yml`, `openapi` job). Adding a 429 response or a `maxLength` is not breaking for oasdiff's `ERR` level as far as known; if it is flagged, the PR gets the label and FE-RL/REDIR follow at once.
- `my-list-be/CLAUDE.md` "Key architectural decisions": sessions in Redis, CSRF middleware runs before routing (`:289`); CORS only for local dev (`:290`).
- `ARCHITECTURE.md:165`: Redis `noeviction`; `:166`: register 409 accepted with a rate limit; `:168`: starting limit values (R-2 follows them, with per-IP register limits per hour rather than per minute).
- `my-list-fe/CLAUDE.md` "Conventions": tests next to the code (`redirect.test.ts`), comments only for a non-obvious why; Query retries 429 at most twice (`src/lib/query-retry.ts:5`, `:13`), and `errors.too_many_requests` already exists in both catalogues (`src/i18n/locales/en.json:232`), so no UI change is needed for 429.
- Logging: never log request bodies, cookies, reset tokens or email addresses outside local development (`be:app/core/logging.py:16-17`).
- Owner rules: no agent reads `.env`; the content database is never touched.

## Approach

Every PR: branch from a fresh `main` of its repo (`sec-rate-limits`, `sec-auth-sessions`, `sec-event-log`, `sec-env-required`, `sec-deps`, `sec-redirect-cap`, `sec-e2e-limits`), PR to `main`, CI green. Each PR lists its mutations and their red results in the description.

### RL. Rate limits (M1-42)

1. `app/core/config.py`: `RATE_LIMITS_ENABLED` and the counts of R-2 (positive `int` fields with `ge=1`).
2. `app/core/rate_limit.py`: a `Rule` (name, window seconds, count read from settings), `client_key(request)` (the client address from `request.client.host`; IPv6 reduced to its /64 with `ipaddress`), `email_key(email)` (SHA-256 of the lower-cased email), and `async def enforce(rule, key)`: skipped when disabled; `INCR` plus `EXPIRE NX` in one pipeline on `rl:<rule>:<key>`; over the count raises `TooManyRequestsError(retry_after=ttl)`; a Redis error is logged and the request passes (R-3). Use `app/core/redis.py`'s client.
3. `app/core/exceptions.py`: `TooManyRequestsError` (429, `too_many_requests`, "Too many requests", carries `retry_after`). `app/core/errors.py`: a handler modeled on `range_not_satisfiable_handler` (`:170-180`) that adds `Retry-After`; registered before the `AppException` one (`:215-220`).
4. Routers: `login` enforces `login_ip` then `login_email`; `register` `register_ip`; `forgot_password` `forgot_ip`, and `forgot_email` silently (over the limit: return the same 202 without calling the service); `submit_guess` `guess_ip`; `search_titles` `search_ip`; `update_password` `password_user` (user id), `reset_password` `password_user` (IP). Add `429` with `ProblemDetails` to each route's `responses=`. Then `uv run python scripts/export_openapi.py`.
5. `tests/conftest.py`: an autouse fixture sets `RATE_LIMITS_ENABLED = False` (monkeypatch on `settings`). `tests/test_rate_limit.py` turns it on and sets small counts:
   - A table over the seven brief routes plus the two password routes: with the count set to 2, the third request answers 429 `too_many_requests` with a whole-number `Retry-After` between 1 and the window, and the first two do not.
   - `forgot_email`: the fourth request for one email is still 202 and does not create a new reset token (the Redis key is unchanged).
   - Two different emails from one IP do not share `login_email`.
   - Redis raising inside `enforce` lets the request through (one test, monkeypatched pipeline).
   - Mutations: drop the `enforce` call from `login` (its row goes red); compare with `>=` instead of `>` (the "first two pass" rows go red).
6. `CONTRACTS.md`: in "Errors", add `too_many_requests` (429, with `Retry-After` in seconds) and which routes can return it; in "Password reset", replace the "not yet implemented" lines (`:85-86`) with the forgot-password behavior of R-2; note that per-IP limits depend on the proxy passing the client address (P06-12).
7. Backend `CLAUDE.md`: a short "Rate limits" paragraph: the rules table, the settings, fail-open, `RATE_LIMITS_ENABLED` off in tests, P06-12.

### FE-RL. e2e settings and API types

1. `e2e/support/backend-env.ts`: every `RATE_LIMIT_*` count set to `'1000'`, with a one-line comment (the suite registers and logs in from one address).
2. `npm run api:generate`; commit `src/api/generated/` only if it changed.
3. Run `npm run e2e` once locally: 15 passed.

### AUTH. Sessions, reset tokens, caps

1. `app/auth/schemas.py`: `max_length=128` on `UserLogin.password` and `UpdatePasswordRequest.old_password`; `max_length=128` on `ResetPasswordRequest.token`.
2. `update_password` (service) revokes all sessions of the user (`revoke_all_sessions`, `app/crud/session.py:51-58`) and returns a new token from `create_session`; the route sets it with `_set_session_cookie` (`app/auth/router.py:21-30`). If revoking fails, the request fails (500) rather than leaving the old session alive; drop the `try/except` around it for this path.
3. `login` and `register` routes: read the incoming session cookie; if present, `delete_session` it after the new one is created.
4. `app/crud/password_reset.py`: keys hold `sha256(token)` hex, the user key holds the hash too; lifetime 1 hour (`PASSWORD_RESET_EXPIRE_SECONDS = 60 * 60`); `get_password_reset_user_id` becomes a consuming read with `GETDEL`, and `reset_password` (`app/auth/service.py:65-77`) consumes first, then loads the user and updates the password (a token that failed on an inactive user is spent, which is fine).
5. Every `/v1/auth/*` response gets `Cache-Control: no-store` (a small dependency or a `Response` header in each handler; `/me` carries the email).
6. Regenerate `openapi/openapi.json`.
7. Tests (extend existing files, no new fixtures):
   - `test_password_update.py`: after an update, the old cookie gets 401 on `/me`, the response's new cookie gets 200, and another session of the same user gets 401. Mutation: keep the current token (old cookie still 200).
   - `test_auth.py`: logging in with a previous session cookie leaves that old token unknown (401 with it alone). Mutation: drop the `delete_session` call. One row: a 129-character login password is 422 `too_long` and never reaches the hasher (monkeypatch `hash`/`verify` to fail if called).
   - `test_password_reset.py`: the raw token is not a Redis key (scan `password_reset:*` and compare); two concurrent `reset-password` calls with one token give one 204 and one 400 (`asyncio.gather`). Mutation: `GET` instead of `GETDEL` (both succeed). The TTL is at most 3600.
   - `/me` has `Cache-Control: no-store` (one assertion in an existing `/me` test).
8. `CONTRACTS.md`: "Password update": success replaces the session (a new cookie; every other session ends); "Password reset": 1-hour TTL, tokens stored hashed; "Auth": `/auth/*` responses are `no-store`. Backend `CLAUDE.md` "Key architectural decisions", Auth: same three facts.

### REDIR. Redirect length and slashes

1. `src/features/auth/redirect.ts`: return `undefined` for a string longer than 2,048 characters before `new URL`; strip trailing slashes in `isAuthPath` with a loop or `trimEnd`-style index walk instead of `/\/+$/`.
2. `redirect.test.ts`: a 2,049-character value gives `undefined`; `/login////` is still an auth path; a 100,000-slash path returns in under 100 ms (`performance.now()`; generous so it cannot flake, and red on the old pattern, which takes seconds). Mutation: restore the old pattern (the timing row goes red).
3. `npm run api:generate` if AUTH changed the snapshot; commit only a real diff.

### LOG. Security events

1. One helper, `security_event(name, **fields)` in `app/core/logging.py` or a small `app/core/audit_log.py`, logging `event=<name> key=value ...` at INFO (WARNING for refusals) through the existing logger, so the request id is attached.
2. Events: `login_succeeded` (user id), `login_failed` (no user id when unknown; never the email), `registered` (user id), `logged_out`, `password_reset_requested` (only "for a known account" or not, at DEBUG for unknown, so the INFO log is not an enumeration list), `password_reset_completed` (user id), `password_updated` (user id), `sessions_revoked` (user id, count), `csrf_refused` (method, path, the origin's host only), `rate_limited` (rule name; the key never, since it can be an email hash or an IP).
3. `tests/test_security_events.py`: one table through the routes with `caplog`: each event appears once with its name, and no record contains the email, the password or a reset token. Mutation: log `payload.email` in `login_failed` (the "no email" check goes red).
4. Backend `CLAUDE.md`: the event names and the rule "ids only".

### CFG. `ENVIRONMENT` required

1. `app/core/config.py:100`: no default. Check `app/content/settings.py` (the content scripts' settings) reads its own `ENVIRONMENT` the same way, and change it to match if it has a default.
2. `tests/test_config.py`: building `Settings` with no `ENVIRONMENT` (environment cleared, `_env_file=None`) raises. Mutation: restore the default.
3. Backend `CLAUDE.md` "Commands": `.env` must set `ENVIRONMENT=local`; `.env.example` gets the line if it lacks it (the implementer may read `.env.example`, never `.env`). The PR description asks the owner to add the line to their own `.env`.

### DEP-FE and DEP-BE. Dependencies (M1-53)

- DEP-FE: move `shadcn` to `devDependencies`; `npm audit fix` (no `--force`), then `npm run build`, `npm test`, `npm run lint` and `npm run e2e`; list what is left and why in the PR. `.github/dependabot.yml`: `npm` and `github-actions`, weekly, grouped (one group for minor and patch, majors separate). A CI job `audit`: `npm audit --omit=dev --audit-level=high`. A "Dependencies" rule in `CLAUDE.md` (row 1).
- DEP-BE: `.github/dependabot.yml` with the `uv` and `github-actions` ecosystems, weekly, grouped. A CI job `audit` running `pip-audit` on the locked requirements (`uv export --format requirements-txt` piped in; how exactly comes from pip-audit's docs at the version used, `docs` skill), all groups included so `av` and `pillow` are covered. Fix or list what it finds. The same "Dependencies" rule in `CLAUDE.md`.
- The rule (both): an agent adds a dependency only when the plan names it or the owner agrees; the name is copied from the tool's official docs, the registry page and source repository are opened and match, and the lockfile change is in the same PR.
- No tests beyond the CI jobs themselves; mutation: pin a known-vulnerable version locally and see the audit step fail, then revert.

### PL. Notes

- `MILESTONE-1.md`: M1-42 done (with the rules table pointer), M1-53 done apart from the GitHub toggles (O-4).
- `ARCHITECTURE.md` progress line; the `limits` departure if accepted (open question 1).

## Skills for implementer

| Files | Load | Why |
|---|---|---|
| Every change | `shvab:karpathy-guidelines` | Small, surgical diffs; the simplest fix that works |
| `my-list-be/app/**`, `my-list-be/tests/**` | `fastapi-service-patterns` (backend project skill, `my-list-be/.claude/skills/fastapi-service-patterns/SKILL.md`) | Layering, router/service split, test style and budget |
| Redis commands (`EXPIRE NX`, `GETDEL`), Dependabot `uv` ecosystem, `pip-audit`, `npm audit` flags | `docs` | Take the exact syntax from the docs at the version in use (redis-py 8, Redis 7), not from memory |
| `my-list-fe/src/features/auth/redirect*.ts` | `shvab:react-testing-library` (Vitest parts only) | The test file style; there is no component change |
| `my-list-fe/e2e/support/backend-env.ts`, `package.json`, workflows | none | **Gap:** no skill for config files; follow the existing files |
| `CLAUDE.md`, `CONTRACTS.md`, `MILESTONE-1.md` | `shvab:no-ai-slop` | Plain, short sentences |

`shvab:react-best-practices`, the frontend React project skills and `shvab:zod` do not apply: no component, hook or schema change.

## Verification

**Backend PRs**, in `/home/alexandr/Developer/MyList project/my-list-be` (the test database and Redis db `1`; the port override recipe in `CLAUDE.md` "Commands" if 5433 or 6379 is taken):
- Every PR: `uv run ruff check . && uv run ruff format --check .`
- RL: `uv run pytest -q tests/test_rate_limit.py tests/test_auth.py tests/test_guesses.py tests/test_title_search.py tests/test_openapi.py`, then the full `uv run pytest -q` once (the autouse fixture changes every test's setup); `uv run python scripts/export_openapi.py --check`.
- AUTH: `uv run pytest -q tests/test_auth.py tests/test_password_reset.py tests/test_password_update.py tests/test_openapi.py`; `export_openapi.py --check`.
- LOG: `uv run pytest -q tests/test_security_events.py tests/test_auth.py tests/test_csrf.py`.
- CFG: `uv run pytest -q tests/test_config.py`, then the full suite once (every module imports settings).
- DEP-BE: `uv sync --locked`, the new audit command locally, the full suite once after any upgrade.
- Each PR's mutations, red, then reverted.

**Frontend PRs**, in `/home/alexandr/Developer/MyList project/my-list-fe`:
- Every PR: `npm run lint`, `npm run format:check`, `npm run build`.
- REDIR: `npx vitest run src/features/auth/redirect.test.ts`.
- FE-RL and DEP-FE: `npm test` and `npm run e2e` (15 passed; ports 8000 and 5173 free, else ask the owner).
- DEP-FE: `npm audit --omit=dev --audit-level=high` exits 0.

**Plan 06 cross-check** (owner or plan-verifier of plan 06): every P06 item above is present in the Caddyfile, Compose file or Dockerfile CMD; after M1-40 runs locally, `curl -sI https://<local host>/` shows HSTS, CSP, `X-Frame-Options`, `nosniff`, `Referrer-Policy` (not `no-referrer`), `Permissions-Policy` and no `Server`; a login through the proxy works (proves P06-7); two clients behind the proxy get separate rate-limit counters (proves P06-12).

## Risks

- **P06-12 missed:** every visitor shares one address and the first 10 logins a minute lock everyone out. The cross-check above catches it.
- **M1-43 email sending inline** would make forgot-password slower for known emails (an enumeration oracle). M1-43's plan must send through the queue.
- **Shared addresses** (a school or a mobile carrier's NAT) share per-IP limits; the guess and search counts are generous for that reason.
- **oasdiff** may call a new `maxLength` on a request field breaking (a request that was valid is now refused); if so, the AUTH PR takes the `breaking-change` label (no client sends 129-character passwords).
- **`npm audit fix`** can move a transitive version that changes build output; the e2e run in DEP-FE is the check.

## Rollback

Each PR is one squash commit; revert with a revert PR. Reverting AUTH after it ran leaves hashed reset tokens in Redis that the old code cannot find: they expire within the hour, and users ask for a new link. Reverting CFG needs nothing. Reverting RL leaves `rl:*` keys that expire on their own.

## Open questions for the owner

**Answered 2026-11-24: the owner chose (a) on all five (SPEC.md decision 80). Plan 06 now carries P06-1 (at launch), P06-3, P06-11 and P06-14.**

Each has a recommended option first; the plan follows it unless the owner says otherwise.

1. **Limiter implementation (R-1).** (a) **Recommended:** a fixed window in Redis written here (about 30 lines, no dependency). (b) The `limits` library named in `MILESTONE-1.md:106` (sliding-window options, one more dependency to watch; about 10 more agent minutes for its docs).
2. **Limit values (R-2).** (a) **Recommended:** the table in R-2, including the password-change row. (b) Only the five routes in the brief.
3. **Reset link lifetime (R-5).** (a) **Recommended:** 1 hour. (b) Keep 2 days (`CONTRACTS.md` unchanged on that point; tokens still hashed and consumed atomically).
4. **Guest answer oracle (R-8).** (a) **Recommended:** accept it, limited by `guess_ip`, and record it as a known limit in `SPEC.md`. (b) Require a valid `daily_proof`-style token per guest game to guess (a design change, a spec first).
5. **`ENVIRONMENT` required (R-6).** (a) **Recommended:** no default. (b) Keep `local` as the default and rely on P06-15 only.

## Traceability

| Lesson row | PR or item |
|---|---|
| 1 slop-squatting | DEP-FE, DEP-BE |
| 8 click-jacking | P06-4, P06-5 |
| 12 downgrade | P06-3 |
| 14 information leakage | P06-9, P06-10, P06-17, P06-18 |
| 15 insecure design | RL, CFG, open question 4 |
| 16 lax settings | CFG, P06-15, P06-16 |
| 17 logging and monitoring | LOG; M1-44, M1-45, M1-52 |
| 20 password mismanagement | AUTH |
| 23 regex injection | REDIR |
| 25 session fixation | AUTH |
| 27 SSL stripping | P06-1, P06-2 |
| 29 toxic dependencies | DEP-FE, DEP-BE, O-4 |
| 30 unencrypted communication | P06-1 to P06-3, P06-16 |
| 31 user enumeration | RL; M1-43 (queue) |
| 39 denial of service | RL, AUTH, P06-11, P06-12 |
| 40, 41, 44 DNS, email, subdomains | O-1, O-2, O-3 |
