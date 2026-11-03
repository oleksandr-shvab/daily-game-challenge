# Phase 1 backend: CSRF Origin check, games, puzzles, guesses, progress, stats, media — Implementation Plan

Status: draft, 2026-11-02. Scope: the backend repo `my-list-be/` and the platform files `CONTRACTS.md` and the root `CLAUDE.md`. The frontend plan is `plans/02-phase-1-frontend.md`, written in parallel; its F1, F2, F3 and G-M1-xx PRs line up with the backend PRs below by task id. Line numbers were checked against backend `main` at `365c671` and the platform repo at `116b3cf`.

## Source requirements

- Spec: `specs/02-phase-1-backend-core-games.md` (SPEC-02, agreed 2026-11-02 with the owner's answers Q1 to Q20). The answers table wins over older text in `SPEC.md`, `MILESTONE-1.md` and `ARCHITECTURE.md`.
- Decision 67 (`SPEC.md:81`) records the same answers.
- Tasks: `MILESTONE-1.md` Phase 1 (`:57-72`): M1-10 to M1-18 and M1-41. This plan is also the backend half of M1-09: it fixes the module contract and the puzzle model in code.
- Backend criteria this plan implements: **AC-1 to AC-6, AC-9 to AC-88**, including the "b" criteria (AC-13b, AC-17b, AC-70b, AC-72b, AC-72c as a manual check, AC-74b as limits the seed files must meet).
- Frontend criteria (not built here, handed off): **AC-7, AC-8, AC-89**, and the frontend half of AC-52, AC-54, AC-75 and AC-79.
- Context read: `ARCHITECTURE.md` sections 2, 5, 7, 9, 10, 12, 14; `CONTRACTS.md` (all); `MILESTONE-1.md` sections 4 to 7; `plans/01-phase-0-backend.md` (format and local test setup).

## Clarifications & recommendations

No questions could be asked. The owner's decisions given with the task are applied as fixed. Everything marked **Recommendation** is my judgment, not spec text. Items that need the owner are under "Open points".

**Decided by the owner for this plan (2026-11-02):** execution is one agent per PR, each checked by `plan-verifier`, and the owner merges. Commits, pushes and PRs happen only when the owner asks.

**Query layer: `app/crud/`, not `app/<domain>/repository.py`.** `my-list-be/CLAUDE.md:79-81` says the query layer is `app/crud/`. The `fastapi-service-patterns` skill (`SKILL.md:9-11`, `:26-29`) says `app/<domain>/repository.py`. The code follows `CLAUDE.md` (`app/crud/user.py`, `session.py`, `password_reset.py`). **Choice: `app/crud/<entity>.py`.** Reasons:
1. It is what exists, so nothing moves.
2. The game data is shared across routes: puzzles, titles and progress are read by the view, guess, resume, archive, stats, merge and media code. Per-domain repositories would have the domains importing each other's repository files. One entity-keyed query layer avoids that.
3. `CLAUDE.md` is the document Phase 0 made true (B3).

PR M1-10a updates the skill's two passages to say `app/crud/<entity>.py` and changes nothing else in the skill.

**Recommendations on design:**
- **R-1. Plural table names** (`games`, `titles`, `puzzles`, `puzzle_clues`, `clue_media_files`, `progress`, `progress_guesses`). This matches the existing `users` table. SPEC-02 names the tables in the singular as concepts. The column sets are exactly the spec's.
- **R-2. Stored guesses go in a child table `progress_guesses`** (progress, position, `title_id` nullable for a skip), not in a JSON column. AC-11 requires that a title referenced by a stored guess cannot be deleted. Only a foreign key with `ON DELETE RESTRICT` gives that. A partial unique index on (progress, title) where the title is not null is a database-level guard behind AC-31.
- **R-3. Integer identity keys for the new tables.** `users` keeps its UUID. Title ids are public: the search returns them and guesses send them. Puzzle and progress ids never leave the server (AC-5).
- **R-4. A variant is valid in Phase 1 only when it equals the game's `default_variant`.** AC-9 gives the game no list of variants, and other variants are a non-goal. A variants list arrives with the word game. The default variant's name is an open point (default: `default`).
- **R-5. Visibility is one SQL predicate** in `app/crud/puzzle.py`. Every puzzle query takes it: view, today, resume, guess, archive, merge and the media lookup. There is no second Python copy (AC-12).
- **R-6. The game module is pure.** It works on plain data (puzzle, clues, answer, guessed titles, progress state) and does no database or network I/O. Guest replay and account storage then call the same `submit_guess` (AC-44). The service loads data, calls the module and stores the result. Media signing is a function passed in, so the module stays testable without storage.
- **R-7. An injected clock.** `app/core/clock.py` provides "now" as a FastAPI dependency. Services take `now` as a parameter, and tests override the dependency. This covers AC-36, AC-69 and the S18 and S19 rows.
- **R-8. The CSRF check is one pure ASGI middleware** (`app/core/csrf.py`), added before the CORS middleware in `app/main.py`. `add_middleware` wraps in reverse order (`app/main.py:43-52`), so this makes it the innermost middleware: its 403 and 415 responses still get `X-Request-ID` from `RequestIdMiddleware`. It runs before routing, dependencies and body parsing, which is the "before any other check" of AC-83. It checks unsafe methods on every path, not only `/v1`. No other path has unsafe routes, and "every later route" is covered by construction.
- **R-9. The Origin check compares only against the allowed-origins list, never against `Host`.** The Vite proxy rewrites `Host` (`changeOrigin: true`, `my-list-fe/vite.config.ts:23`) and passes `Origin` and `Referer` through unchanged (verified by the frontend plan in Vite 8.2.2). Origins are compared after both sides are serialized the same way: scheme and host in lower case, default ports dropped. The list is read from `settings` on each request, so a test can switch `ENVIRONMENT`.
- **R-10. The JSON-only rule (AC-76) applies only to requests that carry a body.** A request counts as having a body when `Content-Length` is greater than 0 or `Transfer-Encoding` is present. Logout sends no body and must never get 415. When a body is present, the media type before any `;` must be `application/json`, compared case-insensitively. A charset parameter is allowed. This is needed because FastAPI's default `strict_content_type` turns a non-JSON body into a 422 for a missing body, not a 415 (`.venv/.../fastapi/routing.py:389`, `:436-446`).
- **R-11. The API's own origin is a new setting, `API_BASE_URL`** (default `http://localhost:8000`). It is allowed only in `local` and `test` (AC-86, Q19).
- **R-12. Every problem-details response gets `Cache-Control: no-store`.** This is set once in `problem_response` (`app/core/errors.py:92`) in PR M1-41, and covers AC-77's "any error response" row for all routes, auth included. ARCHITECTURE 7 already asks for `no-store` on auth responses.
- **R-13. Strict dates.** Pydantic's lax `date` accepts integers as Unix timestamps. Path and query dates (`date`, `before`) therefore use a string with the pattern `^\d{4}-\d{2}-\d{2}$`, then `date.fromisoformat`. A bad value gives 422 `validation_error` with `field: "date"`.
- **R-14. Field names in validation errors drop the `path.` and `query.` prefixes,** as they already drop `body` (`app/core/errors.py:108`). AC-17 wants `field: "date"`, not `path.date`. No existing route has path or query parameters, so nothing existing changes.
- **R-15. List errors get the `max` parameter.** Add Pydantic's list `too_long` type to `VALIDATION_PARAMS` (`app/core/errors.py:62-65`), so a merge with more than 500 entries gives `{"field": "entries", "code": "too_long", "params": {"max": 500}}` (AC-62).
- **R-16. List responses are objects** (`{"items": [...]}` for games and titles; archive adds `next_before`). This keeps later additions non-breaking.
- **R-17. The local media route is left out of the OpenAPI document** (`include_in_schema=False`, GET and HEAD). The frontend never calls it through the generated client: links are opaque URLs taken from the view. FastAPI's `APIRoute` does not add HEAD to a GET route (`fastapi/routing.py:1019-1021`, unlike Starlette's `routing.py:237-238`). One `api_route` with both methods in the schema would emit two operations with the same id. `CONTRACTS.md` documents the route.
- **R-18. Byte ranges reuse Starlette's `FileResponse`,** which in 1.6.0 already answers a single range with 206 and `Content-Range`, sets `Accept-Ranges`, and handles HEAD (`starlette/responses.py:319`, `:395-414`). Two gaps against AC-72b and the edge table:
  - a malformed `Range` gets a plain-text 400, not 416 (`:370-371`);
  - its 416 is plain text without our headers (`:372-373`).

  So the route parses `Range` itself first:
  - one valid range: Starlette serves it;
  - a malformed or unsatisfiable range: our own 416, with `Content-Range: bytes */<size>` and a problem body (code `range_not_satisfiable`);
  - several ranges: the full file with 200, which RFC 9110 allows (Starlette would answer `multipart/byteranges`, which nothing in our stack needs).

  The signature and expiry are checked before any of this (AC-72b: an expired link with `Range` gets 403).
- **R-19. The media route rechecks visibility.** It looks up the file by key through the visibility predicate (R-5). A link to a puzzle that stopped being visible gets 404 `puzzle_not_found`, as in the spec's edge table "for every route including media". The lookup also gives the stored content type (AC-72). Cost: one indexed query per request.
- **R-20. Local media links are absolute and go through the frontend's proxy.** A new setting `MEDIA_LOCAL_BASE_URL` (default `http://localhost:5173/api`) gives links that load from the frontend page in dev with no CORS and no cookie (AC-72). In production with local storage (the AC-72c fallback) it is `https://<site>/api`.
- **R-21. Seed media are committed placeholder files made by us.** They are five WebP images, one H.264 MP4 clip of 12 seconds without audio, and a WebP poster, generated once with ffmpeg in a throwaway Docker container from ffmpeg's built-in test patterns, together under 1 MB. A small manifest records each file's size and duration. This machine has no ffmpeg and no Pillow (checked), and CI never runs the seed. The exact commands go in a README beside the files. See Open point 4.
- **R-22. Merge entries with no guesses are rejected** with code `invalid_guess_history`, because there is nothing to store. A second entry for the same date and variant in one request counts as `already_present`.
- **R-23. Merged rows get `started_at` = now** (and `finished_at` = now when finished). The streak uses the puzzle's date, not these times (AC-49).
- **R-24. A cap on request lists, separate from the AC-39 rule.** The AC-39 count rule (5 on a guess, 6 on a resume or merge entry) must answer `invalid_guess_history`, not `validation_error`. So schemas cap `previous` and `guesses` at 20 entries (a size guard that gives `validation_error`), and the replay applies the AC-39 rule. Accounts never reach the replay (AC-41).

