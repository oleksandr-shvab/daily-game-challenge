# M1-50: Playwright smoke tests with axe — Implementation Plan

Status: draft, 2026-11-24. Scope: a Playwright suite in the frontend repo `my-list-fe/` (own git, GitHub `oleksandr-shvab/my-list-fe`, trunk-based, one PR per step) with its own CI workflow; one small backend PR in `my-list-be/` that pins the log line the suite reads; a platform note. Line numbers were checked against frontend `main` at `0f7a2bf` and backend `main` at `456fa84`. There is no feature spec: the milestone row and the owner's brief are the requirements.

## Source requirements

- Task row: `MILESTONE-1.md:117`. "Playwright smoke tests (guest plays a game, register and login, reset password, language switch, archive) on desktop, phone and tablet, with axe", repos FE and PL, 1.0 day, done when "green in CI".
- Same list in `ARCHITECTURE.md:226` ("critical journeys only ... with mobile and tablet projects and axe"), the flake rules in `ARCHITECTURE.md:228`, and axe "on every key page and viewport" in `ARCHITECTURE.md:180`. Definition of done item 8 asks for "accessibility and mobile smoke tests" (`MILESTONE-1.md:16`).
- Owner decisions from the brief, not reopened: one implementer per PR, then plan-verifier, then the owner merges; paired waves only for independent PRs. Small suite, smoke tests only, and every test must be able to fail. No real IGDB content or Steam trailers: only the dev seed (`scripts/seed_dev.py` and `scripts/seed_media/`). The content database `daily_game_challenge_content` is never touched. No `.env` reading: every setting is an explicit environment variable or a committed e2e config with dummy values. Learning project (2026-11-20): the simplest setup that really works.