**Findings to report:**
- The root `CLAUDE.md:9` says the backend uses "pip + `.venv`", and line 14 uses `.venv/bin/pytest`. The backend uses uv (`my-list-be/CLAUDE.md:9`, `:70`). PR M1-41's platform commit fixes both lines.
- `MILESTONE-1.md:57` heads Phase 1 "about 6 days", but its task table (`:61-72`) sums to 8.6 days. SPEC-02 (`:438`) says "about 5.7 days". This plan estimates 8.0 backend days (Open point 9).
- CORS `expose_headers` lists only `X-Request-ID` (`app/main.py:50`). **No change is needed.** The frontend reaches the API through the proxy (same origin), so CORS never applies to its reads. `<img>` and `<video>` sources need no CORS. `allow_headers` still lists `X-Requested-With` (`app/main.py:49`). It is harmless, and after Q18 nothing sends it. Left as it is, to keep PR M1-41 small.
- A single-member discriminated union is refused by Pydantic, which needs at least two members. So the view is one model with `type: Literal["game_guesser"]` now (AC-3). The second game turns it into a union; that later PR checks whether oasdiff calls that change breaking.

## Execution mode

- **Owner's choice (2026-11-02):** one `implementer` run per PR, on that PR's section only. Then one `plan-verifier` run against that PR's acceptance checks. The owner merges. `shvab:implement-plan` runs exactly this loop for one section.
- **My recommendation for the extra code-review pass** (`code-review`, `high` effort, after `plan-verifier` passes):

| PR | Review | Why |
|---|---|---|
| M1-41 | `code-review` high, plus `security-review` | Every unsafe request passes through it; origin parsing is easy to get subtly wrong (suffix, port, `null`, Referer) |
| M1-12 | `code-review` high | Guess rules, replay, the answer and unearned-step leak rule |
| M1-13 | `code-review` high | Account progress is authoritative; row locking and the first-guess insert race (AC-45); forged `previous` |
| M1-15 | `code-review` high | Merge trusts client data; idempotence and per-entry rejection |
| M1-18 | `code-review` high, plus `security-review` | Signed links, constant-time comparison, path traversal through the key, byte ranges, the S3 adapter |
| M1-14 | optional, `medium` | Pure rules, fully pinned by the S1 to S19 and T1 to T3 tables |
| others | none | `plan-verifier` is enough |

**Owner's change (2026-11-03, after the M1-10a review):** every backend PR that adds a migration or a route (all except M1-17) gets `code-review` at `high` (up to two fix rounds) and then `test-writer`, before its commit. The rows above keep their `security-review` passes. On M1-10a these extra steps found a migration that failed on an empty database and a visibility query that crashed.

- Commits, pushes and PRs only when the owner asks. Squash merge (`ARCHITECTURE.md:156`). `main` has no branch protection, so "CI green before merge" is checked by hand: lint, test, migrations, openapi.
- **Merge order with the frontend:** the owner merges a backend PR that changes the OpenAPI snapshot only once its frontend regeneration PR (G-M1-xx) is ready. The red `api-types` window is then minutes (frontend plan "Assumptions about the backend").

## Modules affected

| Where | What | PR |
|---|---|---|
| `app/core/csrf.py` (new), `app/main.py`, `app/core/config.py`, `app/core/errors.py`, `app/core/exceptions.py` | Origin and JSON-only checks; `no-store` on errors; new error classes; `API_BASE_URL` | M1-41 |
| `tests/conftest.py`, `tests/test_csrf.py` (new) | Default allowed `Origin` on the test client; Origin table | M1-41 |
| `app/core/db.py`, `app/alembic/env.py`, `app/models/` (`game.py`, `title.py`, `puzzle.py` new), migration, `app/crud/puzzle.py` (visibility), `app/core/clock.py` (new), `tests/factories.py` (new) | Naming convention, schema, visibility, clock | M1-10a |
| `app/games/` (new: `router.py`, `schemas.py`, `service.py`, `modules/`), `app/api/main.py`, `app/api/deps.py`, `app/crud/game.py`, `scripts/seed_dev.py` (new) | Game list, puzzle view, optional user, dev seed | M1-10 |
| `app/clock/router.py`, `app/clock/schemas.py` (new) | `GET /v1/clock` | M1-17 |
| migration, `app/crud/title.py`, `app/games/normalize.py`, `tests/conftest.py` | `pg_trgm`, title search | M1-11 |
| `app/games/modules/game_guesser.py`, `app/games/service.py`, `app/games/router.py` | Guess rules, guest guess route | M1-12 |
| `app/models/progress.py`, migration, `app/crud/progress.py`, `app/games/service.py`, `app/games/router.py` | Account progress, resume | M1-13 |
| `app/media/` (new: `storage.py`, `signing.py`, `router.py`), `app/core/config.py`, `scripts/seed_media/` (new), `scripts/check_s3_range.py` (new), `pyproject.toml`, `uv.lock` (boto3), `.gitignore` | Signed media, byte ranges, S3 adapter | M1-18 |
| `app/games/stats.py` (new), `app/games/router.py` | Stats and streak | M1-14 |
| `app/games/service.py`, `app/games/router.py` | Guest merge | M1-15 |
| `app/crud/puzzle.py`, `app/games/router.py` | Archive | M1-16 |
| `openapi/openapi.json` | Snapshot | every PR that changes a route or schema |
| `my-list-be/CLAUDE.md`, `.env.example`, `.claude/skills/fastapi-service-patterns/SKILL.md` | Docs for each PR's part (AC-80); query-layer wording | each PR; skill in M1-10a |
| `CONTRACTS.md`, root `CLAUDE.md` (platform repo) | Auth and Errors (M1-41), "Games" section grown per PR (AC-78); pip to uv (M1-41) | each PR's platform commit |

Not touched: `app/auth/` logic, `app/crud/session.py`, `app/crud/password_reset.py`, `.github/workflows/ci.yml` (all four jobs already cover the new work; see Verification).

## Facts found (file:line)

| Fact | Where |
|---|---|
| Tests build the schema with `Base.metadata.create_all`, with no extensions | `tests/conftest.py:48-49`; CI comment `ci.yml:71` |
| Alembic imports only `User` | `app/alembic/env.py:11` |
| `Base` has no naming convention | `app/core/db.py:9-10` |
| Existing names: index `ix_users_email` (matches the planned convention); primary key is Postgres's default `users_pkey` | `app/alembic/versions/315bf276b828_add_user_model.py:42-44` |
| Only a raising current-user dependency exists; no optional variant | `app/api/deps.py:16-31` |
| CORS: `allow_headers` includes `X-Requested-With`; `expose_headers` only `X-Request-ID`; `RequestIdMiddleware` is added last (outermost) | `app/main.py:43-52` |
| Problem responses are built in one function; headers at line 92 | `app/core/errors.py:72-98` |
| Validation `field` drops only `body` from `loc` | `app/core/errors.py:108` |
| `VALIDATION_PARAMS` covers only string lengths | `app/core/errors.py:62-65` |
| `HTTP_STATUS_CODES` has no 415 or 416 | `app/core/errors.py:41-51` |
| Error classes follow one pattern (`status_code`, `code`, `detail`) | `app/core/exceptions.py:4-52` |
| Operation ids are `<tag>_<route name>` | `app/core/openapi.py:4-8` |
| Only the auth router is mounted | `app/api/main.py:6` |
| The test client has `base_url="http://test"` and no default headers | `tests/conftest.py:79` |
| 12 unsafe requests in existing tests: `test_auth.py` 6, `test_errors.py` 3, `test_password_reset.py` 2, `test_password_update.py` 1; 28 tests in all (with parametrize) | `grep -c client.post tests/*.py` |
| FastAPI `strict_content_type` defaults to true: a non-JSON body is left unparsed, giving 422 for a missing body, not 415 | `.venv/lib/python3.12/site-packages/fastapi/routing.py:389`, `:436-446` |
| FastAPI `APIRoute` does not add HEAD to GET; Starlette `Route` does | `fastapi/routing.py:1019-1021`; `starlette/routing.py:237-238` |
| Starlette 1.6.0 `FileResponse`: `Accept-Ranges` default, single range 206, several ranges multipart, malformed 400 plain text, unsatisfiable 416 plain text | `starlette/responses.py:319`, `:370-373`, `:395-414`, `:420-445` |
| Versions: FastAPI 0.141.1, Starlette 1.6.0, SQLAlchemy 2.0.52, Alembic 1.19.1, Pydantic 2.13.4 | `uv.lock:6,222,384,542,567` |
| The migrations and openapi jobs install with `--no-dev`, so anything the app imports must be a runtime dependency | `ci.yml:91`, `:114` |
| oasdiff fails the openapi job on a breaking change unless the PR has the `breaking-change` label | `ci.yml:129-137` |
| Settings has `FRONTEND_URL` and `BACKEND_CORS_ORIGINS`; deployed environments refuse localhost CORS origins | `app/core/config.py:35-37`, `:58-62` |
| The skill places queries in `app/<domain>/repository.py`; `CLAUDE.md` in `app/crud/` | `SKILL.md:9-11`, `:26-29`; `my-list-be/CLAUDE.md:79-81` |
| The backend `CLAUDE.md` still says `SameSite=Lax` is "judged sufficient" | `my-list-be/CLAUDE.md:93` |
| `CONTRACTS.md` says "No CSRF protection exists yet" | `CONTRACTS.md:36-39` |
| `CONTRACTS.md` error code list | `CONTRACTS.md:100-103` |
| The root `CLAUDE.md` says pip | `CLAUDE.md:9`, `:14` |
| The Vite proxy uses `changeOrigin: true` (Host only) | `my-list-fe/vite.config.ts:20-26` |
| Frontend CI regenerates from the backend `main` snapshot | `my-list-fe/.github/workflows/ci.yml:56-75` |
| Local machine: uv 0.12.5 at `~/.local/bin/uv` (CI pins 0.13.6, `ci.yml:19`); no ffmpeg, no Pillow; `dgc-dev-pg` and `dgc-dev-redis` exist (stopped); port 5433 is held by `devdigest-postgres` | checked 2026-11-02 |

## Architectural constraints

- Layering: router, then service, then query layer (`app/crud/`), then models (`app/models/`). Dependencies point one way (`my-list-be/CLAUDE.md:79`).
- Thin routers. Services hold business rules. No `select()` or `session.execute()` outside the query layer. No ORM instance returned from a router. One DB session per request through `get_db`. No blocking I/O in async code (`SKILL.md`, "Thin routers", "Query encapsulation", "FastAPI/async-specific").
- Tests: one happy-path route test per endpoint, plus one to three unit tests per feature on the risky logic. Fixtures `client` and `db_session`. Names follow `test__<what>__<expected>` (`SKILL.md`, "Tests"). **Where SPEC-02 demands more** (the S1 to S19 and T1 to T3 tables, the Origin table, the range rows, the visibility table, the guest-versus-account table, the leak scan), **the spec wins**: these tests are acceptance criteria, not corner cases. Keep each as one parametrized table.
- Style: `is_` booleans, `StrEnum` for statuses and kinds, f-strings, no `print()` outside scripts (`SKILL.md`, "Style").
- Every error is an `AppException` subclass with a stable `code`; no English-only `detail` (`my-list-be/CLAUDE.md:13`; `CONTRACTS.md` "Errors").
- After any route or schema change: `uv run python scripts/export_openapi.py` and commit. A breaking change needs the `breaking-change` label (`my-list-be/CLAUDE.md:13`). None is expected in this plan: every change adds something.
- Commit `uv.lock` with any dependency change; CI runs `uv sync --locked` (`my-list-be/CLAUDE.md:41`).
- A boundary change covers the backend, the frontend and `CONTRACTS.md` in one pass. Frontend types are regenerated, never hand-patched (root `CLAUDE.md`, "Working across both repos").
- Unique keys `(game, variant, date)` on puzzles and `(user, game, variant, date)` on progress; `ON DELETE CASCADE` from users; CHECK constraints for statuses; a naming convention before more tables (`ARCHITECTURE.md:164`).
- 404 also for things that must not be revealed, such as a future puzzle (`ARCHITECTURE.md:113`).
- Keyset paging for the archive (`ARCHITECTURE.md:169`).
- Never log bodies, cookies or tokens; log user ids, not emails (`app/core/logging.py:74-75`; `ARCHITECTURE.md:186`).
- Random or content-hash media keys, never date-based; private storage; signed links only for earned steps (`ARCHITECTURE.md:197`).
- Inject `now()` so UTC day-boundary tests are exact (`ARCHITECTURE.md:225`).
- The repos are public: no real puzzle data, screenshots, clips or answer lists in Git (decision 59; `ARCHITECTURE.md:197`).
- Do not install the S3 client until the task needs it; boto3 arrives in M1-18 only (`my-list-be/CLAUDE.md:11`; `ARCHITECTURE.md:191`).
- The test suite drops tables and flushes Redis, so test URLs must differ from dev ones (`tests/conftest.py:11-18`).

## Approach

Order and branches. Each branch starts from a fresh `main` after the previous PR merges. Branch names follow `m1-xx-short-name`.

| # | PR | Branch | ACs | Est. (days) | Snapshot | G PR |
|---|---|---|---|---|---|---|
| 1 | **M1-41** CSRF Origin check, JSON-only | `m1-41-csrf-origin-check` | AC-75 (2 codes), AC-76, AC-77 (errors), AC-78 (Auth), AC-83 to AC-88 | 0.5 | unchanged | none |
| 2 | **M1-10a** schema, naming convention, visibility, clock | `m1-10a-game-schema` | AC-9 to AC-13b, AC-17b, AC-18 (table), AC-12 (predicate) | 0.4 | unchanged | none |
| 3 | **M1-10** game list, puzzle view, dev seed | `m1-10-games-and-puzzle-view` | AC-1, AC-3 to AC-6, AC-12 (routes), AC-14 to AC-17, AC-25 (no media), AC-26 (structure), AC-42 (reads), AC-75 (3 codes), AC-77, AC-78, AC-79, AC-81, AC-82 (no media) | 0.6 | changed | G-M1-10 |
| 4 | **M1-17** clock | `m1-17-clock` | AC-67, AC-68, AC-69 (route) | 0.1 | changed | G-M1-17 |
| 5 | **M1-11** title search | `m1-11-title-search` | AC-19 to AC-24 | 1.0 | changed | G-M1-11 |
| 6 | **M1-12** guess, guest replay | `m1-12-guess` | AC-2, AC-4, AC-26 to AC-34, AC-37, AC-39 (guess), AC-40, AC-75 (4 codes) | 1.3 | changed | G-M1-12 |
| 7 | **M1-13** account progress, resume | `m1-13-progress` | AC-35, AC-36, AC-38, AC-39 (resume), AC-41 to AC-45, AC-69 (flag) | 1.0 | changed | G-M1-13 |
| 8 | **M1-18** clue media | `m1-18-clue-media` | AC-13b (read check), AC-25 (media), AC-70 to AC-74, AC-72b, AC-72c (manual), AC-74b (seed files), AC-75 (1 code), AC-77 (media), AC-82 (media) | 1.3 | changed | G-M1-18 |
| 9 | **M1-14** stats and streak | `m1-14-stats` | AC-46 to AC-54 | 0.8 | changed | G-M1-14 |
| 10 | **M1-15** guest merge | `m1-15-merge` | AC-55 to AC-62 | 0.5 | changed | G-M1-15 |
| 11 | **M1-16** archive | `m1-16-archive` | AC-63 to AC-66 | 0.5 | changed | G-M1-16 |
| | | | | **8.0** | | |

Why this order:
- M1-41 goes first, so no game POST ever ships without the check (SPEC-02 `:438`).
- M1-10 is split so that the migration, naming convention and visibility rule are reviewed on their own, apart from the routes. M1-10a changes no route.
- M1-17 stays its own tiny PR, so its G PR matches the frontend plan.
- M1-13 comes before M1-18 because Phase 2 can start once M1-10, M1-12 and M1-13 are merged (SPEC-02 `:445`). This also matches the frontend plan's assumed order.
- M1-14 comes before M1-15 because the merge test compares stats (AC-61).

Every PR:
1. Updates `my-list-be/CLAUDE.md` for its part (AC-80).
2. Updates `.env.example` for any new setting.
3. Regenerates `openapi/openapi.json` and checks that `git diff` shows only additions.
4. Adds its part to `CONTRACTS.md` in the platform repo. The platform commit is local (no remote) and is made when the PR merges, before the G PR.

### PR M1-41: CSRF Origin check and JSON-only bodies (AC-76, AC-83 to AC-88)

1. `app/core/config.py`:
   - Add `API_BASE_URL: str = "http://localhost:8000"` (R-11).
   - Add a property `allowed_origins`: the origin of `FRONTEND_URL`; plus, only when `ENVIRONMENT` is `local` or `test`, each origin in `BACKEND_CORS_ORIGINS` and the origin of `API_BASE_URL` (AC-86).
   - Serialize origins one way: lower-case scheme and host, default port dropped. No wildcard, no suffix match.
2. `app/core/exceptions.py`: add `CsrfOriginMismatchError` (403, `csrf_origin_mismatch`) and `UnsupportedMediaTypeError` (415, `unsupported_media_type`).
3. `app/core/errors.py`:
   - Add `Cache-Control: no-store` to the headers built in `problem_response` (line 92; R-12).
   - Add `415: "unsupported_media_type"` to `HTTP_STATUS_CODES`.
4. `app/core/csrf.py` (new), a pure ASGI middleware like `RequestIdMiddleware` (`app/core/request_id.py:18-43`):
   - Only HTTP POST, PUT, PATCH and DELETE are checked. GET, HEAD and OPTIONS pass (AC-87).
   - Origin source: the `Origin` header. If it is absent, the origin of `Referer` (AC-84). If neither is present, or the value is `null`, unparsable or appears more than once: 403. If it is not exactly in `settings.allowed_origins`: 403 (AC-85).
   - Then, for POST, PUT and PATCH with a body (R-10): a media type other than `application/json` gives 415 (AC-76).
   - Responses are built with `problem_response` from `app/core/errors.py:72` on a `Request(scope)`, so they carry the contract body, `request_id` and `no-store`.
   - It reads only headers; no database, no Redis.