**State of the code (checked 2026-11-24):**
- Frontend: Vitest and Testing Library only; "There are no end-to-end tests yet" (`my-list-fe/CLAUDE.md:7`). Vitest reads only `src/**/*.test.ts(x)` (`vitest.config.ts`), so an `e2e/` folder at the repo root is not picked up. One workflow, `.github/workflows/ci.yml` (lint, build, test, api-types), actions pinned to commit SHAs. No `LEARNINGS.md` in either repo.
- Backend: the reset email is a stub that logs `"[email stub] Password reset link for %s: %s"` at INFO in `local` and `test` only (`app/core/email.py:8-13`), to stdout through `configure_logging` (`app/core/logging.py`; the handler flushes after each record). No test pins that line (checked `tests/`). `CONTRACTS.md:69-71` documents that the link is logged in `local` and `test`.
- The reset token is also stored in plain text in Redis (`password_reset_user:{user_id}` holds the token, `app/crud/password_reset.py`); not used by this plan (R-3).
- Dev seed: game `game-guesser`, launch date 3 days ago (`seed_dev.py:43`), scheduled puzzles for today (Half-Life 2), days -1 to -3, tomorrow (Celeste), and a draft with no date whose answer is "Elden Ring" (`seed_dev.py:89-96`); "today" from the server clock; refuses unless `ENVIRONMENT=local`, a localhost `DATABASE_URL` and `MEDIA_STORAGE=local` (`refusal_reason`, `app/content/target.py:104-112`). It also refuses whenever `CI` is set to anything but empty, `0`, `false` or `no` (`target.py:39`, `:66`); GitHub Actions sets `CI=true`.
- Settings read `.env` only for values the environment does not set (`app/core/config.py:98`, pydantic-settings: process environment wins). No rate limits yet (M1-42 is Phase 4). The backend repo is public (the frontend's api-types job reads it from `raw.githubusercontent.com` without a token).
- The platform repo has no GitHub remote (`git remote -v` is empty), so it has no CI.

## Clarifications & recommendations

No questions could be asked (this planner runs as a subagent). The six questions of the brief are answered below with a default each (**R-1** to **R-6**); other judgment calls are **R-7** onward.

- **R-1. Where the suite lives: the frontend repo, `my-list-fe/e2e/`.** CI: a new workflow `my-list-fe/.github/workflows/e2e.yml` checks out the frontend into `my-list-fe/` and the backend (`oleksandr-shvab/my-list-be`, public, no token) at `main` into `my-list-be/` inside the workspace, so `../my-list-be` is the same relative path as on this laptop. Postgres 16 and Redis 7 are service containers (as in the backend CI). Playwright's `webServer` starts the backend (a committed script: migrate, seed, uvicorn) and the Vite dev server; nothing else starts them, in CI or locally.
  - **This departs from decision 59** (`SPEC.md:73`: the platform repo holds the end-to-end tests) and from `ARCHITECTURE.md:232`. Reason: the platform repo has no remote, so it has no CI, and "green in CI" is the done check. Making it a GitHub repo (and choosing whether `SPEC.md` goes public) is an owner action with its own decisions. The frontend is where the journeys are UI, its CI already pulls from the backend's `main` (api-types job), and the suite moves to the platform repo in one PR later (the files are self-contained under `e2e/` plus one config and one workflow). Open question 1 asks the owner to record this as decision 78.
  - Cost: a backend change that breaks a journey is caught on the next frontend PR, the nightly run (R-11), or a manual run against a backend branch (`workflow_dispatch` input `backend_ref`), not on the backend PR itself.
- **R-2. The real clock and the seeded dates: tests never depend on which day it is.** The backend runs on its real clock; nothing fakes it.
  - The backend start script re-seeds on every run (in CI and locally), right before the tests, so "today" in the data is the server's today at that moment. A stale seed from yesterday cannot exist.
  - No test hard-codes a date or knows today's answer. Dates are read from the page (links, the address). The guest journey loses on purpose: its one real guess is "Elden Ring", the answer of the seed's undated draft, which is never visible, so it is wrong on every day. The rest are skips. The end screen check is "Not this time" plus an answer shown, never which answer.
  - The archive checks "a Today row, then at least 3 past rows", true before and after 00:00 UTC (after midnight the seed's "tomorrow" becomes today and day -3 becomes -4).
  - A run that crosses 00:00 UTC mid-test can show the day-change message; that test fails once and passes on the retry (R-6). Accepted, documented, not engineered around. The nightly run is set at 06:00 UTC.
  - Not chosen: a fake-clock setting in the backend (a production code path that moves time, for a problem that the re-seed already solves), and Playwright's `page.clock` (it moves only the browser's clock, while "today" is the server's; `my-list-fe/CLAUDE.md:58`, `:60`).
- **R-3. Password reset without email: read the link the backend already logs.** No backend seam is needed. The start script sends the backend's stdout and stderr to `my-list-fe/.e2e/backend.log` (truncated each run). A helper polls that file with `expect.poll` (no sleep) for the line that contains the test's unique email and `/reset-password?token=`, and takes the URL from it. The emails are unique per test, so parallel tests never read each other's link.
  - What makes it safe: `CONTRACTS.md:69-71` already promises the link is logged in `local` and `test`; backend PR **BE-E2E** adds the missing test that pins the line (logged in `local` and `test`, never in `staging` or `production`, which is also a security check the suite lacks today), a comment at the logger call, and one line in `CONTRACTS.md` saying the frontend e2e reads it.
  - Not chosen: (b) a file outbox in the backend (`EMAIL_OUTBOX_DIR`, local and test only; about 15 more agent minutes, a new setting and a test; worth it when M1-43 replaces the stub, see Risks); (c) reading the token from Redis (couples the test to key names inside the backend). Open question 2.
- **R-4. Viewports and browsers: Chromium only, three projects.**
  - `desktop`: `devices['Desktop Chrome']` (1280x720).
  - `phone`: `devices['Pixel 7']` with `viewport` 360x740 (the narrowest width M1-03 checks, `MILESTONE-1.md:49`; its other two widths, 768 and 1280, are the tablet and desktop projects); touch on, `isMobile` on. Below 768 px the sidebar is a panel behind the header button (`my-list-fe/CLAUDE.md:93`).
  - `tablet`: `devices['iPad Mini']` (768x1024, touch) with `browserName: 'chromium'`. 768 px is exactly where the sidebar stays open beside the content (`CLAUDE.md:91`), the edge worth one project.
  - WebKit is left out. Its cost: one more browser download with its system packages in CI (about a minute), one more project (a third more test time), and Linux WebKit is not iOS Safari, so it would not prove what a phone user sees while adding its own flakes (video, clipboard). Add it later as a `phone-webkit` project in the nightly run only, if wanted (Open question 3). `ARCHITECTURE.md:143` lists an iPhone-class WebKit; this is a deliberate cut for a learning project.
  - Every project sets `locale: 'en-US'`, `colorScheme: 'light'` and `reducedMotion: 'reduce'` (the step-6 clip then does not autoplay, `CLAUDE.md:67`; one less moving part).
- **R-5. Where axe runs, and existing violations.**
  - Package `@axe-core/playwright`. One helper, `checkA11y(page, name)` in `e2e/support/axe.ts`, tags `wcag2a`, `wcag2aa`, `wcag21a`, `wcag21aa`, `wcag22aa` (the project's target is WCAG 2.2 AA). It runs on the whole page (no excluded regions), after a web-first assertion has seen the state it checks (never after a timeout).
  - Called at nine states, on every project: the game page as a guest at start, the end screen, the archive, register, login, forgot password, reset password, the game page in Russian, and the game page signed in (after the register step). That is "every key page and viewport".
  - **Any violation fails** the test, with the rule id, help text and targets in the message, and the full results attached to the report.
  - **A documented allow-list** for what exists today: `e2e/support/axe-allowlist.ts`, entries `{ rule, page, projects?, reason }`, matched by axe rule id and the `name` passed to `checkA11y` (optionally only on some projects). Never a rule switched off globally, never a region excluded. It starts empty. On the first full run, the implementer adds one entry per existing violation, with the reason axe gives, and lists them in the PR description. **The e2e PR changes no app code**: fixes are follow-up PRs that delete their entry (Open question 4 offers the other way).
- **R-6. Flake control.**
  - `retries: process.env.CI ? 1 : 0` (`ARCHITECTURE.md:228`). A test that passes on its retry is reported as "flaky" by Playwright; per `ARCHITECTURE.md:228` it gets an issue, is quarantined and fixed within a week, or deleted.
  - `trace: 'on-first-retry'`, `screenshot: 'only-on-failure'`, `video: 'off'`. The HTML report, `test-results/` (traces) and `.e2e/backend.log` are uploaded as one artifact when the job did not pass, kept 7 days. The log holds reset tokens of throwaway accounts on a throwaway database only.
  - No fixed sleeps: no `page.waitForTimeout`, no `setTimeout` in tests. Waits are web-first assertions (`expect(locator).toBeVisible()`), `expect.poll` for the log file, and `page.waitForURL`. `eslint-plugin-playwright`'s recommended rules (for `e2e/**` only) make `no-wait-for-timeout`, `missing-playwright-await` and `no-focused-test` lint errors, so the rule is checked, not hoped for.
  - Isolation: every test gets a fresh browser context (Playwright's default), so guest records and the saved language start empty; every account email is `e2e-<random uuid>@example.com`. No test depends on another's state, so the default worker count is fine.
  - `forbidOnly: !!process.env.CI`. Reporter in CI: `github` plus `html` (never opened); locally `list`.
- **R-7. The dev server, not a production build.** `webServer` runs `npm run dev -- --port 5173 --strictPort`. `http://localhost:5173` is the only allowed origin for POSTs and the default `FRONTEND_URL` (`my-list-fe/CLAUDE.md:31-32`), and the clue links already point there (`MEDIA_LOCAL_BASE_URL` default, `config.py:132`). A `vite preview` run would need port 4173 added as an allowed origin and as `FRONTEND_URL`; the `build` job already proves the production build compiles. Revisit with M1-40 (Compose stack).
- **R-8. A database of its own: `daily_game_challenge_e2e`.** On the compose Postgres (`localhost:5433`) locally and on a service container mapped to the same port in CI, so one committed config works in both. Redis database `2`, so e2e never touches a dev session (dev uses `0`, the backend tests `1`). Media folder: the default `var/media` (gitignored, content-addressed; the seed writes the same files there). The content database is never named anywhere in the suite.
- **R-9. The seed's CI guard is cleared for one command only.** The start script runs `CI= uv run --no-sync python scripts/seed_dev.py`. Every other guard of `refusal_reason` still applies (`ENVIRONMENT` must be `local`, the database must be on this machine, storage must be `local`), and in CI the database is a throwaway service container. A comment in the script says why. Backend PR BE-E2E records it in the backend `CLAUDE.md` next to the seed paragraph, so the guard's owner knows. Not chosen: a new backend flag that bypasses the guard (the same effect with more code).
- **R-10. Backend settings come from one committed object.** `e2e/support/backend-env.ts` exports the dummy values; the config passes them to the backend `webServer` as `env`. Values: `ENVIRONMENT=local` (the seed needs it, and the email stub logs only in `local` and `test`), `DATABASE_URL=postgresql+asyncpg://postgres:postgres@localhost:5433/daily_game_challenge_e2e`, `REDIS_URL=redis://localhost:6379/2`, `SECRET_KEY=e2e-only-secret-key-not-used-anywhere-0000`, `FRONTEND_URL=http://localhost:5173`, `BACKEND_CORS_ORIGINS=["http://localhost:5173"]`, `MEDIA_STORAGE=local`, `MEDIA_LOCAL_DIR=var/media`, `MEDIA_LOCAL_BASE_URL=http://localhost:5173/api`. Process environment wins over a developer's `.env` in pydantic-settings, so a local `.env` cannot change these; values the object does not set (IGDB keys and so on) are not used by the server, the seed or the migrations. No agent reads any `.env`.
- **R-11. A separate workflow file with a nightly run.** `e2e.yml`, not a fifth job in `ci.yml`: its triggers differ (pull request, push to `main`, `schedule` at 06:00 UTC, `workflow_dispatch` with `backend_ref`, default `main`). The nightly run is what catches a backend `main` that broke a journey.
- **R-12. Five tests, the journeys of the row, nothing more.** Each runs on all three projects (15 runs). The phone differs only where the shell differs: one helper opens the panel when the header's sidebar button ("Show or hide the sidebar") is visible. Setup that is not the journey under test goes through the API (`request.post` to `/api/v1/auth/register` with `Origin: http://localhost:5173`, which the backend requires on unsafe methods, `CONTRACTS.md:37-46`).
- **R-13. Rate limits later.** M1-42 will limit register, login and forgot-password per client. The e2e makes about 12 registrations and logins a run from one address; M1-42's plan must keep its limits settings-driven so `backend-env.ts` can raise them for `local`. Noted under Risks, nothing to do now.

## Execution mode

- **Owner's choice (already decided, not asked again):** one `implementer` per PR, then `plan-verifier`; the owner merges. Commits and PRs only when the owner asks.
- **Extra passes:** the owner's rule (code-review high and test-writer) is for backend PRs with a migration or a route. BE-E2E has neither (one test, a comment, docs). FE M1-50 is test infrastructure plus a workflow; its real check is the first CI run. `plan-verifier` only; the owner may still ask for code-review on M1-50.
- **Paired wave:** BE-E2E and FE M1-50 are independent (the log line already exists on backend `main`; BE-E2E only pins it), so they may run together. Scratch prefixes in the shared scratchpad: `m150be_`, `m150fe_`; never run a scratch script another agent wrote. BE-E2E runs only the backend pytest (test database `daily_game_challenge_test`, Redis db `1`), FE M1-50 only its own e2e database and Redis db `2`, so they share nothing.
- **Ports:** the e2e run needs `8000` and `5173` free (`reuseExistingServer: false`, so it never talks to a dev server whose settings and log it does not control). If either port is taken, the implementer asks the owner; it never stops a process it did not start.
- **Test budget:** the five tests and the one backend test listed below, no more. Each is checked to fail once by a one-line mutation (listed per PR), run on the `desktop` project only, then reverted; the PR description lists the mutation and the red result.

## Order and estimates

Agent minutes are estimates, calibrated on Phases 1 to 3. Owner review is separate.

| Step | PR | Repo | Waits for | Implementer | plan-verifier | Agent total | Owner review |
|---|---|---|---|---|---|---|---|
| wave 1 | **BE-E2E** Pin the reset-link log line | BE | nothing | 8 | 3 | ~11 min | 5 min |
| wave 1 | **M1-50** Playwright smoke suite, axe, e2e workflow | FE | nothing (runs alongside BE-E2E) | 45 | 12 | ~57 min | 25-30 min, plus one CI round (~5 min wall clock per run) |
| after both merge | **PL** platform notes | PL | M1-50 green in CI | 3 | none | ~3 min | 3 min |

`MILESTONE-1.md:117` gives M1-50 1.0 day of human-equivalent work; not changed by this plan. The implementer cannot see CI before the owner opens the PR; if the first CI run fails where the local run passed, the fix goes back to the same implementer as a second round (budget ~10 min).

## Modules affected

| Where | Why | PR |
|---|---|---|
| `my-list-be/tests/test_password_reset.py` | One parametrized test: the stub logs the link in `local` and `test`, not in `staging` or `production` | BE-E2E |
| `my-list-be/app/core/email.py` | A one-line comment at the log call: the frontend e2e reads this line | BE-E2E |
| `my-list-be/CLAUDE.md` | Two sentences: the e2e reads the stub's line (near `:11`); the e2e start script runs the seed with `CI` cleared against its own database (seed paragraph, `:227-231`) | BE-E2E |
| `my-list-fe/playwright.config.ts` (new) | Projects, `webServer` for both servers, retries, trace, reporters | M1-50 |
| `my-list-fe/e2e/start-backend.sh` (new) | Migrate, seed, start uvicorn with its log in `.e2e/backend.log` | M1-50 |
| `my-list-fe/e2e/support/*.ts` (new) | `backend-env.ts`, `axe.ts`, `axe-allowlist.ts`, `reset-link.ts`, `accounts.ts`, `nav.ts` | M1-50 |
| `my-list-fe/e2e/*.spec.ts` (new) | `guest-game`, `auth` (two tests), `language`, `archive` | M1-50 |
| `my-list-fe/tsconfig.e2e.json` (new), `tsconfig.json` | Type-check `e2e/` and `playwright.config.ts` in `tsc -b` (so the `build` job checks them) | M1-50 |
| `my-list-fe/eslint.config.js` | `eslint-plugin-playwright` recommended for `e2e/**` | M1-50 |
| `my-list-fe/package.json`, `package-lock.json` | Dev dependencies `@playwright/test`, `@axe-core/playwright`, `eslint-plugin-playwright`; script `"e2e": "playwright test"` | M1-50 |
| `my-list-fe/.gitignore`, `.prettierignore` | `test-results/`, `playwright-report/`, `.e2e/` | M1-50 |
| `my-list-fe/.github/workflows/e2e.yml` (new) | The CI job (R-1, R-11) | M1-50 |
| `my-list-fe/CLAUDE.md`, `README.md` | "Project state" (`:7`), "Commands", a short "End-to-end tests" section; README: how to run locally | M1-50 |
| `CONTRACTS.md` | Password reset (`:69-71`): one sentence that the frontend e2e reads the logged line | BE-E2E (boundary rule: same pass) |
| `MILESTONE-1.md`, `SPEC.md` | M1-50 status; decision 78 if the owner accepts R-1 | PL |

Not touched: any app code under `my-list-fe/src/` or `my-list-be/app/` beyond the one comment; `src/api/generated/` (no regeneration); `ci.yml` of either repo; the content database.

## Facts found (file:line)

- Allowed origins and the cookie: `localhost`, never `127.0.0.1`; port `4173` is not allowed (`my-list-fe/CLAUDE.md:29-32`; `CONTRACTS.md:37-55`).
- Vite proxy: `/api` to `http://localhost:8000`, `Origin` kept (`my-list-fe/vite.config.ts`).
- Reset link: `{FRONTEND_URL}/reset-password?token={token}` (`app/auth/service.py:61`; `CONTRACTS.md:72`). A successful reset ends every session and the frontend goes to `/login` (`CONTRACTS.md:80-83`; `my-list-fe/CLAUDE.md:52`).
- Forgot-password and login send a signed-in user to `/` (`my-list-fe/CLAUDE.md:49`), so the reset test starts as a guest.
- Shell on phones: header with the sidebar button, brand and the compact account control; sidebar as a panel (`my-list-fe/CLAUDE.md:93`). Account button named "Account: {{email}}" (`en.json`, `nav.account_menu`), menu has "Log out".
- Strings the tests can use (`src/i18n/locales/en.json`): "Search for a game", "Guess", "Skip", "Not this time", "Archive", "Today", "Log in", "Sign up", "Create account", "Forgot password?", "Send reset link", "Check your email", "New password", "Confirm new password", "Reset password", "Language", "Русский". Query by role and accessible name, as the unit tests do (`CLAUDE.md:109`).
- Language: saved in `localStorage` key `language`, `<html lang>` follows (`my-list-fe/CLAUDE.md:126`).
- Guest records live in `localStorage` (`CLAUDE.md:70`), so a reload keeps the game (decision 20).
- Archive: today's row first, with "Today" and a link to `/games/$slug`, `data-today` on its link; past rows link to `/games/$slug/$date` (`CLAUDE.md:79-80`).
- Backend health for `webServer.url`: `GET /readyz` checks Postgres and Redis (`CONTRACTS.md:458-462`).
- Backend CI pins `astral-sh/setup-uv@07a047e608db84b3d8c06cd9a7c7dcc9c355c18e # v10.3.2`, uv `0.13.6`, Python 3.12 (`my-list-be/.github/workflows/ci.yml:16-34`); frontend CI pins `actions/checkout@3d3c42e…` v7.0.1 and `actions/setup-node@949feb2…` v7.1.0, Node 24 (`my-list-fe/.github/workflows/ci.yml`).
- `uv sync --no-default-groups` installs the runtime only (`my-list-be/CLAUDE.md:20`).

## Architectural constraints

- Platform: a boundary change updates backend, frontend and `CONTRACTS.md` in one pass (root `CLAUDE.md`, "Working across both repos"); use `localhost`, not `127.0.0.1` (same section).
- `my-list-fe/CLAUDE.md`: never put a test file in `src/routes/` (`:108`); generated code is never hand-edited (`:46`); comments only where the why is not obvious (`:113`); no user-visible text in components (`:125`, not relevant: no app change).
- `my-list-be/CLAUDE.md`: `seed_dev.py` and the content database are kept apart; the seed deletes the game's puzzles (`:165`, `:227-231`). The reset link is an account-takeover token: logged only in `local` and `test` (`app/core/email.py:9`; `app/core/logging.py` docstring).
- `ARCHITECTURE.md:228`: `retries: 1` in CI only; flaky tests reported and quarantined; no sleeps.
- Workflows: every third-party action pinned to a full commit SHA with the version in a comment (both `ci.yml` files); `permissions: contents: read`.
- Owner rule (brief): no `.env` reading by agents; e2e settings explicit (R-10).

## Approach

Every PR: branch from a fresh `main` (`m1-50-be-reset-log`, `m1-50-playwright`), PR to `main`, CI green.

### BE-E2E. Pin the reset-link log line

1. `tests/test_password_reset.py`: one parametrized test over `ENVIRONMENT` (`local`, `test`, `staging`, `production`), with `monkeypatch` on `settings.ENVIRONMENT` and `caplog` at INFO for `app.core.email`. It calls `send_password_reset_email("a@example.com", "http://localhost:5173/reset-password?token=t")`. In `local` and `test` the log text contains the email and the full link; in `staging` and `production` it contains neither (the warning only). Mutation: log in every environment (drop the `if`), the two last rows go red; change the message so it no longer has the link, the first two go red.
2. `app/core/email.py`: a comment above the `logger.info` line: the frontend e2e (`my-list-fe/e2e/support/reset-link.ts`) reads this line by the email and the link; keep both in it.
3. `CLAUDE.md` (backend): after `:11`, one sentence on the e2e reading that line; in the seed paragraph, one sentence that the frontend e2e start script runs `seed_dev.py` with `CI` cleared against its own database `daily_game_challenge_e2e` (R-9).
4. `CONTRACTS.md` "Password reset": after "the link is logged server-side", add that the frontend's Playwright suite reads it from the backend's output, so the line keeps the email and the link.

### M1-50. Playwright smoke suite with axe

1. **Dependencies.** `npm i -D @playwright/test @axe-core/playwright eslint-plugin-playwright` (current versions; check each one's docs for the API used, `docs` skill). Script `"e2e": "playwright test"`. Browsers are not in `package.json`: `npx playwright install chromium` once locally, `npx playwright install --with-deps chromium` in CI.
2. **Type check and lint.** `tsconfig.e2e.json` (like `tsconfig.node.json`: `types: ["node"]`, `noEmit`, the same strictness flags) including `playwright.config.ts` and `e2e/**/*.ts`, referenced from `tsconfig.json`, so `npm run build` (`tsc -b`) checks them. `eslint.config.js`: a block for `e2e/**` and `playwright.config.ts` with the plugin's flat recommended config and `globals.node`. Ignore files: `test-results/`, `playwright-report/`, `.e2e/` in `.gitignore` and `.prettierignore`.
3. **`e2e/support/backend-env.ts`**: the object of R-10, with a comment that these are dummy values for a throwaway database.
4. **`e2e/start-backend.sh`** (bash, `set -euo pipefail`, executable): `cd` to the backend (`${BACKEND_DIR:-<frontend root>/../my-list-be}`), then `uv run --no-sync alembic upgrade head`, then `CI= uv run --no-sync python scripts/seed_dev.py` (comment: R-9), then create `.e2e/` in the frontend root and `exec uv run --no-sync uvicorn app.main:app --port 8000 > <frontend root>/.e2e/backend.log 2>&1`. `--no-sync` because CI installs with `uv sync --locked --no-default-groups` and a plain `uv run` would install the default groups again; locally the developer's own `uv sync` is enough.
5. **`playwright.config.ts`**:
   - `testDir: 'e2e'`, `forbidOnly`, `retries`, `reporter` and `use` (`baseURL: 'http://localhost:5173'`, trace, screenshot, locale, color scheme, reduced motion) as in R-4 and R-6.
   - `projects`: `desktop`, `phone`, `tablet` (R-4).
   - `webServer`: two entries. Backend: `command: 'bash e2e/start-backend.sh'`, `url: 'http://localhost:8000/readyz'`, `env: backendEnv`, `reuseExistingServer: false`, `timeout: 120_000`. Frontend: `command: 'npm run dev -- --port 5173 --strictPort'`, `url: 'http://localhost:5173'`, `reuseExistingServer: false`.
6. **`e2e/support/`**:
   - `accounts.ts`: `uniqueEmail()` (`e2e-${crypto.randomUUID()}@example.com`), a fixed test password of 12 characters, and `registerByApi(request, email, password)` (POST `/api/v1/auth/register` with the `Origin` header, expects 201).
   - `nav.ts`: `openNav(page)`: if the header's "Show or hide the sidebar" button is visible (phone), press it and wait for the panel; otherwise nothing.
   - `reset-link.ts`: `readResetLink(email)`: `expect.poll` over `.e2e/backend.log` (default 10 s) for the last line containing `email` and `/reset-password?token=`, returns the URL found in it.
   - `axe.ts` and `axe-allowlist.ts` (R-5).
7. **Specs** (each test: `test.describe` none, one `test` per journey, role and name locators, web-first assertions):
   - `guest-game.spec.ts`, "a guest plays today's puzzle to the end": open `/`; the step-1 clue image is visible and loaded (`naturalWidth > 0`, proves signed media through the proxy); `checkA11y('game-start')`; type "elden" in "Search for a game", pick "Elden Ring" from the list, press "Guess"; the guess list shows it and "5 guesses left"; reload; the guess and "5 guesses left" are still there; press "Skip" five times; the heading "Not this time" shows with an answer; `checkA11y('end-screen')`. Mutation: in `guest-records.ts` skip the write after a guess, the reload check goes red.
   - `auth.spec.ts`, "register, log out and log in": open `/register` (on the phone through the header's "Sign up"; on wider screens the sidebar's), `checkA11y('register')`, fill Email, Password (and any confirm field the form has), "Create account"; the account button "Account: <email>" shows (sidebar, or header on the phone) on `/`; `checkA11y('game-signed-in')`; open the menu, "Log out"; "Log in" shows; go to "Log in", `checkA11y('login')`, sign in with the same email and password; the account button shows again. Mutation: make the login page's success handler not refresh the session (the account button never shows), red.
   - `auth.spec.ts`, "reset a forgotten password": `registerByApi` with a unique email; open `/login`, "Forgot password?", `checkA11y('forgot-password')`, submit the email; "Check your email" shows; `readResetLink(email)`; open it; `checkA11y('reset-password')`; fill "New password" and "Confirm new password" with a new value, "Reset password"; the page is `/login`; sign in with the new password; the account button shows. Mutation: set `FRONTEND_URL` in `backend-env.ts` to another port, the opened link fails, red.
   - `language.spec.ts`, "switch to Russian and keep it": open `/`, `openNav`, choose "Русский" in "Language"; `<html lang="ru">` and the nav label "Игры" (the Russian `nav.games`; read the exact text from `ru.json`) show; reload; still Russian; `checkA11y('game-ru')`. Mutation: in `src/i18n/language.ts` stop saving the choice, the reload check goes red.
   - `archive.spec.ts`, "open a past puzzle from the archive": open `/`, `openNav`, "Archive"; the first row has "Today" and links to `/games/game-guesser`; at least 3 more rows follow (R-2); `checkA11y('archive')`; open the first past row; the address matches `/games/game-guesser/\d{4}-\d{2}-\d{2}` and the clue image is visible. Mutation: leave the today row out of the list, red.
8. **`.github/workflows/e2e.yml`**:
   - Triggers: `pull_request`, `push` to `main`, `schedule` `0 6 * * *`, `workflow_dispatch` with input `backend_ref` (default `main`). `permissions: contents: read`; `concurrency` as `ci.yml`.
   - One job `e2e`, `ubuntu-latest`, `timeout-minutes: 20`, `defaults.run.working-directory: my-list-fe`. Services: `postgres:16-alpine` (`POSTGRES_PASSWORD: postgres`, `POSTGRES_DB: daily_game_challenge_e2e`, ports `5433:5432`, the health check from the backend CI) and `redis:7-alpine` (`6379:6379`, health check).
   - Steps: checkout the frontend (`path: my-list-fe`); checkout `oleksandr-shvab/my-list-be` at `inputs.backend_ref || 'main'` (`path: my-list-be`); setup-uv (the backend CI's pinned SHA, uv `0.13.6`, Python 3.12, cache on) and `uv sync --locked --no-default-groups` in `my-list-be` (if the seed or alembic needs a package from another group, use `--no-dev` and say why in the PR); setup-node (Node 24, npm cache with `cache-dependency-path: my-list-fe/package-lock.json`); `npm ci`; `npx playwright install --with-deps chromium`; `npm run e2e`; on failure (`if: ${{ failure() }}`) upload `playwright-report/`, `test-results/` and `.e2e/backend.log` with `actions/upload-artifact`, pinned to the full SHA of its current release (look it up with `gh api`), `retention-days: 7`.
   - No `.env` exists in either checkout; every backend setting comes from `backend-env.ts`.
9. **Docs.**
   - Frontend `CLAUDE.md`: "Project state" no longer says there are no end-to-end tests; "Commands" gets `npm run e2e`; a short "End-to-end tests" section: where they are, what starts the servers, the e2e database and Redis db, the reset log, the allow-list rule (R-5), the no-sleep rule, viewport projects, and that the suite is meant to move to the platform repo (R-1).
   - `README.md` "Check": how to run locally, once: `cd ../my-list-be && docker compose up -d && docker compose exec -T db createdb -U postgres daily_game_challenge_e2e`, `uv sync`, then `npx playwright install chromium`; each run: stop the dev servers on 8000 and 5173, `npm run e2e`.

Acceptance M1-50: the five tests pass on the three projects locally and in the `e2e` workflow on the PR; each was seen red under its mutation; axe runs at the nine states with any allow-list entry explained in the PR; the owner adds `e2e` to the required checks of `main` after the first green run.

### PL. Platform notes (after M1-50 is green)

- `MILESTONE-1.md`: M1-50 status, with the suite's home and the Chromium-only cut.
- `SPEC.md`: decision 78 with the owner's answers to the open questions below (at least R-1's departure from decision 59).
- `ARCHITECTURE.md` progress line: Playwright and axe in the frontend CI.

## Skills for implementer

Frontend project skills are in `my-list-fe/.claude/skills/` (React patterns only); backend ones in `my-list-be/.claude/skills/`.

| Files | Load | Why |
|---|---|---|
| Every change | `shvab:karpathy-guidelines` | Small, surgical diffs; no app code in M1-50 |
| `playwright.config.ts`, `e2e/**`, `e2e.yml` | `docs` | **Gap:** no Playwright or axe skill exists. Take `webServer`, projects, `expect.poll`, `AxeBuilder` and `eslint-plugin-playwright` usage from their docs at the installed version, not from memory |
| `e2e/*.spec.ts` | `shvab:react-testing-library` (query priority section only) | The same role-and-name locator priority the unit tests use; the rest of that skill (Vitest, jsdom) does not apply |
| `tsconfig.e2e.json`, `eslint.config.js` | none | **Gap:** follow `tsconfig.node.json` and the existing flat config |
| `my-list-be/tests/test_password_reset.py`, `app/core/email.py` | `fastapi-service-patterns` (backend project skill; read its `SKILL.md`) | Its test budget and test style |
| `CLAUDE.md`, `README.md`, `CONTRACTS.md` | `shvab:no-ai-slop` | The owner wants plain, short sentences |

`shvab:react-best-practices`, the React project skills and `shvab:zod` do not apply: no component, hook or schema changes.

## Verification

**BE-E2E**, in `/home/alexandr/Developer/MyList project/my-list-be`:
- `uv run ruff check . && uv run ruff format --check .`
- `uv run pytest -q tests/test_password_reset.py` (the test database and Redis db `1`, as `CLAUDE.md` "Commands" says; if port 5433 is taken, the override recipe there).
- The two mutations of step 1, each red, then reverted.

**M1-50**, in `/home/alexandr/Developer/MyList project/my-list-fe`:
- Prerequisites: compose Postgres on 5433 and Redis on 6379 up, `daily_game_challenge_e2e` created, ports 8000 and 5173 free (else ask the owner), `npx playwright install chromium`.
- `npm run lint`, `npm run format:check`, `npm run build` (now also type-checks `e2e/`).
- `npm run e2e`: 15 passed (5 tests, 3 projects), 0 flaky.
- `CI=1 npm run e2e` once: same result with CI settings (one retry, `forbidOnly`, the `github` reporter); the seed still runs (R-9).
- Flake shake-out once: `npx playwright test --repeat-each=3`: 45 passed, 0 flaky. A test that fails here is fixed, never given a sleep or a longer timeout without a cause.
- The five mutations of step 7, each red on `--project=desktop`, then reverted (`git diff -- src` empty at the end).
- `npm test` is not needed: no file under `src/` changes.
- After the owner opens the PR: the `e2e` job is green; the artifact upload step is skipped on success.

## Risks

- **The log line is the seam** (R-3). Pinned by BE-E2E's test and the `CONTRACTS.md` sentence. When M1-43 moves email to a queue, the `local` and `test` path must still log the link or the suite switches to an outbox (Open question 2 (b)); M1-43's plan must say which.
- **Midnight UTC during a run** (R-2): one failure, passed on the retry and reported as flaky; ignore it once when the run's time is near 00:00 UTC.
- **Backend `main` moves under the frontend.** A seed or startup change breaks the suite on the next frontend PR or nightly run, not on the backend PR. `backend_ref` lets a backend branch be tried first. Moving the suite to the platform repo (R-1) does not change this; a backend-side trigger would.
- **`localhost` resolving to `::1`.** uvicorn binds `127.0.0.1`; Node and Chromium fall back to IPv4 as the dev setup already does. If CI shows `ECONNREFUSED ::1`, bind uvicorn with `--host localhost` in the start script.
- **Rate limits (M1-42)** will count the suite's registrations and logins from one address (R-13).
- **Existing axe violations** may be several on the first run, so the allow-list is long at first; each entry is a known defect with a reason, and the owner chooses the follow-ups.
- **CI time:** about 4-6 minutes per run (uv and npm installs, the Chromium download, 15 tests), in parallel with the other jobs. Caching the Playwright browsers is left out for simplicity.

## Rollback

- Each PR is one squash commit; revert with a revert PR.
- Reverting M1-50 removes the suite and the workflow; nothing in the app changes. Remove `e2e` from the required checks first if it was added.
- Reverting BE-E2E removes a test, a comment and doc lines; the suite still works (the log line itself is older than this plan).

## Open questions for the owner

Each has a recommended option first; the plan follows it unless the owner says otherwise.

1. **Where the suite lives (R-1).** (a) **Recommended:** the frontend repo now, with a nightly run; record it as decision 78, a departure from decision 59 until the platform repo has a GitHub remote and the Compose stack (M1-40), then move it in one PR. (b) Give the platform repo a GitHub remote now and put the suite there (owner creates the repo and decides whether `SPEC.md` goes public; about 15 more agent minutes for a workflow that checks out both app repos).
2. **Reading the reset link (R-3).** (a) **Recommended:** from the backend's log, pinned by BE-E2E. (b) A file outbox in the backend for `local` and `test` (`EMAIL_OUTBOX_DIR`), about 15 more agent minutes; better once M1-43 lands.
3. **WebKit (R-4).** (a) **Recommended:** Chromium only now. (b) Add a `phone-webkit` project to the nightly run only (about 10 agent minutes, about a minute more per nightly run).
4. **Existing axe violations (R-5).** (a) **Recommended:** fail on any violation, with an allow-list of today's ones (rule and page, with a reason), fixed in follow-up PRs. (b) Fix them in the M1-50 PR (scope and time unknown until the first run; mixes app changes into a test PR).

## Traceability

| Requirement | PR, step | Checked by |
|---|---|---|
| Guest plays a game | M1-50.7 `guest-game.spec.ts` | 3 projects; reload mutation |
| Register and login | M1-50.7 `auth.spec.ts` (test 1) | 3 projects; session mutation |
| Reset password | BE-E2E.1-4; M1-50.6 `reset-link.ts`, M1-50.7 `auth.spec.ts` (test 2) | backend log test; 3 projects; `FRONTEND_URL` mutation |
| Language switch | M1-50.7 `language.spec.ts` | 3 projects; save mutation |
| Archive | M1-50.7 `archive.spec.ts` | 3 projects; today-row mutation |
| Desktop, phone, tablet | M1-50.5 projects (R-4) | 15 runs per CI run |
| axe | M1-50.6 `axe.ts`, nine states (R-5) | any non-listed violation fails |
| Green in CI | M1-50.8 `e2e.yml` | the PR's `e2e` job; then a required check |
| No real content, no content DB, no `.env` | R-8, R-10, M1-50.3-4 | committed `backend-env.ts`; dev seed only |
| Flake control | R-6, M1-50.2 lint rules | `--repeat-each=3`; `retries: 1` in CI with traces |