5. `app/main.py`: add the middleware before the CORS block (R-8), with a one-line comment on why it is innermost.
6. `tests/conftest.py:79`: give the `client` fixture a default header `Origin: http://localhost:5173` (`FRONTEND_URL`'s origin). Every existing and new unsafe request then sends an allowed origin (AC-88). Tests that need no origin remove the header on that request or use a second client.
7. `tests/test_csrf.py` (new), one parametrized table over POST on `/v1/auth/login`, plus one row each for `/v1/auth/logout` (no body), PUT, PATCH and DELETE. For PUT, PATCH and DELETE no route exists, so the expected result is "403 before 405" for a bad origin and 405 for a good one. Rows:
   - allowed `Origin`: passes to the route;
   - `https://evil.example`: 403;
   - no headers: 403;
   - `Referer` only, allowed: passes;
   - `Referer` only, foreign: 403;
   - `Origin: null`: 403;
   - `http://localhost:5174`: 403;
   - `https://localhost:5173`: 403;
   - `http://localhost:5173.evil.example`: 403;
   - `http://localhost:8000`: passes in `test`, and is 403 after monkeypatching `settings.ENVIRONMENT = "production"`.

   Also:
   - a bad origin plus a bad body plus no session gives 403, not 422 or 401 (AC-83);
   - an allowed origin with `Content-Type: text/plain` on login gives 415;
   - logout with no body and no content type gives 204;
   - GET `/healthz` with a foreign `Origin` gives 200;
   - every 403 and 415 carries `Cache-Control: no-store`;
   - one unit test of the origin serializer.
8. Docs:
   - `my-list-be/CLAUDE.md:93`: replace "`SameSite=Lax` is judged sufficient..." with the rule. Origin, falling back to Referer, is checked first on unsafe methods; JSON-only bodies; `SameSite=Lax` stays as defense in depth; no custom header (Q18). Name the allowed origins per environment, and say that curl needs `-H 'Origin: http://localhost:5173'`.
   - Add `API_BASE_URL` to `.env.example`.
9. Snapshot: run the export. **It does not change**: middleware adds no route or schema, and 403 and 415 are not added to `ERROR_RESPONSES` (they would wrongly appear on GET routes). No G PR (the frontend plan expects none in that case).
10. Platform commit:
    - `CONTRACTS.md:36-39`: replace "No CSRF protection exists yet..." with the Origin rule (AC-83 to AC-87), the JSON-only rule for requests with a body (AC-76), the dev note (use `localhost`; `127.0.0.1:5173` and the preview server on 4173 are not allowed origins; the Vite proxy must keep `Origin`; scripts send `Origin`), and Q18 (no custom header).
    - `CONTRACTS.md:100-103`: add `csrf_origin_mismatch` (403) and `unsupported_media_type` (415), and state that every error response is `Cache-Control: no-store`.
    - Root `CLAUDE.md:9`: "uv (`pyproject.toml`, `uv.lock`)" instead of "pip + `.venv`". Line 14: `cd my-list-be && uv run pytest`.

### PR M1-10a: naming convention, game schema, visibility, clock (AC-9 to AC-13b, AC-17b, AC-18)

1. `app/core/db.py:9-10`: give `Base` a `MetaData(naming_convention=...)` with the usual keys:
   - `ix_%(column_0_label)s`
   - `uq_%(table_name)s_%(column_0_name)s`
   - `ck_%(table_name)s_%(constraint_name)s`
   - `fk_%(table_name)s_%(column_0_name)s_%(referred_table_name)s`
   - `pk_%(table_name)s`

   `ix_users_email` already matches. Before adding any table, run `alembic check` with only this change. Expected: no diff, because Alembic does not compare primary-key names. If it reports one, stop and report.
2. Models: `app/models/game.py`, `title.py`, `puzzle.py`, with constraints named through the convention. All are exported from `app/models/__init__.py`. `app/alembic/env.py:11` imports the package (all models), not only `User`.
   - `games`: `slug` unique, with CHECK `^[a-z0-9]+(-[a-z0-9]+)*$`; `default_variant`; `title_kind`; `launch_date`; `is_enabled`; timestamps (AC-9).
   - `titles`: `kind` (CHECK `video_game`), `name`, `normalized_name`, `franchise` (nullable), `normalized_franchise` (nullable), `year` (nullable), timestamps (AC-18). `normalized_franchise` is a deliberate stored copy: the trigram index in M1-11 needs a column, and the normalizer is Python Unicode code that SQL cannot repeat without `unaccent`. Both normalized columns are set only by `app/crud/title.py` through one normalizer (`app/games/normalize.py`, moved forward from M1-11 because the seed needs it in M1-10).
   - `puzzles`: `game_id` FK, `variant`, `date`, `status` (CHECK `draft`, `in_review`, `approved`, `scheduled`), `answer_title_id` FK to `titles` with `ON DELETE RESTRICT` (AC-11), timestamps; unique `(game_id, variant, date)` (AC-10).
   - `puzzle_clues`: `puzzle_id` FK cascade; `step` (CHECK 1 to 6); `media_type` (CHECK `image`, `video`); `hint_kind`, `hint_value` (CHECK both null or both set); `source_url` nullable; unique `(puzzle_id, step)` (AC-13). `hint_kind` stays free text (other games will have other hints), and its values are documented in the module.
   - `clue_media_files`: `clue_id` FK cascade; `role` (CHECK `source`, `poster`); `key` (indexed, not unique, because content-hash keys can repeat); `content_type` (CHECK `image/webp`, `video/mp4`, `video/webm`); `byte_size`, `width`, `height`; `duration_ms` (CHECK: set exactly when the content type is video); CHECK `role = poster` implies `image/webp`; partial unique `(clue_id, content_type) WHERE role = 'source'` and `(clue_id) WHERE role = 'poster'` (AC-13b).
   - The cross-row rules of AC-13b (a video clue has exactly one MP4 and one poster; an image clue has exactly one image and no poster) cannot be database constraints. The view checks them on read (M1-18) and gives a 500 when they are broken (edge table); the builder (M1-22) checks them on write.
3. One migration: `uv run alembic revision --autogenerate -m "add games titles puzzles clues"`. Review the generated file by hand. Add `ALTER TABLE users RENAME CONSTRAINT users_pkey TO pk_users` (and its reverse in the downgrade), so the migrated database matches the convention used by `create_all` in tests.
4. `app/crud/puzzle.py`: the visibility predicate (R-5): status `scheduled`, `date <= today`, `date >= game.launch_date`, `game.is_enabled` (AC-12). Its docstring says it is the only visibility rule and that a later admin preview widens it here (Q12).
5. `app/core/clock.py`: the `now` dependency (UTC, timezone aware) and a `today` helper (R-7).
6. `tests/factories.py` (new): plain async helpers that create a game, titles and a scheduled puzzle with 6 clues through the session. In M1-18 they also create media rows and files. No factory library.
7. Tests: one parametrized test of the visibility predicate over each status, a future date, a date before launch, a disabled game, today, and yesterday (AC-12). One test that deleting a title referenced by a puzzle raises an integrity error (AC-11).
8. Skill: `fastapi-service-patterns/SKILL.md:9-11` and `:26-29` now name `app/crud/<entity>.py` (Clarifications). `my-list-be/CLAUDE.md`: the models, the naming convention, and the layout rule for game code (`app/games/`, `app/crud/`, `app/models/`).
9. Snapshot unchanged (no route). No `CONTRACTS.md` change, no G PR.

### PR M1-10: game list, puzzle view, dev seed (AC-1, AC-3 to AC-6, AC-14 to AC-17, AC-25, AC-42, AC-81, AC-82)

1. `app/api/deps.py`: add `get_optional_user` and `OptionalUser`, reusing `get_session` and `get_user_by_id` as in `get_current_user` (`:16-28`). A missing, unknown or expired cookie, or an inactive user, gives `None`, never 401 (AC-42, AC-81).
2. `app/core/exceptions.py`: `GameNotFoundError` (404 `game_not_found`), `VariantNotFoundError` (404 `variant_not_found`), `PuzzleNotFoundError` (404 `puzzle_not_found`). Every not-found case uses the same class and default detail, so the bodies differ only in `request_id` (AC-17).
3. `app/core/errors.py:108`: drop `path` and `query` from `loc` as well (R-14).
4. `app/games/modules/` (new):
   - `base.py`: the module contract (AC-2). It names `get_puzzle(puzzle data, progress state, sign) -> view` and `submit_guess(puzzle data, progress state, guess) -> (new state, feedback)` over plain dataclasses (R-6). `submit_guess` is declared here and built in M1-12.
   - `game_guesser.py`: the variant rule (R-4) and `get_puzzle`. In progress, the view shows steps 1 to `guesses_used + 1`; after the end, all six with `source_url` (AC-26). Fewer than six clues on a scheduled puzzle raises, giving a 500 (edge table).
   - `__init__.py`: the registry, slug to module. A game row with no module is treated as `game_not_found`, and a warning is logged.
5. `app/games/schemas.py`:
   - `GameRead` (`slug`, `default_variant`, `launch_date`) and `GameList` (`items`).
   - `GameGuesserView`, with all AC-25 fields: `type` (literal `game_guesser`), `slug`, `variant`, `date`, `number`, `status`, `max_guesses`, `guesses_used`, `guesses_left`, `guesses`, `steps`, `answer`, `counts_for_streak`, `signed_in`. Each step has `step`, `hint` (`kind`, `value`, or null) and `source_url` (null until the end). `media` is added in M1-18; adding a response field is not a breaking change.
   - Guess entries: `title_id`, `name`, `result`.
   - `number` = days since `launch_date` + 1 (Q16).
6. `app/games/service.py`: resolve the game (enabled; else `game_not_found`), then the variant (R-4; else `variant_not_found`), then the visible puzzle (R-5, with `today` from the clock; else `puzzle_not_found`). Then build the view for an empty progress state. In this PR `signed_in` is true when `OptionalUser` is a user, and `counts_for_streak` is `null`. M1-13 adds stored progress.
7. `app/games/router.py` (tag `games`), mounted in `app/api/main.py` at `/games`:
   - `GET /v1/games`: `games_list_games`, `public, max-age=300`.
   - `GET /v1/games/{slug}/puzzles/today`: `games_get_today_puzzle`. Declared **before** the dated route.
   - `GET /v1/games/{slug}/puzzles/{date}`: `games_get_puzzle`, with the strict date (R-13) and optional `variant`.

   Puzzle routes send `private, no-store` (AC-77), through one small helper used by every route.
8. `scripts/seed_dev.py`, run as `uv run python scripts/seed_dev.py`:
   - It exits with a clear message unless `ENVIRONMENT == "local"` (AC-82).
   - It deletes and recreates the `game-guesser` game's data, so re-running it (daily, or after each PR) is safe.
   - It creates the enabled game with `launch_date` = today - 3 and `default_variant` from Open point 1.
   - It creates at least 10 titles with full names: "The Legend of Zelda: Breath of the Wild", "Half-Life 2", "Mario", "Super Mario Bros.", some with franchises, one near-duplicate pair.
   - It creates scheduled puzzles for today and the 3 previous days, one scheduled puzzle for tomorrow and one draft, each with 6 clues and hints, the hints using `null` once.

   No media in this PR; M1-18 adds it.
9. Tests:
   - one route test per endpoint;
   - one table test over the three puzzle routes for each invisible case, checking an identical body apart from `request_id` and `no-store` (AC-17);
   - `variant=nope` gives `variant_not_found`; `2026-02-30` and `20261102` give 422 with `field: "date"`;
   - a request with an unknown cookie answers with `signed_in: false`, and one with no cookie also works (AC-42, AC-81);
   - an injected clock at 23:59:59 and 00:00:00 UTC shows tomorrow's puzzle turning visible exactly at midnight (AC-69);
   - one test asserts the view at step 1 has exactly one step, `answer: null`, and none of the answer title's id or name (AC-4).
10. Docs: `my-list-be/CLAUDE.md` gets the game domain and how to seed a local game (AC-80).
11. Snapshot: new paths and schemas only.
12. Platform: `CONTRACTS.md` gets a new "Games" section with:
    - the routes;
    - the slug, variant and date rules;
    - the identical 404s;
    - the view shape;
    - `signed_in`, with the sentence from the frontend plan's F2: "A game response with `signed_in: false` while the frontend shows a user means the session ended; the frontend switches to signed out, as for a 401.";
    - the cache table;
    - the three new codes in "Errors".

### PR M1-17: clock (AC-67 to AC-69)

1. `app/clock/schemas.py` and `app/clock/router.py` (tag `clock`, operation `clock_get_clock`): `GET /v1/clock` returns `now`, `today` and `next_reset` from the clock dependency, with `Cache-Control: no-store`. No `SessionDep` (AC-67).
2. Tests: a fixed clock gives exact values, including at 23:59:59 and 00:00:00. A test overrides `get_db` with a function that raises, and the route still answers 200 (no database).
3. Snapshot; `CONTRACTS.md` "Games" gets a "Clock" paragraph: display only, the server owns "today" (AC-69).

### PR M1-11: title search (AC-19 to AC-24)

1. A migration with `CREATE EXTENSION IF NOT EXISTS pg_trgm` (AC-23), plus GIN `gin_trgm_ops` indexes on `titles.normalized_name` and `titles.normalized_franchise`, declared on the model (`postgresql_using`, `postgresql_ops`) so `alembic check` agrees. The downgrade drops the indexes, then the extension. `pg_trgm` is a trusted extension, so a database owner can create it without being a superuser (relevant for the Phase 4 migrator role).
2. `tests/conftest.py:48`: run `CREATE EXTENSION IF NOT EXISTS pg_trgm` in the same `begin()` block, before `create_all` (AC-23).
3. `app/games/normalize.py` (from M1-10a): NFKD, drop combining marks, casefold, turn every non-alphanumeric character into a space, collapse spaces, trim. "Half-Life 2" becomes "half life 2".
4. `app/crud/title.py` search, in one statement:
   - set the word-similarity threshold to 0.4 for the transaction with `set_config(..., true)` (SPEC-02 research note `:448`);
   - filter by the game's `title_kind`, and by `q` matching the name or the franchise through the trigram operator;
   - order by exact normalized match, then `starts_with(normalized_name, q)`, then the higher of the two word similarities, then name, then id;
   - limit 200 (AC-21).

   `starts_with` and the trigram operators have no wildcards, and normalization removes `%`, `_` and backslashes, so user text never acts as a pattern (AC-22). The text is always a bound parameter.
5. Route `GET /v1/games/{slug}/titles` (`games_search_titles`): `q` is required with `max_length=100`, so a longer value gives 422 `too_long` (AC-20). A trimmed `q` under 2 characters, or a normalized `q` that is empty, gives `{"items": []}`. The response is `public, max-age=300`. Items have `id`, `name`, `franchise` and `year`, and no answer marker (AC-19).
6. Tests, on real Postgres with full-title fixtures, as one table:
   - "zlda" finds the Zelda title;
   - "half life" finds "Half-Life 2";
   - "mario" lists "Mario" before "Super Mario Bros.";
   - 250 matching titles return 200;
   - nonsense returns few or none;
   - `%`, `a_b` and a backslash do not return everything;
   - empty and one-letter `q` give empty lists;
   - 101 characters gives 422.
7. AC-24 is a manual benchmark: `scripts/bench_title_search.py` inserts 50,000 synthetic titles into the **dev** database (refusing outside `local`), times 200 searches, prints p95, and removes its rows. Not in CI.
8. Snapshot; `CONTRACTS.md` gets a search paragraph (the `q` rules, the 200 cap, the year in the list).

### PR M1-12: guess and guest replay (AC-2, AC-4, AC-26 to AC-34, AC-37, AC-39, AC-40)

1. `game_guesser.submit_guess` (pure):
   - A skip (`title_id` null) is `skipped` and never gets the franchise flag.
   - A guess is correct when it is the answer title or has the same normalized name (Q9).
   - A wrong guess gets `franchise` when both normalized franchises are present and equal. A missing franchise never matches (AC-28).
   - A correct guess gives `won`. A sixth guess or skip that is not correct gives `lost` (AC-29).
   - Score = guesses used, skips included (AC-30).

   The module raises its own errors: duplicate title, title not of the game's kind, already finished.
2. `app/games/service.py` guest flow:
   - Load every title in `previous` plus the new one in one query, filtered by kind.
   - Replay `previous` with `submit_guess`. During the replay, any error, more than 5 entries, or an entry after a win gives `invalid_guess_history` (AC-39). If the replay ends the game, the new guess gives `puzzle_already_finished`.
   - Apply the new guess. Here a duplicate gives `duplicate_guess` (AC-31), an unknown title or a title of another kind gives `title_not_found` (AC-32), and a finished game gives `puzzle_already_finished` (AC-33).
   - Store nothing (AC-37).
   - `counts_for_streak` is today == puzzle date when `previous` is empty, and `null` otherwise (AC-40).
3. New exceptions: `TitleNotFoundError` (422), `DuplicateGuessError` (422), `InvalidGuessHistoryError` (422), `PuzzleAlreadyFinishedError` (409).
4. Route `POST /v1/games/{slug}/puzzles/{date}/guesses` (`games_submit_guess`): body `{title_id: int | null, previous: list[int | null]}` capped at 20 (R-24). The response is the new view (AC-34), `private, no-store`. Account requests behave like guests until M1-13. That is acceptable because nothing is stored yet and M1-13 follows directly; `CONTRACTS.md` says so until M1-13.
5. Tests:
   - pure unit tests of `submit_guess`, one table: win, lose, skip, franchise, null franchise on either side, near-duplicate correct, duplicate, after finish;
   - a route test that walks a full won game and a full lost game, scanning every response body for the answer's id and name until the end (AC-29);
   - a step-count check at each step (AC-26);
   - route rows for each AC-39 case and each new code;
   - `counts_for_streak` with the injected clock, both sides of midnight.
6. Snapshot; `CONTRACTS.md` "Games" gets the guess rules, `previous` (the guest keeps its own list and the first `counts_for_streak`), and the four codes.

### PR M1-13: account progress and resume (AC-35, AC-36, AC-38, AC-41 to AC-45)

1. `app/models/progress.py` and a migration:
   - `progress`: `user_id` FK to `users` `ON DELETE CASCADE`; `puzzle_id` FK; `status` (CHECK `in_progress`, `won`, `lost`); `started_at`; `finished_at`; `counts_for_streak`; `is_test` (server default false); `origin` (CHECK `play`, `merge`); unique `(user_id, puzzle_id)` (AC-35).
   - `progress_guesses` (R-2): `progress_id` FK cascade; `position`; `title_id` FK `RESTRICT`, nullable; unique `(progress_id, position)`; partial unique `(progress_id, title_id) WHERE title_id IS NOT NULL`.
2. `app/crud/progress.py`:
   - "get or create for update": `INSERT ... ON CONFLICT (user_id, puzzle_id) DO NOTHING`, then `SELECT ... FOR UPDATE`. Two first guesses at once cannot both insert, and later guesses run one after another (AC-45).
   - The `INSERT` sets `counts_for_streak` from the clock at that moment, and nothing ever updates it (AC-36).
   - Rows are created only on a guess, never on a view or resume.
3. Service account flow:
   - Ignore `previous` entirely (AC-41).
   - Lock the row, build the state from the stored guesses, apply the guess with the same `submit_guess`, append the guess row, set the status and `finished_at`, commit.
   - The view's `counts_for_streak` is the stored value.
   - `is_test` is never set or returned (AC-43).
   - View, today and resume read the stored row when there is one.
4. Route `POST /v1/games/{slug}/puzzles/{date}/resume` (`games_resume_puzzle`): body `{previous}`. A guest gets the replay, with at most 6 entries; a replay that ends the game returns the finished view (AC-38, AC-39). An account gets the stored state. Nothing changes in either case. `private, no-store`.
5. Tests:
   - the forged-`previous` test of AC-41;
   - one table-driven test running the same sequences as a guest and as an account, comparing views apart from `signed_in`, `counts_for_streak` and links (AC-44);
   - S18 and S19 at the flag level with the injected clock (AC-36);
   - deleting a user deletes its progress (AC-35);
   - **AC-45 concurrency:** it cannot use the `client` fixture, because one connection is shared by a savepoint. A dedicated fixture commits a user, a game and a puzzle through the session-scoped `engine`, runs two service calls on two independent sessions with `asyncio.gather` (two skips: both stored, positions 1 and 2; two identical title guesses: one stored, one `duplicate_guess`), and truncates the game tables and `users` in a `finally` block.
6. Snapshot; `CONTRACTS.md` gets the account rules (the server copy wins; `previous` is ignored), resume, and `signed_in`.

### PR M1-18: clue media, signed links, byte ranges (AC-25 media, AC-70 to AC-74b, AC-82 media)

**Carried over from M1-10 (owner, 2026-11-03):** M1-10 shipped `GameModule.get_puzzle(puzzle, state, *, is_signed_in)` without the `sign` parameter, since there was no media to sign. This PR adds `sign` to the contract in `app/games/modules/base.py` and to `game_guesser.py`, and passes the signer from the service.

1. `uv add boto3` (runtime: the app imports it, and CI's `--no-dev` jobs must install it). Lock with CI's uv version (Risks).
2. Settings (`app/core/config.py`):
   - `MEDIA_STORAGE` (`local` or `s3`, default `local`);
   - `MEDIA_LOCAL_DIR` (default `var/media`, which goes into `.gitignore`);
   - `MEDIA_LOCAL_BASE_URL` (R-20);
   - `MEDIA_SIGNING_KEY` (secret, separate from `SECRET_KEY`);
   - `MEDIA_IMAGE_LINK_TTL_SECONDS` (600, bounded 60 to 3600; AC-70);
   - `MEDIA_VIDEO_LINK_TTL_SECONDS` (3600, bounded 600 to 86400; AC-70b);
   - `S3_ENDPOINT_URL`, `S3_REGION`, `S3_BUCKET`, `S3_ACCESS_KEY_ID`, `S3_SECRET_ACCESS_KEY` (secret).

   The deployed-config validator refuses `s3` with any S3 value missing, and `local` with a placeholder or short `MEDIA_SIGNING_KEY` (the AC-72c fallback can make `local` real in production).
3. `app/media/signing.py`: HMAC-SHA256 over the key and the expiry, base64url. Comparison with `hmac.compare_digest` (spec "Untrusted inputs").
4. `app/media/storage.py`: an interface `signed_url(key, kind) -> (url, expires_at)` with two implementations.
   - Local: `{MEDIA_LOCAL_BASE_URL}/v1/media/{key}?exp=&sig=`.
   - S3: boto3 `generate_presigned_url` for `get_object`, SigV4, with `ResponseCacheControl` set to `private, max-age=<ttl>`. Presigning computes a signature locally and does no network I/O, so calling it from async code does not block; a code comment says so, because the skill bans blocking boto3 calls.

   The lifetime is chosen by content type: video uses the video TTL; images and posters use the image TTL.
5. `app/media/router.py`, `GET` and `HEAD` `/v1/media/{key}`, outside the schema (R-17). Steps:
   - Check the key against `^[a-f0-9]{64}$` (no path traversal).
   - Check the signature and expiry: failure gives 403 `invalid_media_link`, revealing nothing (AC-73).
   - Look up the file through the visibility predicate (R-19).
   - Check `Range` (R-18).
   - Serve with Starlette `FileResponse`, using the stored content type, `X-Content-Type-Options: nosniff`, and `Cache-Control: private, max-age=<remaining lifetime>` (AC-72, AC-77).
   - Its 403, 404 and 416 also carry `nosniff`.
   - New: `InvalidMediaLinkError` (403) and the 416 code `range_not_satisfiable` (Open point 3).
6. View: each earned step gets `media`:
   - `type` (`image` or `video`), `width`, `height`, `expires_at`;
   - `sources`: `{url, content_type}`; WebM first when present, MP4 last; one entry for an image;
   - `poster`: `{url, content_type, expires_at}` for a video, `null` for an image (AC-25).

   Links are made only for steps in the view, which holds only earned steps of a visible puzzle (AC-71). On read, the AC-13b cross-row rules are checked, and a break raises, giving a 500.
7. Seed media (R-21):
   - `scripts/seed_media/` holds the 7 placeholder files, `manifest.json` (content type, width, height, duration), and a README with the ffmpeg commands that made them. The clip is H.264 `yuv420p` with `+faststart`, no audio, 12 s, 640x360 or smaller, well inside AC-74b; the images and poster are WebP at 1280x720 or smaller.
   - `seed_dev.py` copies them into `MEDIA_LOCAL_DIR` under their SHA-256 keys and creates the `clue_media_files` rows.
8. `scripts/check_s3_range.py` for AC-72c, manual and not in CI:
   - It uploads the seed clip to the configured bucket, presigns a GET, and asks for `Range: bytes=0-1` and `bytes=100-`; it expects 206 and a correct `Content-Range`.
   - It prints the presigned URL so a person can open it in a `<video>` in Chrome and Safari.
   - It deletes the object at the end.
9. Tests:
   - signer unit tests (valid, expired, tampered; image and video lifetimes);
   - one route table with `MEDIA_LOCAL_DIR` on `tmp_path`: full GET (200, `Accept-Ranges`, content type, `nosniff`, `max-age` no longer than the remaining lifetime); HEAD; `bytes=0-1`; `bytes=100-`; `bytes=-500`; an unsatisfiable range (416 with `bytes */<size>`); a malformed range (416); an expired link with `Range` (403); a bad signature (403); a puzzle unscheduled after issue (404);
   - a view test at step 1: no key or URL of steps 2 to 6 or the poster anywhere in the body (AC-71);
   - the step-6 shape: video, MP4 last, poster signed;
   - one S3 presign unit test with fake credentials: the URL has the bucket host, `X-Amz-Expires` equals the video TTL, and the request makes no network call.
10. Docs: `my-list-be/CLAUDE.md:11`, `:76`: boto3 is now installed; the storage settings; seeding media (AC-80).
11. Snapshot (adds `media` and its models); `CONTRACTS.md` gets the media shape, signed links (bearer links, refetch on 403), byte ranges, lifetimes, the AC-74b limits table, and `invalid_media_link`.

### PR M1-14: stats and streak (AC-46 to AC-54)

1. `app/games/stats.py`, pure functions. Streak days are the puzzle dates of finished, `counts_for_streak`, default-variant, non-test rows (AC-49).
   - The run continues across a gap of 1 to 3 missed days without adding to it; a gap of 4 or more starts a new run.
   - `current_streak` is the last run's length while the missed days after the last streak day, not counting today, are 3 or fewer; otherwise 0.
   - `max_streak` is the longest run (AC-50).
   - Counters: `played` counts won and lost rows; `wins`; `distribution` has keys 1 to 6 with zeros (AC-47, AC-54).
2. `app/crud/progress.py`: one query for the account's rows for a game and variant, `is_test` false (AC-48), with puzzle date, status, guess count and `counts_for_streak`.
3. Route `GET /v1/games/{slug}/stats` (`games_get_stats`): `CurrentUser`, so a guest gets 401 `not_authenticated` (AC-46). Optional `variant`. For a variant other than the default, the streak fields are `null` (AC-51). `private, no-store`. Computed on every read, never stored (AC-53).
4. Tests:
   - S1 to S19 as one parametrized table over the pure function, with the spec's row ids as test ids (AC-52);
   - T1 to T3 the same way (AC-54);
   - one route test;
   - one test that an `is_test` row is skipped.
5. Snapshot; `CONTRACTS.md` gets the stats paragraph, which names the S and T tables in SPEC-02 as the shared vectors for the frontend's guest stats.

### PR M1-15: guest merge (AC-55 to AC-62)

1. Route `POST /v1/games/{slug}/progress/merge` (`games_merge_progress`): `CurrentUser` (AC-55). Body `{entries: [{date, variant, guesses, played_as_daily}]}`, where `entries` has `max_length=500`; more gives 422 with `entries`, `too_long`, `max: 500` (R-15, AC-62), and nothing is stored.
2. Service, per entry, in request order:
   - resolve the variant (else reject `variant_not_found`) and the visible puzzle (else reject `puzzle_not_found`);
   - replay `guesses` with `submit_guess` and the AC-39 rule at 6 (else reject `invalid_guess_history`; R-22 for an empty list);
   - insert the progress row and its guesses with `ON CONFLICT DO NOTHING` on `(user_id, puzzle_id)`, setting `origin = merge` and `counts_for_streak = played_as_daily` (AC-56, AC-57, Q2);
   - a conflict counts as `already_present`, and the account's row is untouched (AC-58).

   One commit at the end. The client sends no outcome, and none is read (AC-56).
3. Response: `{stored, already_present, rejected, rejected_entries: [{date, variant, code}]}` (AC-60). `private, no-store`.
4. Tests:
   - mixed entries;
   - a second identical request changes nothing, and stats are identical (AC-61);
   - an existing account row wins (AC-58);
   - one rejection of each kind still merges the others (AC-59);
   - 501 entries gives 422 and stores nothing (AC-62);
   - a guest gets 401.
5. Snapshot; `CONTRACTS.md` gets merge: when the frontend calls it, chunks of 500, safe to retry.

### PR M1-16: archive (AC-63 to AC-66)

1. `app/crud/puzzle.py`: a keyset query of visible puzzles with `date < before`, newest first, fetching `limit + 1` rows to know whether there is more. For an account, it left-joins the account's progress for state and guesses used. Days with no visible puzzle are simply absent (AC-65).
2. Route `GET /v1/games/{slug}/archive` (`games_list_archive`):
   - `variant` is optional;
   - `before` uses the strict date and defaults to today; a later value is clamped to today;
   - `limit` is 1 to 100, default 30 (AC-64).

   Items have `date`, `number`, `state`, `guesses_used`. Both of the last two are `null` for a guest (AC-63). `next_before` is the last item's date, or `null`. `private, no-store`.
3. Past puzzles play through the existing view, resume and guess routes (AC-66): one test plays yesterday's puzzle and checks `counts_for_streak` is false.
4. Tests: paging across two pages; the clamp; never today or the future; gaps; guest nulls; account states.
5. Snapshot; `CONTRACTS.md` gets archive paging.

## Hand-off to the frontend plan (`plans/02-phase-1-frontend.md`)

Each backend PR that changes the snapshot has a G-M1-xx PR in the frontend plan. **Merge rule:** the owner merges the backend PR only when its G PR is ready; the G PR is the next frontend merge. No backend PR here needs the `breaking-change` label. If oasdiff says otherwise, stop and report.

| Backend PR | Frontend PR it unblocks | Operations (generated names) | Error codes | Other things the frontend needs |
|---|---|---|---|---|
| M1-41 | **F1** (error texts, Origin) | none; snapshot unchanged, so no G PR | `csrf_origin_mismatch` (403), `unsupported_media_type` (415). F1 adds all ten AC-75 codes at once (frontend R-2): also `game_not_found`, `variant_not_found`, `puzzle_not_found`, `title_not_found`, `duplicate_guess`, `invalid_guess_history`, `puzzle_already_finished`, `invalid_media_link` | Every POST, PUT, PATCH and DELETE needs an allowed `Origin` (or `Referer`). Dev allowed origins: `http://localhost:5173`, `BACKEND_CORS_ORIGINS`, `http://localhost:8000`. Not allowed: `127.0.0.1:5173`, preview on 4173. The check never looks at `Host`, so the proxy's `changeOrigin` is fine. Requests **with a body** must be `application/json`; bodiless POSTs (logout) never get 415. Every error response is `no-store`. |
| M1-10a | none | none | none | Schema only. |
| M1-10 | G-M1-10, then **F3** (known games) and **F2** (`signed_in`) | `games_list_games`, `games_get_today_puzzle`, `games_get_puzzle` | `game_not_found`, `variant_not_found`, `puzzle_not_found` (404, identical bodies for every hidden case) | `GET /v1/games` returns `{items: [{slug, default_variant, launch_date}]}` with `public, max-age=300` (F3). **`signed_in` first appears here**, top-level in the puzzle view: F2 can start after G-M1-10, not G-M1-13. `signed_in: false` with a cached user means the session ended: sign out locally, as for a 401. The view is tagged by `type: "game_guesser"`. `today` names the resolved `date`. Path and query validation errors now name the bare field (`date`, `q`). |
| M1-17 | G-M1-17 | `clock_get_clock` | none | `now`, `today`, `next_reset`; display only (M1-37). |
| M1-11 | G-M1-11 | `games_search_titles` | `validation_error` for `q` over 100 | `{items: [{id, name, franchise, year}]}`; trimmed `q` under 2 gives `[]`; at most 200; `public, max-age=300` (M1-31). |
| M1-12 | G-M1-12 | `games_submit_guess` | `title_not_found`, `duplicate_guess` (422), `invalid_guess_history` (422), `puzzle_already_finished` (409) | Body `{title_id \| null, previous}`. A guest keeps its own guess list and the first non-null `counts_for_streak`; the response is the full new view. |
| M1-13 | G-M1-13 | `games_resume_puzzle` | as M1-12 | For accounts the server copy wins and `previous` is ignored. A guess or resume answered with `signed_in: false` is a guest result (frontend Phase 2 note). |
| M1-18 | G-M1-18 | none (the media route is outside the schema) | `invalid_media_link` (403); `range_not_satisfiable` (416, seen only by `<video>`, never by axios, so no catalogue entry is needed) | Each step's `media`: `type`, `width`, `height`, `expires_at`, `sources` (use in order: WebM first, MP4 last), `poster` (video only). URLs are absolute and used as they are; do not prefix. On 403 or a load error after `expires_at`, fetch the view or resume again. M1-40's CSP needs `media-src` for the bucket origin. |
| M1-14 | G-M1-14 | `games_get_stats` | `not_authenticated` (401) for guests | `distribution` keys `"1"` to `"6"`; streak fields `null` for a non-default variant; the S1 to S19 and T1 to T3 ids for the frontend's guest stats (frontend Open point 2). |
| M1-15 | G-M1-15 | `games_merge_progress` | per-entry codes `puzzle_not_found`, `variant_not_found`, `invalid_guess_history`; 422 `too_long` over 500 | Send chunks of 500 or fewer; retry is safe. Response `{stored, already_present, rejected, rejected_entries}` (M1-36). |
| M1-16 | G-M1-16 | `games_list_archive` | `validation_error` for `limit` or `before` | `{items: [{date, number, state, guesses_used}], next_before}`; `state` and `guesses_used` are `null` for guests, and the browser fills them (M1-35). |

`CONTRACTS.md` ownership: this plan writes the Auth CSRF paragraph (`:36-39`), the Errors code list (`:100-103`) and the whole new "Games" section, including the F2 sentence on `signed_in: false`. The frontend plan edits none of these (its "Modules affected" agrees).

## Skills for implementer

The backend's project skill is `my-list-be/.claude/skills/fastapi-service-patterns/SKILL.md`. When the implementer runs from the platform folder, it may not be listed: read the file directly.

| Files | Load | Why |
|---|---|---|
| `app/**/*.py` (routers, services, `app/crud/`, models, `app/core/`) | `fastapi-service-patterns`, `shvab:karpathy-guidelines` | The repo's layering, tests and style rules; small, surgical diffs |
| `app/core/csrf.py`, `app/media/*` | the above plus `docs` | Starlette ASGI and `FileResponse` behaviour at 1.6.0; RFC 9110 range rules; boto3 presign and Hetzner Object Storage docs (SigV4, addressing style) at the versions in use |
| `app/alembic/**`, `app/core/db.py`, models with indexes | `fastapi-service-patterns`, `docs` | Alembic 1.19 autogenerate and `alembic check` behaviour with naming conventions and GIN `postgresql_ops`; SQLAlchemy 2.0 `MetaData(naming_convention=...)` |
| `app/crud/title.py` | `docs` | `pg_trgm` operators, `set_config`, `starts_with` in Postgres 16 |
| `tests/**` | `fastapi-service-patterns` ("Tests") | Fixtures and naming; spec tables win over the "1 to 3 tests" budget (Architectural constraints) |
| `pyproject.toml`, `uv.lock` | `docs` | uv lock at CI's version |
| `scripts/seed_dev.py`, `scripts/seed_media/`, `scripts/check_s3_range.py`, `scripts/bench_title_search.py` | `shvab:karpathy-guidelines`, `docs` (ffmpeg flags for H.264, `+faststart`, no audio, WebP) | **Gap:** no project skill for scripts or media encoding |
| `CLAUDE.md`, `CONTRACTS.md`, `SKILL.md` text, READMEs | `shvab:no-ai-slop` | The owner wants plain, short sentences |
| Review passes | `code-review` (high), `security-review` for M1-41 and M1-18 | Execution mode table |

No skill covers Postgres or Alembic specifically (gap filled with `docs`). Frontend skills (`shvab:react-*`, `shvab:zod`) do not apply here.

## Verification

### Local setup (as Phase 0; never touches port 5433)

- Prefix commands with `PATH="$HOME/.local/bin:$PATH"` (uv is not on `PATH` in non-login shells).
- `docker start dgc-dev-pg dgc-dev-redis` (Postgres 5544, Redis 6390). Recreate them with the commands in `plans/01-phase-0-backend.md:182-185` if they are gone. `postgres:16-alpine` ships `pg_trgm`.
- `<4 values>` means these four assignments, at the front of every `pytest` and `alembic` command (`.env` now points at `dgc-dev-pg` on 5544 too, but under the old `item_list` database names, so pass these explicitly; export them as variables, since zsh does not word-split `env "$V"`):
  - `DATABASE_URL=postgresql+asyncpg://postgres:postgres@localhost:5544/daily_game_challenge`
  - `TEST_DATABASE_URL=postgresql+asyncpg://postgres:postgres@localhost:5544/daily_game_challenge_test`
  - `REDIS_URL=redis://localhost:6390/0`
  - `TEST_REDIS_URL=redis://localhost:6390/1`
- Do not edit `.env`. Stop the containers at the end.

### Per PR (run in `my-list-be/`)

Every PR runs the gate below once, in the implementer run; `plan-verifier` re-runs it. Scoped tests are named per PR. The full suite is still small (28 tests today), and the M1-41 and M1-10a changes touch shared code, so the full suite runs on every PR.

| Check | Command | Pass |
|---|---|---|
| Lockfile | `uv lock --check` | exit 0 |
| Lint, format | `uv run ruff check .` and `uv run ruff format --check .` | clean |
| Snapshot | `uv run python scripts/export_openapi.py --check` | exit 0; `git diff main -- openapi/openapi.json` shows only additions |
| Scoped tests | `<4 values> uv run pytest -q <files below>` | all pass |
| Full suite | `<4 values> uv run pytest -q` | all pass |
| Migrations (M1-10a, M1-11, M1-13) | `docker exec dgc-dev-pg createdb -U postgres daily_game_challenge` (ignore "already exists"), then `<4 values> uv run alembic upgrade head`, `uv run alembic heads` (one head), `<4 values> uv run alembic check`, then `alembic downgrade -1` and `upgrade head` again. **Also from an empty database, as CI does:** `dropdb --if-exists` and `createdb` a throwaway database, point `DATABASE_URL` at it, `upgrade head`, `alembic check`, `downgrade base`, `upgrade head`, then drop it (the dev database alone hides migrations that only work on old state; found in M1-10a review) | exit 0, one head, no diff, on both databases |

Scoped tests per PR:

| PR | Scoped tests | PR-specific pass |
|---|---|---|
| M1-41 | `tests/test_csrf.py tests/test_auth.py tests/test_password_reset.py tests/test_password_update.py tests/test_errors.py` | Every AC-85 row; logout 204 without a body; 415 on a non-JSON body; snapshot unchanged |
| M1-10a | `tests/test_visibility.py` (new) | `alembic check` clean with only the convention, then with the tables; `users_pkey` renamed |
| M1-10 | `tests/test_games.py` (new) | Identical 404 bodies; `signed_in` false with a bad cookie; midnight flip with the injected clock; seed runs twice in `local` and refuses with `ENVIRONMENT=test` |
| M1-17 | `tests/test_clock.py` | Route works with `get_db` raising |
| M1-11 | `tests/test_title_search.py` | All AC-21 and AC-22 rows; manual `scripts/bench_title_search.py` p95 under 150 ms (AC-24, recorded in the PR text) |
| M1-12 | `tests/test_game_guesser.py tests/test_guesses.py` | Leak scan over a full won and a full lost game |
| M1-13 | `tests/test_progress.py tests/test_guesses.py` | Guest-versus-account table; forged `previous`; concurrency test leaves no rows behind (run the full suite after it) |
| M1-18 | `tests/test_media.py tests/test_media_signing.py tests/test_games.py` | Every range row; step-1 body free of later keys; S3 presign without network |
| M1-14 | `tests/test_stats_rules.py tests/test_stats.py` | S1 to S19 and T1 to T3 by id |
| M1-15 | `tests/test_merge.py` | Second request changes nothing; 501 entries stores nothing |
| M1-16 | `tests/test_archive.py` | Paging and clamp; never today |

CI must be green on all four jobs for each PR: lint, test, migrations (`upgrade`, one head, `alembic check` against the real migrations), openapi (snapshot and oasdiff with no label).

### Manual acceptance (SPEC-02 "Definition of done", after the PR named)

Run with the dev seed (`uv run python scripts/seed_dev.py` with the four values and `ENVIRONMENT=local`), the backend on `http://localhost:8000` and the frontend dev server on `http://localhost:5173`. Add `-H 'Origin: http://localhost:5173'` and `-H 'Content-Type: application/json'` to curl POSTs.

| DoD item | After | Check |
|---|---|---|
| 1 | M1-18 | `GET /v1/games` lists `game-guesser`; `/puzzles/today` shows step 1 only, and its image URL opens in the browser |
| 2 | M1-10 | Tomorrow's date and the draft's date give the same 404 apart from `request_id` |
| 3 | M1-11 | "zlda" lists the Zelda title with its year |
| 4 | M1-18 | Guest: wrong guess, skip, step 3 appears and its link was not in the step-1 body; after five misses the step-6 clip plays muted and loops in Chrome and Firefox; a sixth miss shows the answer. Safari and iOS wait for M1-50 |
| 5 | M1-13 | Signed in: a second browser shows the same state; a forged `previous` changes nothing |
| 6 | M1-14 | Stats after a few plays match AC-52 and AC-54 |
| 7 | M1-15 | Merge sent twice; stats unchanged after the first |
| 8 | M1-16, M1-17 | Archive lists the 3 seeded past days, not today; `/v1/clock` counts to 00:00 UTC |
| 9 | M1-41 (login), M1-12 (guess) | `Origin: https://evil.example` and no `Origin` give 403 on login and on a guess; login from the frontend works; "Try it out" on `http://localhost:8000/docs` posts a guess |
| AC-72c | before Phase 4 relies on S3 | `scripts/check_s3_range.py` against a real Hetzner bucket gives 206 for both ranges, and the printed link plays in a browser. **Not a blocker for Phase 1 or dev**; if it fails, production uses `MEDIA_STORAGE=local` (AC-72c) |

## Risks

- **uv version and `uv.lock`.** Local uv is 0.12.5; CI pins 0.13.6 (`ci.yml:19`). Adding boto3 in M1-18 rewrites the lock. Lock with `uvx uv@0.13.6 lock` (or `uv self update 0.13.6`) and check that only boto3, botocore, s3transfer, jmespath and their transitive needs were added. CI `uv sync --locked` is the proof.
- **`alembic check` with the naming convention or GIN ops.** Autogenerate might report a spurious diff, for example on `postgresql_ops` or the renamed primary key. Mitigation: run `alembic check` locally in M1-10a and M1-11 before anything else. If a diff appears that the model cannot express, stop and report; do not silence it with `include_object` without the owner.
- **Committed rows leak between tests.** The AC-45 test commits for real. If its cleanup fails, unique keys break later tests. Mitigation: `TRUNCATE ... CASCADE` in `finally`, and run the full suite after it.
- **Answer leak through a near-duplicate.** A wrong guess's name could equal the answer's normalized name only if it were correct (Q9), so the leak scan picks fixtures with distinct names.
- **Seed dates go stale.** The seed is relative to today. Re-run it on a new day; `CLAUDE.md` says so.
- **Placeholder binaries in a public repo** (about 1 MB, made by us). Accepted by AC-82; Open point 4 if the owner prefers generating them.
- **Frontend red window** after each snapshot-changing merge. Mitigation: the merge rule in Execution mode.
- **No branch protection.** Check all four jobs by hand.
- **The `today` route order.** Declared after the dated route, "today" would fail date validation and give 422. Covered by the M1-10 route test.
- **CSRF breaks a developer flow.** curl, the preview server or `127.0.0.1` get 403. Mitigation: `CONTRACTS.md`, `CLAUDE.md`, and the error code (`csrf_origin_mismatch`, not a generic 403).

## Rollback

- Each PR is one squash commit; roll back with a revert PR.
- A PR that changed the snapshot is reverted together with its G PR, backend first, or frontend `api-types` turns red.
- PRs with migrations (M1-10a, M1-11, M1-13): on a shared database, run `alembic downgrade` to the previous revision before deploying the revert. Phase 1 runs only locally and in CI, so in practice: revert, then `alembic downgrade -1` locally, or recreate the dev database and re-seed. The M1-13 downgrade drops progress rows (local test data only).
- M1-41: reverting removes the check. Do it only together with the games POST routes, or ship a fix instead: the spec forbids game POST routes without it.
- M1-18: the revert also removes boto3 from the lock. Local media files in `var/media` can be deleted.
- Platform commits (`CONTRACTS.md`, root `CLAUDE.md`) are reverted with their PR.

## Open points

**Owner's answers (2026-11-02):** every default below is accepted as written, so each point is decided. The execution mode is one agent per PR, each checked by `plan-verifier`, and the owner merges.

Defaults are applied by the plan; the owner can change them before the named PR.

1. **Default variant name** (M1-10). SPEC-02 never names it. Default: `default`. Only the seed and the frontend's reading of `default_variant` see it.
2. **Media route for a puzzle hidden after the link was issued** (M1-18). Default: 404 `puzzle_not_found` (spec edge table). The alternative is 403 `invalid_media_link`.
3. **Range edge cases** (M1-18). Default: a malformed or unsatisfiable range gives 416 with a problem body and the new code `range_not_satisfiable` (added to `CONTRACTS.md`; no frontend text, because only `<video>` sees it); several ranges give the full file with 200. AC-75's list does not include a 416 code.
4. **Seed media committed** (M1-18). Default: commit seven small placeholder files made with ffmpeg test patterns (under 1 MB), plus their commands. The alternative is to generate at seed time, which needs ffmpeg and Pillow on every developer machine; this machine has neither.
5. **The media route is not in the OpenAPI snapshot** (M1-18). Default: excluded, documented in `CONTRACTS.md` (R-17).
6. **Plural table names** (M1-10a). Default: plural, as `users` (R-1).
7. **`users_pkey` renamed to `pk_users`** (M1-10a). Default: yes, in the first new migration.
8. **AC-72c needs a real Hetzner bucket and credentials** from the owner. Default: not a blocker for Phase 1; the script is ready, and the check is done before Phase 4 relies on S3. If it fails, production serves media through the backend route.
9. **Phase 1 estimate.** `MILESTONE-1.md:57` says about 6 days, the task table sums to 8.6, and this plan estimates 8.0 backend days (plus the frontend share of M1-41). Default: no change by this plan; the owner updates `MILESTONE-1.md` at the next status update.
10. **The AC-24 benchmark** is manual (`scripts/bench_title_search.py`) and recorded in the M1-11 PR text, not in CI. Default: accepted.
11. **CORS `allow_headers` still lists `X-Requested-With`** (`app/main.py:49`). Default: leave it; it is harmless. Remove it in a later cleanup if wanted.

## Traceability

| AC | Backend part | Plan step | Check |
|---|---|---|---|
| AC-1 | Routes under `/v1/games/{slug}/...`, module chosen by slug | M1-10.4, M1-10.7 | `test_games.py` |
| AC-2 | `get_puzzle`, `submit_guess` | M1-10.4, M1-12.1 | `test_game_guesser.py` |
| AC-3 | `type: game_guesser` | M1-10.5 | snapshot; `test_games.py` |
| AC-4 | No answer or unearned clue before the end | M1-10.9, M1-12.5, M1-18.9 | leak scan; step-1 body test |
| AC-5 | No internal puzzle or progress id | M1-10.5 | snapshot review (no `id` on puzzle or progress schemas) |
| AC-6 | Progress not keyed by language | M1-13.1 | migration review |
| AC-7, AC-8 | Frontend | Hand-off (M1-10 row, F3) | frontend plan |
| AC-9 | `games` columns and slug CHECK | M1-10a.2 | migration; CI migrations job |
| AC-10 | `puzzles` key and status CHECK | M1-10a.2 | migration; `test_visibility.py` |
| AC-11 | Title FK RESTRICT (puzzle answer, guesses) | M1-10a.2, M1-13.1 | integrity test (M1-10a.7) |
| AC-12 | One visibility predicate on every puzzle route | M1-10a.4, M1-10.6, M1-12, M1-13, M1-15, M1-16, M1-18.5 | `test_visibility.py`; 404 table |
| AC-13 | `puzzle_clues` | M1-10a.2 | migration |
| AC-13b | `clue_media_files`; cross-row check on read | M1-10a.2, M1-18.6 | migration; `test_media.py` |
| AC-14 | `GET /v1/games` | M1-10.7 | `test_games.py` |
| AC-15 | Dated and today views | M1-10.7 | `test_games.py` |
| AC-16 | `variant` default and 404 | M1-10.6 | `test_games.py` |
| AC-17 | Identical 404s; strict date | M1-10.2, M1-10.3, R-13 | 404 table; date rows |
| AC-17b | Naming convention; migration passes CI | M1-10a.1, M1-10a.3 | `alembic check`; CI migrations |
| AC-18 | `titles` columns | M1-10a.2 | migration |
| AC-19 | Search response, no answer hint | M1-11.5 | `test_title_search.py` |
| AC-20 | Short `q` empty; over 100 is 422 | M1-11.5 | `test_title_search.py` |
| AC-21 | Ranking, threshold, cap 200 | M1-11.4 | `test_title_search.py` |
| AC-22 | No wildcards | M1-11.4 | `test_title_search.py` |
| AC-23 | `pg_trgm` in the migration and in the test setup | M1-11.1, M1-11.2 | CI test and migrations jobs |
| AC-24 | 50,000-title latency | M1-11.7 | manual benchmark (Open point 10) |
| AC-25 | View fields; `media` | M1-10.5, M1-18.6 | snapshot; `test_games.py`; `test_media.py` |
| AC-26 | Earned steps; all six with `source_url` at the end | M1-10.4, M1-12.5 | `test_guesses.py` |
| AC-27 | Guess check, near-duplicate correct | M1-12.1, M1-12.4 | `test_game_guesser.py` |
| AC-28 | Franchise flag rules | M1-12.1 | `test_game_guesser.py` |
| AC-29 | Won, lost, answer only at the end | M1-12.1, M1-12.5 | leak scan |
| AC-30 | Score includes skips | M1-12.1 | `test_game_guesser.py` |
| AC-31 | `duplicate_guess` | M1-12.2, M1-13.1 (DB guard) | `test_guesses.py` |
| AC-32 | `title_not_found` | M1-12.2 | `test_guesses.py` |
| AC-33 | `puzzle_already_finished` | M1-12.2 | `test_guesses.py` |
| AC-34 | Guess returns the view | M1-12.4 | `test_guesses.py` |
| AC-35 | `progress` table, cascade, unique | M1-13.1 | migration; cascade test |
| AC-36 | `counts_for_streak` at the first stored guess, never changed | M1-13.2 | injected-clock test (S18, S19) |
| AC-37 | Guest replay, nothing stored | M1-12.2 | `test_guesses.py` |
| AC-38 | Resume | M1-13.4 | `test_progress.py` |
| AC-39 | `invalid_guess_history`; finished replay | M1-12.2, M1-13.4, R-24 | `test_guesses.py`; `test_progress.py` |
| AC-40 | Guest `counts_for_streak` only on the first guess | M1-12.2 | `test_guesses.py` |
| AC-41 | Accounts ignore `previous` | M1-13.3 | forged-`previous` test |
| AC-42 | Bad cookie means guest, `signed_in: false` | M1-10.1 | `test_games.py`; Hand-off M1-10 row (F2) |
| AC-43 | `is_test` false, never set or returned | M1-13.1, M1-13.3 | snapshot review; migration |
| AC-44 | Guest and account give the same view | M1-13.5 | table-driven test |
| AC-45 | Concurrent requests serialized | M1-13.2, M1-13.5 | concurrency test |
| AC-46 | Stats route, 401 for guests | M1-14.3 | `test_stats.py` |
| AC-47 | `played` counts finished, archive included | M1-14.1 | T1 to T3 |
| AC-48 | Skip `is_test` | M1-14.2 | `test_stats.py` |
| AC-49 | Streak days | M1-14.1 | S15 to S19 |
| AC-50 | Grace rule | M1-14.1 | S1 to S14 |
| AC-51 | `null` streaks for a non-default variant | M1-14.3 | `test_stats.py` |
| AC-52 | S1 to S19 | M1-14.4 | `test_stats_rules.py` by id; frontend in M1-34 |
| AC-53 | Computed on read | M1-14.3 | code review (no stored counter); migration has none |
| AC-54 | T1 to T3 | M1-14.4 | `test_stats_rules.py` |
| AC-55 | Merge route, 401 for guests | M1-15.1 | `test_merge.py` |
| AC-56 | Replay, no client outcome | M1-15.2 | `test_merge.py` |
| AC-57 | `origin: merge`, flag from `played_as_daily` | M1-15.2 | `test_merge.py` |
| AC-58 | Account row wins | M1-15.2 | `test_merge.py` |
| AC-59 | Per-entry rejection | M1-15.2 | `test_merge.py` |
| AC-60 | Counts and rejected list | M1-15.3 | `test_merge.py` |
| AC-61 | Idempotent | M1-15.2 | replay test |
| AC-62 | Over 500 is 422 `too_long`, nothing stored | M1-15.1, R-15 | `test_merge.py` |
| AC-63 | Archive items and `next_before` | M1-16.2 | `test_archive.py` |
| AC-64 | `limit` range; `before` clamp | M1-16.2 | `test_archive.py` |
| AC-65 | Never today or future; gaps left out | M1-16.1 | `test_archive.py` |
| AC-66 | Past puzzles play through the same routes | M1-16.3 | `test_archive.py` |
| AC-67 | Clock values, no database | M1-17.1 | `test_clock.py` |
| AC-68 | Clock `no-store` | M1-17.1 | `test_clock.py` |
| AC-69 | Server clock owns "today" | R-7, M1-10a.5, M1-10.9, M1-17.2 | midnight tests |
| AC-70 | Signed links, image TTL | M1-18.2 to M1-18.4 | `test_media_signing.py` |
| AC-70b | Video TTL | M1-18.2, M1-18.4 | `test_media_signing.py` |
| AC-71 | Links only for earned steps of visible puzzles | M1-18.6 | step-1 body test |
| AC-72 | Local route or bucket; content type; `nosniff` | M1-18.4, M1-18.5 | `test_media.py` |
| AC-72b | Byte ranges, HEAD, 416, signature on every request | M1-18.5, R-18 | range table |
| AC-72c | Hetzner presigned `Range` | M1-18.8 | manual script (Open point 8) |
| AC-73 | 403 `invalid_media_link` | M1-18.5 | `test_media.py` |
| AC-74 | Random or hash keys; private storage | M1-18.5, M1-18.7 | key-format check; code review |
| AC-74b | Builder limits | M1-18.7 (seed files comply); limits in `CONTRACTS.md` | manifest review; enforcement in M1-22 |
| AC-75 | New error codes | M1-41.2, M1-10.2, M1-12.3, M1-18.5 | each PR's tests; `CONTRACTS.md`; frontend F1 |
| AC-76 | 415 for non-JSON bodies | M1-41.4, R-10 | `test_csrf.py` |
| AC-77 | Cache-Control table | R-12, M1-10.7, M1-11.5, M1-17.1, M1-18.5, and every route step | header assertions in each PR's route tests |
| AC-78 | `CONTRACTS.md` Games and Auth | each PR's platform step | review of each platform commit |
| AC-79 | Snapshot and frontend regeneration | every PR step "Snapshot"; Hand-off | CI openapi job; frontend G PRs |
| AC-80 | Backend `CLAUDE.md` | M1-41.8, M1-10a.8, M1-10.10, M1-18.10 | docs review |
| AC-81 | Game routes work for a guest with no cookie | M1-10.1 | `test_games.py` |
| AC-82 | Dev seed | M1-10.8, M1-18.7 | manual seed run; refusal outside `local` |
| AC-83 | Origin checked first on unsafe methods | M1-41.4, M1-41.5 | order rows in `test_csrf.py` |
| AC-84 | Referer fallback | M1-41.4 | `test_csrf.py` |
| AC-85 | 403 rows | M1-41.4 | `test_csrf.py` table |
| AC-86 | Allowed origins per environment | M1-41.1, R-11 | `test_csrf.py` (`test` versus `production`) |
| AC-87 | GET, HEAD, OPTIONS unchecked | M1-41.4 | `/healthz` row |
| AC-88 | Existing tests send an allowed `Origin` | M1-41.6 | full suite green; login without `Origin` gets 403 |
| AC-89 | Frontend text | Hand-off (M1-41 row, F1) | frontend plan |
