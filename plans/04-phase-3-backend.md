# Phase 3 backend: IGDB client, title import, puzzle builder, review, scheduling, buffer check — Implementation Plan

Status: draft, 2026-11-12. Scope: the backend repo `my-list-be/` and one paragraph of the root `CONTRACTS.md` (platform repo). The frontend part (the Sources section and the `critic_score` label) is `plans/04-phase-3-frontend.md`, written in the same pass; its two PRs line up with the backend PRs below by task id. Line numbers were checked against backend `main` at `08fdb12`, frontend `main` at `ef8f791` and the platform repo at `be4be69` (with the uncommitted `MILESTONE-1.md` and `SPEC.md` edits that link SPEC-04 and add decision 68).

## Source requirements

- Spec: `specs/04-phase-3-content.md` (SPEC-04, agreed 2026-11-12; the owner chose option (a) for all of Q1 to Q18). The answers table (`specs/04-…:20-39`) wins over older text in `SPEC.md`, `MILESTONE-1.md` and `ARCHITECTURE.md`. Decision 68 (`SPEC.md:82`) records the same answers. The questions are not reopened here.
- Tasks: `MILESTONE-1.md` Phase 3 (`:87-98`): M1-20 to M1-25, decisions D2 (IGDB) and D5 (reviewer), definition-of-done item 7.
- Backend criteria this plan implements: **AC-1 to AC-62 and AC-73 to AC-86**, with AC-1, AC-2, AC-9, AC-20, AC-24, AC-54, AC-61 as owner steps or manual checks behind the gates below.
- Frontend criteria, handed off: **AC-63 to AC-70** and the `critic_score` label of AC-31 (`plans/04-phase-3-frontend.md`). **AC-71 and AC-72** land with M1-46 (footer, legal page); this plan only hands the fixed text on.
- Context read: root `CLAUDE.md`, `CONTRACTS.md` "Games" (`:349-450`), `MILESTONE-1.md`, `SPEC.md` decisions 67 and 68, `ARCHITECTURE.md` sections 9, 10 and 14 (`:188`, `:199`, `:251`), both repo `CLAUDE.md` files, `fastapi-service-patterns/SKILL.md`, `plans/02-phase-1-backend.md` (format, local test setup, risks), `plans/03-phase-2-frontend.md`.
- Neither repo has a `LEARNINGS.md` (checked: no file matching `*learn*` outside `node_modules` and `.venv`). The traps on record are the Phase 1 plan's "Risks" and the owner's notes on execution, which are applied below.

## Clarifications & recommendations

No questions could be asked (this planner runs as a subagent). The owner's decisions given with the task are applied as fixed. Everything marked **R-n** is my judgment, not spec text. Defaults I had to pick where something was truly open are under "Open points" and in the final report.

**Decided by the owner for this plan (2026-11-12):** see "Execution mode". The spec's 18 answers are fixed.

**Recommendations on design:**

- **R-1. One schema PR first (M1-22a), carrying every column and table Phase 3 needs.** M1-21 (`titles.igdb_id`), M1-22 (`puzzles.date` optional, the build slot) and M1-24 (exclusions, approval time) each need schema. If two PRs of one wave each added an Alembic revision, `main` would get two heads. One migration up front lets the later PRs run in waves with no migration at all.
- **R-2. The content code lives in `app/content/`, the CLIs in `scripts/`.** Library code under `app/` is importable by tests and follows the layering (queries in `app/crud/<entity>.py`, `my-list-be/CLAUDE.md:79-81`). The CLIs stay thin, like `scripts/seed_dev.py`. `app/main.py` never imports `app/content/`, so the API, the OpenAPI snapshot and the server image are unchanged. One CLI file per task, so paired PRs never edit the same CLI.
- **R-3. Script-only settings in their own class.** `app/content/settings.py` has `ContentSettings(BaseSettings)` with `IGDB_CLIENT_ID`, `IGDB_CLIENT_SECRET`, `PUZZLE_SEED_SALT`, `CONTENT_WORK_DIR` (default `var/content-work`), `IGDB_IMAGES_CLEARED_BY` (see R-12) and the candidate thresholds (AC-22). It reads the same `.env`, is built only by the scripts, and is never imported by the app. So the server needs no IGDB variable, and the deployed-config validator in `app/core/config.py:163-236` is unchanged.
- **R-4. New dependencies go in a `content` dependency group** (`pillow`, `av` (PyAV), and `httpx`, which today is dev-only), with `[tool.uv] default-groups = ["dev", "content"]` so `uv sync` and CI's test job install them. The buffer check (M1-25) must run on the server (M1-52) with runtime dependencies only, so it imports neither Pillow, PyAV nor httpx. The implementer checks the `default-groups` behaviour with `docs` against uv 0.13.6 (CI's `UV_VERSION`, `ci.yml:19`).
- **R-5. The step-6 clip is drawn frame by frame in Python and encoded with PyAV.** Pillow renders each frame of a slow pan and cross-fade over 2 or 3 screenshots (12 s, 24 fps, 1280x720); PyAV encodes H.264 `yuv420p` with `+faststart` and no audio stream, and reads the file back to measure it (AC-39). No system ffmpeg is needed (this machine has none, checked; the seed media were made in a throwaway Docker container, `scripts/seed_media/README.md`). **First step of M1-22c is a 5-minute spike:** confirm that the installed PyAV wheel has an H.264 encoder (`libx264` or another). If it has none, fall back to the `imageio-ffmpeg` package (a static ffmpeg binary, frames piped in as raw RGB) and keep PyAV only for reading the file back. Either way no system package is needed in CI.
- **R-6. The puzzle's date is optional, and only a scheduled puzzle must have one.** The CHECK is `status <> 'scheduled' OR date IS NOT NULL`, as the spec words it (AC-46). The tools always write `NULL` for a puzzle that is not scheduled, and unscheduling clears it (AC-59). The stricter "date set exactly when scheduled" would break existing tests that build dated drafts on purpose (`tests/test_visibility.py`) for no gain, since visibility already requires `scheduled` (`app/crud/puzzle.py:15-36`). The unique key `(game_id, variant, date)` keeps working, because Postgres treats NULLs as distinct.
- **R-7. A "slot" is a positive build number, unique per game and variant (`puzzles.build_slot`).** The builder takes `--slots 41-50`, or `--next 10`, which prints the range it picked from the highest slot in use. A slot that already has a puzzle is skipped, so re-running a range is a no-op (AC-46). Slots are built in ascending order, and each one sees the answers chosen by the slots before it in the same run (AC-25).
- **R-8. The seed is an HMAC, never a plain hash.** `seed = HMAC-SHA256(salt, "<slug>:<variant>:<slot>:<generator version>")`, and every choice gets its own stream, `random.Random(HMAC-SHA256(seed, "<purpose>"))`, with purposes `answer`, `screenshots`, `crop` and `clip`. Inputs are sorted first (candidates by IGDB id, screenshots by image id), so the choices do not depend on the order IGDB returns (AC-26, AC-28). `GENERATOR_VERSION` is a constant in the builder, raised whenever the choice logic changes.
- **R-9 (amended by decision 71, 2026-11-13: avoid the union of all rebuild rows' screenshots; fewer than 7 left means not rebuildable, and M1-22d adds a command that gives the rebuild up as "never").** **"Rebuild" forces the same answer into the same slot.** A rejection copies the draft's slot and the IGDB ids of its screenshots into the exclusion row, then deletes the draft (AC-51). `build --rebuilds` (and any `--slots` range that holds such a slot) builds that slot with the excluded title as the answer and leaves the excluded screenshots out of the pool, so the screenshots and the crop change (AC-52), deterministically. A "never" exclusion removes the title from candidates for good (AC-23).
- **R-10. Approved puzzles reach another environment by a promote step, M1-24c.** The spec has the builder name a target (AC-44) and wants 30 puzzles scheduled "in production before launch" (AC-61, DoD 5), but the review page refuses any environment but `local` (AC-47), and no IGDB screenshot may leave `local` until Q1 is cleared (AC-2). The only path that satisfies all three: build and review in `local`, then copy approved puzzles (rows and files) to the target as `approved`, then schedule there. Production then never holds an unreviewed draft. This is a gap in the spec, not a decision of the owner; see Open point 1.
- **R-11. A dedicated local database for real content.** `seed_dev.py` deletes every puzzle of the game on each run (`scripts/seed_dev.py:167`), and would fail (RESTRICT) or wipe real drafts. Recommendation: real content work uses `ENVIRONMENT=local` with `DATABASE_URL=.../daily_game_challenge_content` and `MEDIA_LOCAL_DIR=var/content-media`; the dev seed keeps `daily_game_challenge`. The backend `CLAUDE.md` says so in M1-21.
- **R-12. The IGDB image gate is a setting, not a code change.** Every writing script that stores an IGDB screenshot (the builder, promote) refuses any target other than `local` while `IGDB_IMAGES_CLEARED_BY` is empty. The owner sets it to the `SPEC.md` decision that records IGDB's written yes or his written acceptance of the risk (AC-1, AC-2). The value is printed with the target.
- **R-13. One target guard for every writing script** (`app/content/target.py`): `--target` is required and must equal the `ENVIRONMENT` environment variable itself (not the settings default, the same reason as `seed_dev.py:233-247`); the run prints the target, the database host and the storage kind (folder or bucket name, never a key or credential) before the first write; a target other than `local` needs `--confirm-target <name>` or the name typed at a prompt; the run refuses when the `CI` environment variable is set (AC-44, AC-84). `refusal_reason` moves here from `seed_dev.py`, which imports it.
- **R-14. The AC-13b media rule becomes one public pure function.** `_media_layout` (`app/games/modules/game_guesser.py:136-162`) is private and raises. M1-24b splits out `clue_layout_problem(clue) -> str | None`, which `_media_layout` keeps using, so the builder, scheduling (AC-58) and the buffer check (AC-74) apply the same rule the view applies on read.
- **R-15. Conservative replay guard for title updates (AC-18).** The import refuses to change `normalized_name`, `normalized_franchise` or `kind` of a title that a stored guess references (`progress_guesses.title_id`) or that is the answer of a puzzle with stored games, and reports it. A change of the display name with the same normalized name is allowed. This refuses more than a real replay check would, with no replay code; production has no stored games before launch, so it bites only later.
- **R-16. Scheduling never leaves a hole.** It walks the dates from the first schedulable day (AC-56). On each free date it takes the first approved, ready puzzle (by `approved_at`, then id) that keeps the 14-day series rule against every scheduled puzzle on either side (AC-57). If none fits, it stops and reports the date, instead of skipping it, because a gap ends the buffer (AC-75).
- **R-17. The review page is a separate tiny app, not an API route.** `app/content/review/app.py` is a small Starlette app served by `scripts/review_puzzles.py` on `127.0.0.1` only, with HTML built by one escaping helper (no template engine, no new dependency). It is never mounted in `app/main.py`, so decision 11 (no admin UI) and the OpenAPI snapshot hold. Because any web page in the owner's browser could POST to a local port, every POST needs the page's own `Origin`, a random per-process form token, and a `Host` of `127.0.0.1:<port>` or `localhost:<port>` (DNS rebinding). The response has `Content-Security-Policy: default-src 'self'` and no script.
- **R-18. `source_url` is built, never copied:** `https://www.igdb.com/games/<slug>`, with the IGDB `slug` checked against `^[a-z0-9]+(-[a-z0-9]+)*$`. A candidate whose slug fails is skipped and counted (AC-33 needs a source on every clue). The frontend shows the host without a leading `www.` (frontend plan R-2).
- **R-19. The critic score rounds half up.** Python's `round(84.5)` is 84 (banker's rounding). The hint uses `Decimal(...).quantize(Decimal(1), ROUND_HALF_UP)`; one table row pins 84.5 to "85".
- **R-20. Candidates are a subset of the search list by construction.** Candidates need 50 or more ratings and one of four game types; the search list takes 1 or more rating and five types (AC-10, AC-21). So "plus every candidate" (AC-10) needs no extra query. One assertion in the M1-22b filter test keeps this true if a threshold changes. A candidate whose normalized name and year collide with another stored title (a near-duplicate the import dropped) is skipped and counted, so the builder never adds a duplicate title.

**Findings to report (spec text that disagrees with itself or with the code):**

- **AC-50 vs AC-51.** AC-50 says "`draft` is used only by a draft the reviewer sent back for a rebuild"; AC-51 says a rejection, "rebuild" included, deletes the draft. This plan follows AC-51 (with R-9): no tool leaves a puzzle in `draft`. The status stays in the CHECK for the dev seed.
- **Exit codes collide with Python's defaults.** `argparse` exits 2 on a usage error, and an uncaught exception exits 1. Both would read as "tomorrow missing" and "buffer low". The check overrides `ArgumentParser.error` and catches every exception, so both give code 3 (AC-80).
- **The candidate funnel needs a definition of "ratings".** IGDB has `rating_count` (its users) and `total_rating_count` (users and critics). Default: `total_rating_count`, a setting next to the thresholds (Open point 3).
- **`MILESTONE-1.md:95` lists M1-22's clip as "not yet estimated"**: sized in "Order and estimates". Promote (R-10) is not in the milestone table.
- **The seed and one test name `metacritic_score`** (`scripts/seed_dev.py:79`, `:102`, `:198`; `tests/test_games.py:801`). M1-22b changes them to `critic_score` with the `CONTRACTS.md` edit.

## Execution mode

- **Owner's choice (2026-11-12, given with the task; not asked again):** one `implementer` agent per PR, on that PR's section only, then one `plan-verifier` run against that PR's checks. The owner merges. `shvab:implement-plan` runs that loop for one section. Commits, pushes and PRs only when the owner asks.
- **Required extra passes:** every backend PR with a migration or a route gets `code-review` at `high` (up to two fix rounds), then `test-writer`, before its commit. In this plan that is **M1-22a** (migration) and **M1-24a** (the review page's routes). No other PR adds a migration or an API route.
- **My recommendation for further `code-review` high passes** (agent minutes only; the owner can drop any):

| PR | Recommended extra | Why |
|---|---|---|
| M1-20 | `code-review` high | Secrets in the environment, a retry loop that must end, token renewal |
| M1-21 | `code-review` high, `test-writer` | AC-17 and AC-18 protect stored games; idempotence |
| M1-22b | `code-review` high | The salt and the seed are the whole defence against computed answers (AC-26 to AC-28) |
| M1-22d | `code-review` high, `test-writer` | Atomic draft writes, the target guard, the IGDB image gate, the fetch allow list |
| M1-24b | `code-review` high | Today's and past puzzles are locked (AC-59, AC-86) |
| M1-24c | `code-review` high, `test-writer` | Writes to another environment's database and bucket |
| M1-22c, M1-25 | none | Pure media code pinned by its limit table; a read-only check pinned by its code table |

- **Test budget, told to `implementer` and `test-writer` up front** (`fastapi-service-patterns/SKILL.md:64-87`, owner's rule of 2026-11-04): one happy-path `client` test per endpoint (only M1-24a has endpoints), plus 1 to 3 unit tests or parametrized tables per feature. Every test must be able to fail: check it by mutating the rule (delete the guard, invert the condition) and watching it go red, with `PYTHONDONTWRITEBYTECODE=1` and a cleared `__pycache__` (owner's note after M1-14). `test-writer` adds a test only where such a mutation leaves the suite green, and names the mutation. The spec's CI list (`specs/04-…:333`) is covered by the tables named per PR; no more.
- **Paired waves.** Each PR keeps its own implementer, plan-verifier, reviews and merge; the second to merge rebases. Pairs were chosen where nothing builds on the paired PR and few files are shared:
  - **Wave A: M1-22a with M1-20.** Schema versus an HTTP client; shared files: `my-list-be/CLAUDE.md`, `.env.example` (different sections).
  - **Wave B: M1-21 with M1-22c.** Title import versus pure media code. Only M1-22c changes `pyproject.toml` and `uv.lock` (Pillow, PyAV); the one shared file is `CLAUDE.md`.
  - **Wave C: M1-24a with M1-24b.** Review versus scheduling; both add functions to `app/crud/puzzle.py` (append-only, rebase) and touch `CLAUDE.md`.
  - **Wave D: M1-25 with M1-24c.** Both use M1-24b's readiness function and change nothing in it.
  - Not paired: M1-22b (M1-22d builds on it, and it carries the boundary edit with the frontend label), M1-22d (everything after builds on it).
  - **Frontend alongside.** M1-23 (Sources) can run at any time, best alongside wave A. FE-Q3 (the label) merges in the same pass as M1-22b.
  - **Costs of a wave:** a second worktree of `my-list-be`; a separate test database per agent (`TEST_DATABASE_URL=.../daily_game_challenge_test_<prefix>`), because the suite drops its tables (`tests/conftest.py`); one session scratchpad shared by both agents, so each gets a file prefix and never runs a scratch script it did not just write; the owner reviews two PRs at once.
  - **Scratch prefixes:** `p3_22a_`, `p3_20_`, `p3_21_`, `p3_22c_`, `p3_22b_`, `p3_22d_`, `p3_24a_`, `p3_24b_`, `p3_25_`, `p3_24c_` (frontend: `p3_23_`, `p3_q3_`).
- **Squash merge** (`ARCHITECTURE.md:156`). `main` has no branch protection, so "CI green" is checked by hand on all four jobs.

## Order and estimates

Agent minutes are estimates, calibrated on Phase 1 and 2 (planners took 5 to 15 minutes; implementer PRs tens of minutes). Columns in brackets are my recommended extra passes; the required ones are not bracketed. Owner review is separate and is usually the larger cost.

| Step | PR | Waits for | Implementer | plan-verifier | code-review high + fixes | test-writer | Agent total | Owner review |
|---|---|---|---|---|---|---|---|---|
| 1 (wave A) | **M1-22a** content schema | nothing | 15 | 5 | 12 | 6 | ~40 min | 20 min |
| 1 (wave A) | **M1-20** IGDB client, fixtures, `igdb_list` | nothing | 20 | 5 | [12] | none | ~25 (40) min | 20 min |
| 2 (wave B) | **M1-21** title import | M1-22a, M1-20 | 25 | 6 | [15] | [8] | ~30 (55) min | 25 min |
| 2 (wave B) | **M1-22c** media: images, step-6 clip, poster | nothing (start after wave A for a free slot) | 5 spike + 30 | 6 | none | none | ~40 min | 25 min (look at a generated clip) |
| 3 | **M1-22b** candidates, seed, hints, `CONTRACTS.md` | M1-22a, M1-20 | 20 | 5 | [12] | none | ~25 (40) min | 20 min |
| 3 (frontend) | **FE-Q3** `critic_score` label | merges with M1-22b | 3 | 2 | none | none | ~5 min | 2 min |
| 4 | **M1-22d** builder: drafts, storage writer, dry run | M1-21, M1-22b, M1-22c | 30 | 6 | [15] | [8] | ~35 (60) min | 30 min |
| 5 (wave C) | **M1-24a** review page | M1-22d | 25 | 6 | 15 | 8 | ~55 min | 25 min (and one real review) |
| 5 (wave C) | **M1-24b** scheduling, readiness | M1-22d | 20 | 5 | [12] | none | ~25 (40) min | 20 min |
| 6 (wave D) | **M1-25** buffer check | M1-24b | 15 | 5 | none | none | ~20 min | 15 min |
| 6 (wave D) | **M1-24c** promote, game settings | M1-24b, M1-22d | 25 | 6 | [15] | [8] | ~30 (55) min | 25 min |
| any (frontend) | **M1-23** Sources section | nothing | 20 | 5 | none | none | ~25 min | 15-20 min |

Wall clock of agent time with the waves: about 40 + 40 + 25 + 35 + 55 + 30 ≈ **3.75 hours** with the required passes only, or about 40 + 55 + 40 + 60 + 55 + 55 ≈ **5 hours** with every recommended pass. Owner review of the PRs: about **4 hours** in all, between steps.

**The step-6 clip (M1-22, "not yet estimated" in `MILESTONE-1.md:95`):** about **0.5 developer days** on the milestone's scale. In agent terms it is the spike (5 min) and about 15 of M1-22c's 30 implementer minutes (frame rendering, encoding, poster, the size loop), plus about 30 minutes of the owner looking at the first real clips and tuning pan speed, fade length and quality. Promote (R-10, about 0.3 days) is also not in the milestone table. The other human-day estimates in `MILESTONE-1.md:93-98` are not changed by this plan.

**Owner time on real data, after the gates open** (not agent time): Twitch account and IGDB email, about 25 min; first title import, under an hour of machine time (non-functional target) and 10 min of the owner; threshold counts (AC-24), 15 min; building 40 drafts, about 20 to 30 min of machine time; reviewing 30 or more drafts at the D5 budget of 10 a day, 10 min a day for 3 to 4 days plus rebuilds (AC-54).

## Gates (owner prerequisites; none blocks starting)

Work that needs no IGDB credentials starts first: the schema, the client against hand-made fixtures, the media code, the filters, seed and hints over fixtures, the builder with a fake IGDB and generated images, review, scheduling, the check and promote, all tested in CI with no network.

| Gate | Owner action | What waits for it | What does not |
|---|---|---|---|
| **G1 = D2** | Twitch developer account (two-factor), `IGDB_CLIENT_ID` and `IGDB_CLIENT_SECRET` in the workstation `.env`; read the terms at signup | AC-9 (five games), the real title import and the AC-20 benchmark, the AC-24 counts, real drafts | Every PR's code and CI |
| **G2 = Q1 email** | Email partner@igdb.com (AC-1); record the answer as a decision in `SPEC.md` section 2; set `IGDB_IMAGES_CLEARED_BY` | Any IGDB screenshot outside `local` (AC-2): the builder or promote with a non-local target | Building and reviewing in `local` |
| **G3 = D5** | The owner reviews (10 a day) | AC-54, approved puzzles, DoD item 7 | M1-24a code |
| **G4 = launch date (Q17)** | Set the production launch date before Phase 5 (`scripts/manage_game.py`, M1-24c) | AC-61 (30 from the launch date), the check's "not launched" window ending | Scheduling in `local` (the seed's launch date) |
| **G5 = D3** | Hosting and a production database and bucket (Phase 4/5) | Running promote, scheduling and the check against production | Testing promote between two local databases |

If IGDB says no and the owner does not accept the risk, the fallback of `MILESTONE-1.md` section 6 applies (a hand-built list with the owner's screenshots). The builder's media and draft code is reusable for it; only the IGDB fetch would change. Not planned here.

## Modules affected

| Where | What | PR |
|---|---|---|
| `app/models/title.py`, `app/models/puzzle.py`, `app/models/exclusion.py` (new), `app/models/__init__.py`, one migration, `app/games/enums.py` (`ExclusionReason`), `app/games/service.py`, `app/games/modules/base.py` (date narrowing) | `titles.igdb_id`; optional `puzzles.date`; `build_slot`, `generator_version`, `approved_at`; `puzzle_clues.source_image_ids`; table `answer_exclusions` | M1-22a |
| `app/content/settings.py`, `app/content/igdb.py`, `app/content/fetch.py` (new), `scripts/igdb_list.py` (new), `tests/fixtures/igdb/` (new), `pyproject.toml`, `uv.lock` | Client, allow-listed fetch, AC-9 CLI | M1-20 |
| `app/content/target.py`, `app/content/titles_import.py`, `app/content/franchise_overrides.py` (new), `app/crud/title.py`, `scripts/import_titles.py` (new), `scripts/bench_title_search.py`, `scripts/seed_dev.py` (import `refusal_reason`) | Import, target guard, real-list benchmark | M1-21 |
| `app/content/media.py` (new), `pyproject.toml`, `uv.lock` (`pillow`, `av`) | Images, crop, clip, poster, measurement, limits | M1-22c |
| `app/content/candidates.py`, `app/content/seed.py`, `app/content/hints.py` (new), `app/crud/puzzle.py`, `app/crud/exclusion.py` (new), `scripts/build_puzzles.py` (new, `--counts` only), `scripts/seed_dev.py`, `tests/test_games.py:801` | Filters and counts, seed, hint values, `critic_score` | M1-22b |
| `app/media/writer.py` (new), `app/content/builder.py` (new), `scripts/build_puzzles.py`, `.gitignore` | Store files, write drafts, dry run, rebuilds | M1-22d |
| `app/content/review/` (new: `app.py`, `html.py`, `actions.py`), `scripts/review_puzzles.py` (new), `app/crud/puzzle.py`, `app/crud/exclusion.py` | Review page, approve, reject | M1-24a |
| `app/games/modules/game_guesser.py` (R-14), `app/content/readiness.py`, `app/content/schedule.py` (new), `app/crud/puzzle.py`, `scripts/schedule_puzzles.py` (new) | Readiness, scheduling, unscheduling | M1-24b |
| `app/content/buffer_check.py` (new), `scripts/check_puzzle_buffer.py` (new) | Tomorrow and buffer check | M1-25 |
| `app/content/promote.py`, `scripts/promote_puzzles.py`, `scripts/manage_game.py` (all new) | Copy approved puzzles to a target; launch date | M1-24c |
| `my-list-be/CLAUDE.md`, `.env.example` | A "Content" section grown per PR; new settings | every PR |
| Root `CONTRACTS.md` "Games", "The view" (`:355-361`) | `critic_score` replaces `metacritic_score` in the hint kinds; `source_url` is the game's igdb.com page; the file-limits table says 1 MB = 1,048,576 bytes (owner, 2026-11-13, decision 70) | M1-22b (platform commit) |

Not touched: `app/main.py`, `app/api/`, every route and response schema, `openapi/openapi.json`, `.github/workflows/ci.yml`, `app/auth/`.

## Facts found (file:line)

| Fact | Where |
|---|---|
| `puzzles.date` is `NOT NULL`; unique `(game_id, variant, date)` named `uq_puzzles_game_id_variant_date` | `app/models/puzzle.py:34`, `:43`; `app/alembic/versions/dece8484277f_…py:109-110` |
| Unique names use `column_0_N_name`, so `(game_id, variant, build_slot)` gets a distinct name | `app/core/db.py:16` |
| Statuses `draft`, `in_review`, `approved`, `scheduled`; no `rejected` | `app/models/puzzle.py` `PuzzleStatus` |
| `titles` has no source id; `kind` is only `video_game`; `year` nullable | `app/models/title.py:10`, `:46` |
| `hint_kind` is free text, at most 32 characters; `hint_value` at most 255; `source_url` is `Text`, nullable | `app/models/puzzle.py:70`, `:80-82` |
| Only `create_title` and `update_title` write the normalized columns | `app/crud/title.py:26-49`; `my-list-be/CLAUDE.md:101` |
| Visibility is one SQL condition; a NULL date never passes `date <= today` | `app/crud/puzzle.py:15-36` |
| Every use of `puzzle.date` in the service is on a visible puzzle | `app/games/service.py:253`, `:288`, `:345-347`, `:475-476`, `:529-561` |
| The AC-13b rule is private and raises | `app/games/modules/game_guesser.py:136-162`, called at `:51` |
| `PuzzleData.date` is `dt.date` | `app/games/modules/base.py:79` |
| Storage has `signed_url` only, no write or exists | `app/media/storage.py:12-15`, `:27-107` |
| boto3 is a runtime dependency; httpx is dev-only; no Pillow, no PyAV | `pyproject.toml` |
| The seed deletes every puzzle of the game; its draft has a date; hint kinds include `metacritic_score`; `SOURCE_URL` is `https://example.com/seed/source` | `scripts/seed_dev.py:167`, `:96`, `:79`, `:47` |
| `refusal_reason` reads the `ENVIRONMENT` variable itself and checks a local DB host | `scripts/seed_dev.py:233-247` |
| The benchmark inserts 50,000 synthetic titles; its only option is `--titles` | `scripts/bench_title_search.py:1-21`, `:272` |
| `is_weak_secret` (placeholder or under 32 characters) | `app/core/config.py:21` |
| `.gitignore` ignores `var/media/` only | `.gitignore` |
| `CONTRACTS.md` lists the hint kinds and says `source_url` is null until the end; the media limits table | `CONTRACTS.md:355-361`, `:426-435` |
| CI: uv 0.13.6; migrations and openapi jobs install `--no-dev` | `ci.yml:19`, `:91`, `:114` |
| The frontend labels hint kinds from a map; unknown kinds show "Hint" | `my-list-fe/src/features/games/clue-ladder/clue-ladder.tsx:8-27` |
| Local machine: uv 0.12.5 (CI pins 0.13.6); no ffmpeg, ffprobe or cwebp; `dgc-dev-pg` and `dgc-dev-redis` exist (stopped); port 5433 is held by `devdigest-postgres` | checked 2026-11-12 |

## Architectural constraints

- Layering: router, service, query layer `app/crud/<entity>.py`, models; no `select()` or `session.execute()` outside `app/crud/` (`my-list-be/CLAUDE.md:79-91`; `SKILL.md:24-37`). Content code follows it: `app/content/*` calls `app/crud/*`.
- Every CHECK has a `name=`; a CHECK built from a StrEnum is text, and changing the enum needs a hand-written migration (`my-list-be/CLAUDE.md:94-95`). Tables plural with integer keys (`:97`).
- `alembic check` does not compare CHECK text or operator classes: compare a migrated database with a `create_all` one by hand (`my-list-be/CLAUDE.md:95`, `:100`).
- Puzzle visibility is one condition; do not write a second copy (`my-list-be/CLAUDE.md:98`). Time comes from `app/core/clock.py`; services take `now` (`:99`).
- Normalized title columns are written only through `create_title`/`update_title` (`my-list-be/CLAUDE.md:101`).
- No blocking calls in `async def` paths (`SKILL.md:95-96`). Scripts may block, but S3 calls inside an async script run in `asyncio.to_thread`.
- `print()` is fine in scripts only (`SKILL.md:101`); library code under `app/content/` returns data, and the CLI prints it.
- Errors in the API are `AppException` subclasses (`my-list-be/CLAUDE.md:13`). Content code raises its own exceptions, which the CLIs turn into messages and exit codes; it never reaches the API.
- Commit `uv.lock` with any dependency change; lock with CI's uv 0.13.6 (`my-list-be/CLAUDE.md:41`; Phase 1 plan risk).
- Content-hash media keys, private storage, EXIF stripped, a secret salt from the environment, puzzle data never in Git, a deterministic seed with tests on a fixed test salt (`ARCHITECTURE.md:199`; decision 59).
- Allow-list hosts for any fetch-by-URL in the scripts; validate third-party data (`ARCHITECTURE.md:251`; AC-85).
- The repos are public: no real screenshot, clip, answer list or draft in Git; test fixtures are made by us (AC-43).
- A boundary change covers backend, frontend and `CONTRACTS.md` in one pass; frontend types are regenerated with Orval, never hand-patched (root `CLAUDE.md`, "Working across both repos").
- The test suite drops tables and flushes Redis: test URLs must differ from dev ones (`my-list-be/CLAUDE.md:13`, `:49`).

## Approach

Every PR: branch from a fresh `main` (`m1-xx-short-name`), PR to `main`, the four CI jobs green. Every PR runs `uv run python scripts/export_openapi.py --check` and **expects no change**; a diff means the PR touched the API by mistake, and the agent stops and reports. Every PR adds its part to a new "Content" section of `my-list-be/CLAUDE.md` (commands, settings, what the script refuses) and its settings to `.env.example`.

### PR M1-22a: content schema (AC-15, AC-46, AC-51, AC-55 schema) — migration, code-review high + test-writer

1. Models:
   - `titles.igdb_id`: `BigInteger`, nullable, unique (`uq_titles_igdb_id`). NULLs are distinct, so the seed's titles stay valid (AC-15).
   - `puzzles.date`: nullable, `Mapped[dt.date | None]`; new CHECK `scheduled_has_date`: `status <> 'scheduled' OR date IS NOT NULL` (R-6, AC-46).
   - `puzzles.build_slot` (`Integer`, nullable, CHECK `build_slot > 0`, name `build_slot_positive`), `puzzles.generator_version` (`String(32)`, nullable), `puzzles.approved_at` (`DateTime(timezone=True)`, nullable); unique `(game_id, variant, build_slot)` (R-7).
   - `puzzle_clues.source_image_ids`: `ARRAY(String(32))`, nullable: the IGDB image ids the clue was made from, kept for the builder's records (AC-33). Never in any response.
   - New `answer_exclusions` (`app/models/exclusion.py`): `id`, `game_id` FK `RESTRICT`, `title_id` FK `RESTRICT`, `reason` (CHECK from `ExclusionReason`: `rebuild`, `never`), `build_slot` (nullable; the slot to rebuild), `image_ids` (`ARRAY(String(32))`, not null, server default `'{}'`), `created_at`; index on `(game_id, title_id)`. Export it from `app/models/__init__.py`, so `alembic/env.py` sees it.
2. Code that reads `puzzle.date`: every caller handles a visible puzzle, whose date is set. Narrow once where the service builds `PuzzleData` (`app/games/service.py`, the place that fills `date=` for the module) with an explicit check that raises `PuzzleDataError` on `None`, so the module's `date: dt.date` stays true. No other behaviour changes.
3. One migration, `uv run alembic revision --autogenerate -m "add content columns and answer exclusions"`. Review by hand: the CHECK and the `ARRAY` columns; the downgrade drops the new table and columns and makes `date` `NOT NULL` again, after **refusing with a clear error** if any row has a NULL date (never delete data in a downgrade). On an empty database the downgrade runs clean.
4. `scripts/seed_dev.py`: its draft gets `date=None` (the tools' rule, R-6). Nothing else.
5. Tests (one table, `tests/test_game_schema.py`): a scheduled puzzle with no date is refused; two drafts with no date for one game and variant are allowed; two puzzles with the same `(game, variant, build_slot)` are refused; an exclusion with reason `maybe` is refused. Plus the existing visibility table still passes, with one added row: a scheduled puzzle cannot exist without a date, so "approved, no date" is invisible.
6. Docs: `CLAUDE.md` "Database conventions": the optional date and its CHECK, the slot, the exclusion table.

### PR M1-20: IGDB client (AC-3 to AC-9, AC-85) — wave A

1. `pyproject.toml`: a `content` group with `httpx` (R-4), `default-groups = ["dev", "content"]`; `uvx uv@0.13.6 lock`.
2. `app/content/settings.py` (R-3): `ContentSettings` with `IGDB_CLIENT_ID: str | None`, `IGDB_CLIENT_SECRET: SecretStr | None` and the rest added by later PRs. A helper `require(*names)` stops the run before any request with "IGDB_CLIENT_SECRET is not set" (AC-3). Secrets never appear in `repr`, logs or errors.
3. `app/content/fetch.py`: one `httpx.AsyncClient` factory with the allow list `{"api.igdb.com", "id.twitch.tv", "images.igdb.com"}` checked on every request (an event hook that refuses any other host, before the request leaves), `https` only, no redirects followed, a timeout, and a size cap on bodies (AC-85).
4. `app/content/igdb.py`:
   - **Token:** client-credentials POST to `id.twitch.tv`; kept in memory only; renewed once and the request repeated when IGDB answers 401 (AC-4).
   - **Limits:** at most 4 request starts per second and 8 open requests (an `asyncio.Semaphore(8)` and a start-time spacer of 250 ms) (AC-5).
   - **Retries:** 429 and 5xx wait (exponential, honouring `Retry-After` when present) and retry at most 5 times, then raise `IgdbUnavailable` with a message; the CLI exits non-zero (AC-5).
   - **Paging:** `limit 500`, keyset on `id` (`where id > <last>; sort id asc;`) rather than a growing offset; an async iterator over pages (AC-6). Check the query syntax and the `game_type` field (which replaced `category`) with `docs` against the IGDB v4 API docs.
   - **Records:** Pydantic models for what AC-7 lists: id, name, slug, `first_release_date`, `game_type`, `version_parent`, `parent_game`, `franchise`, `franchises`, `collections`, `release_dates` (date, platform name), genres, `involved_companies` (company name, `developer` flag), `aggregated_rating`, `aggregated_rating_count`, `total_rating_count`, screenshots (`image_id`, width, height). One `IgdbGame` per record after validation: a wrong shape, a name with no letter or digit, a year outside 1950 to next year, or a screenshot with no id or size is skipped and counted by reason, never raised (AC-8). `image_id` must match `^[a-z0-9]+$` (it goes into a URL).
   - IGDB text is data: no field is ever put into a shell command, SQL text or HTML without escaping (spec "Untrusted inputs").
5. `scripts/igdb_list.py` (read-only, no target): `--limit 5` prints five games with every AC-7 field, "missing" where absent (AC-9). No answers are involved.
6. `tests/fixtures/igdb/`: hand-written JSON in IGDB's documented shape (a page of games with every field, a second page, a record per AC-8 skip reason, a 401 then 200, a 429 with `Retry-After`, a run of 503s). Made by us; no recorded real response is committed. After G1 the owner runs `igdb_list.py` once and the agent of M1-21 compares a real record with the fixture shape.
7. Tests (`tests/test_igdb_client.py`, `httpx.MockTransport`, no network): **(a)** one table over the transport: two pages joined in order; 401 renews once then succeeds; a second 401 fails; 429 then 200 succeeds; six 503s stop with `IgdbUnavailable` (bounded); a request to another host is refused before sending. **(b)** one validation table: each AC-8 skip reason counted, a valid record mapped. **(c)** a timing test of the spacer with an injected clock (no request starts sooner than 250 ms after the previous one).
8. Docs and `.env.example`: `IGDB_CLIENT_ID`, `IGDB_CLIENT_SECRET` (empty), and "never commit or print them".

### PR M1-21: title import (AC-10 to AC-20) — wave B

1. `app/content/target.py` (R-13): `refusal_reason` (moved from `seed_dev.py`, which now imports it), `TargetGuard` (`--target`, `--confirm-target`, prompt, `CI` refusal, the printed line). `bench_title_search.py` and `seed_dev.py` import from here.
2. `app/crud/title.py`:
   - `create_title` and `update_title` take `igdb_id` (keyword, default `None`).
   - `get_titles_by_igdb_ids(db, ids)`, and `find_near_duplicate(db, kind, normalized_name, year, exclude_id)`.
   - `referenced_title_ids(db, ids)`: ids referenced by `progress_guesses.title_id`, or answer of a puzzle that has a `progress` row (R-15).
3. `app/content/titles_import.py` (pure mapping plus one service function):
   - **Scope** (AC-10, AC-11): `game_type` in main game, remake, remaster, expanded game, standalone expansion; no `version_parent`; `total_rating_count >= 1` (R-20 makes candidates a subset).
   - **Franchise** (AC-12): main `franchise` name, else the first of `collections` by IGDB id order. Clean: trim, collapse spaces, drop a trailing qualifier in parentheses such as "(series)". Then `FRANCHISE_OVERRIDES` (`app/content/franchise_overrides.py`, IGDB franchise or collection id to name, empty or a few entries; no answers).
   - **Year** (AC-13): UTC year of `first_release_date`, else `None`.
   - **Near-duplicates** (AC-14): within a run, group by (normalized name, year); keep the record with more ratings (then the lower IGDB id). Against stored titles: an existing title is never replaced (AC-17); a new record that collides with one counts as "near-duplicate".
   - **Upsert** (AC-15, AC-16): match by `igdb_id`; unchanged fields mean no write, so `updated_at` does not move. A change that R-15 forbids for a referenced title is "refused" and the title is left as it is (AC-18). Nothing is ever deleted (AC-17).
   - Commits every 1,000 titles, so a stopped run keeps its progress and a re-run continues (AC-16, edge case "429 for a while").
   - Returns counts: added, updated, unchanged, near-duplicates, refused, skipped (AC-8) (AC-19).
4. `scripts/import_titles.py --target <env> [--confirm-target <env>]`: guard, read IGDB through M1-20, print the counts.
5. `scripts/bench_title_search.py`: a `--existing` flag that times the same queries against the titles already in the database, inserting and deleting nothing (AC-20; "the" and "zlda" are in its query list).
6. Tests (`tests/test_titles_import.py`):
   - **(a)** pure mapping table: the franchise rule (franchise; no franchise, first collection; neither; "(series)" dropped; override applied), scope (each excluded type, a version of another game, zero ratings), the year (none; 1950 edge).
   - **(b)** database table over fixtures: "Doom" 1993 twice and "Doom" 2016 give two titles (AC-14); a second run over the same data changes no row and no `updated_at` (AC-16); a title referenced by a stored guess keeps its normalized name when IGDB renames it, and is counted as refused (AC-18); a title missing from the second run's data stays (AC-17).
   - That is the budget: no client test (no endpoint).
7. Docs: the R-11 content database; how to run the import and the benchmark against the real list.

Manual after G1: two real runs, the second all "unchanged"; "zlda" finds Zelda titles with years in the frontend; `bench_title_search.py --existing` p95 under 150 ms, recorded in the PR or a follow-up note. If it misses, the owner picks a Phase 1 fallback (3-character minimum, or ignoring stop words) before launch (AC-20).

### PR M1-22c: media processing (AC-34 to AC-40) — wave B

1. **Spike first (R-5)**, 5 minutes, results in the PR text: `uv add --group content pillow av`; check that PyAV can open an H.264 encoder, and that Pillow writes WebP. If PyAV has no H.264 encoder, use `imageio-ffmpeg` for encoding as R-5 says, and stop to report if that also fails.
2. `app/content/media.py`, pure functions over files in a working folder, no database, no network:
   - `still(source, out)`: fit within 1920x1080, WebP, all metadata dropped (open, convert to RGB, save without `exif`/`icc_profile`/XMP), quality starting at 82 and lowered in steps down to 50 until under 1 MB, else raise `MediaLimitError` (AC-35, AC-39).
   - `pixelated_crop(source, out, rng)`: a crop of about a third of the width at a position from `rng` (the `crop` stream), scaled down to blocks of about 20 px and back up with nearest-neighbour, output 960x540 WebP. These are start values in named constants for the owner to tune after the first real drafts (AC-34).
   - `clip(sources, out_mp4, rng)`: 2 or 3 screenshots, 12 s at 24 fps, 1280x720; each shot a slow pan or zoom (about 1.0 to 1.1), 1 s cross-fades; H.264 `yuv420p`, `+faststart`, no audio stream, CRF lowered in steps until under 4 MB, else `MediaLimitError` (AC-36, AC-37, AC-39). No WebM in Milestone 1 (it is optional, SPEC-02 Q20).
   - `poster(clip_mp4, out)`: the clip's first frame, decoded from the encoded file, as WebP under the image limits (AC-40).
   - `measure(path) -> MediaFacts`: content type, byte size, width, height and duration, read from the file itself (Pillow for WebP, PyAV for MP4: one video stream, codec H.264, zero audio streams) (AC-39). The builder stores these values, never the intended ones.
   - Limits come from one table in the module, equal to `CONTRACTS.md:426-435`.
3. Tests (`tests/test_content_media.py`, images generated in the test with Pillow, small sizes):
   - **(a)** one table of limits over generated inputs: a 3000x2000 noisy image becomes a WebP within 1920x1080 and 1 MB with no EXIF (the input carries EXIF and a GPS tag); the crop is within bounds and pixelated (few distinct colours per block); an incompressible input that cannot fit raises `MediaLimitError`.
   - **(b)** the clip from three generated 1280x720 images: `measure` gives `video/mp4`, 8 to 15 s, at most 1280x720 and 4 MB, no audio stream; the poster equals a decoded frame of the clip (pixel difference small).
   - **(c)** determinism: the same `rng` seed gives byte-identical stills and the same crop box (the clip encoder is not required to be byte-identical; its parameters are).
4. Docs: dependencies and the start values; no data is committed.

### PR M1-22b: candidates, seed, hints, the `critic_score` boundary edit (AC-21 to AC-28, AC-30 to AC-33)

1. `ContentSettings` gains `PUZZLE_SEED_SALT: SecretStr | None`, `CANDIDATE_MIN_RATINGS = 50`, `CANDIDATE_MIN_SCREENSHOTS = 7`, `CANDIDATE_MIN_WIDTH = 1280`, `CANDIDATE_MIN_HEIGHT = 720`, `CANDIDATE_MIN_AGE_DAYS = 365`, `CANDIDATE_RATING_FIELD = "total_rating_count"` (AC-22; Open point 3).
2. `app/content/seed.py` (R-8): `check_salt(salt, other_secrets)` refuses a missing salt, `is_weak_secret` (`app/core/config.py`), or a salt equal to `SECRET_KEY`, `MEDIA_SIGNING_KEY`, `IGDB_CLIENT_SECRET` or `S3_SECRET_ACCESS_KEY` (AC-27); `SlotSeed(salt, slug, variant, slot, version).stream(purpose) -> random.Random`. The builder calls `check_salt` before reading IGDB. Tests pass a fixed test salt.
3. `app/content/candidates.py`, pure:
   - `funnel(games, *, today, settings, earlier_answer_igdb_ids, never_igdb_ids) -> Funnel`: the filters in order, each with its count, and the final list (AC-24). Order: game type and not a version (AC-21); released at least a year before `today`; ratings; screenshots of at least 1280x720, at least 7 (AC-21); a valid IGDB slug (R-18); not excluded "never" (AC-23); not an earlier answer in any status (AC-25).
   - `choose_answer(candidates, stream)`: sort by IGDB id, pick with the stream.
   - `assign_screenshots(game, stream, avoid_ids)`: from the eligible screenshots minus `avoid_ids` (R-9), sorted by `image_id`, pick 4 for steps 2 to 5, 1 for the step-1 crop, and 2 or 3 for the clip, all distinct (AC-34, AC-37). Fewer than 7 left: not buildable, reported.
4. `app/content/hints.py`, pure (AC-30, AC-31): step 1 `None`; step 2 `critic_score` = `aggregated_rating` rounded half up (R-19) only when `aggregated_rating_count >= 4`; step 3 `platform` = the platforms of the earliest release date; step 4 `genre`; step 5 `year`; step 6 `developer` (companies with the developer flag). At most three values joined by ", ", at most 255 characters (cut whole names, never mid-word), English as IGDB gives it, `None` when missing (never invented). Never `metacritic_score`. `source_url(game)` builds the igdb.com page (R-18, AC-33).
5. `app/crud/puzzle.py`: `list_answer_igdb_ids(db, game_id)` (every status). `app/crud/exclusion.py`: `list_exclusions(db, game_id)`.
6. `scripts/build_puzzles.py --counts`: the AC-24 funnel against IGDB, printed as "filter: passed N", with no answers. The build itself lands in M1-22d.
7. **Boundary pass (critic_score, Q3, Q12).** In this PR:
   - `scripts/seed_dev.py:79`, `:87`, `:93`, `:102`, `:198`: `metacritic_score` becomes `critic_score` (the field `has_metacritic_hint` becomes `has_critic_hint`), so dev data uses the new kind. `tests/test_games.py:801` follows.
   - **Platform commit, `CONTRACTS.md` "Games", "The view" (`:358-361`):** the kinds today are `critic_score` (IGDB's aggregated critic score, shown only when at least 4 critic scores back it), `platform`, `genre`, `year` and `developer`; `metacritic_score` is no longer produced. After `:357` ("`source_url` (`null` until the game ends)"): "For the game guesser it is the game's page on igdb.com (`https://www.igdb.com/games/<slug>`) for every clue made from IGDB screenshots, the clip included. It is a plain link the frontend shows as a source; it never carries a signed link." **This is the only PR that edits `CONTRACTS.md` in Phase 3.**
   - Frontend **FE-Q3** (`plans/04-phase-3-frontend.md`) adds the "Critic score" label in both catalogues. Merge order: FE-Q3 first or together; a kind with no label still shows under "Hint", so neither order breaks anything.
   - No Orval regeneration: `hint.kind` is a free string in the snapshot, and no schema changes. `export_openapi.py --check` passes unchanged.
8. Tests: **(a)** `tests/test_content_seed.py`: one salt gives the same answer, screenshots and crop stream twice; another salt gives a different choice on a fixture of 50 candidates; a missing, short, placeholder or reused salt is refused (AC-27, AC-28). **(b)** `tests/test_candidates.py`: one funnel table over fixture games, one row per filter (a 6-screenshot game, 1279-wide screenshots, 49 ratings, released 364 days ago, an edition, a "never" title, an earlier answer), the counts adding up (AC-24), and the R-20 subset assertion. **(c)** `tests/test_hints.py`: one table: 84.5 with 4 scores gives "85"; 3 scores gives `None`; four platforms give three joined; no developer gives `None`.

### PR M1-22d: the builder (AC-2, AC-29, AC-32, AC-33, AC-41 to AC-46, AC-50, AC-52)

1. `app/media/writer.py`, script-only and sync (the API never imports it): `MediaWriter` with `put(key, path, content_type)` (no-op when the key exists, AC-41) and `exists(key)`; `LocalMediaWriter` writes into `settings.media_local_path` with a temp file and `os.replace` (no half file); `S3MediaWriter` uses `head_object` and `put_object` with `ContentType` and no public ACL, built from the same settings as `S3MediaStorage` (`app/media/storage.py:57-86`). Async callers wrap it in `asyncio.to_thread`.
2. `app/content/builder.py`, per slot in ascending order:
   - check the salt (M1-22b) before any IGDB request (AC-27); check the IGDB image gate (R-12) before anything when the target is not `local` (AC-2);
   - plan: a rebuild exclusion for this slot forces its title and avoids its image ids (R-9), else `funnel` and `choose_answer`; `assign_screenshots`; hints; `source_url`;
   - fetch the chosen screenshots (`t_1080p` from `images.igdb.com` through the allow-listed client) into `CONTENT_WORK_DIR/raw/` (cached by image id), process into `CONTENT_WORK_DIR/out/<slot>/` (M1-22c), `measure` each file, check limits (AC-39);
   - stop here under `--dry-run`: print per slot the planned files, hints present, sizes, and the answer only with `--show-answers` (AC-45);
   - otherwise put every file under its SHA-256 (AC-41, AC-42), then in **one transaction**: upsert the answer's title by `igdb_id` through M1-21's mapping (skip and report a near-duplicate, R-20), insert the puzzle as `in_review` with `date NULL`, `build_slot`, `generator_version`, six clues (steps 1 to 5 `image`, 6 `video`, AC-29), hints, `source_url`, `source_image_ids`, and the media rows (one WebP per image clue; MP4 plus poster for the clip; AC-13b checked before commit), then delete the slot's rebuild exclusion (AC-46, AC-50, AC-52). A failure anywhere rolls back: no puzzle, no clue, no media row. Files already stored stay (non-goal: clean-up).
   - A slot that already has a puzzle is skipped (R-7). The run never touches a puzzle that has stored games (AC-86).
3. `scripts/build_puzzles.py --target <env> (--slots A-B | --next N | --rebuilds) [--dry-run] [--show-answers] [--confirm-target <env>]`, plus `--counts` from M1-22b. The guard prints the target first (AC-44). `.gitignore` gets `var/content-work/` and `var/content-media/` (AC-43).
4. Tests (`tests/test_builder.py`, a fake IGDB client over fixtures and generated images, `LocalMediaWriter` on `tmp_path`, the test salt):
   - **(a)** a real build of two slots writes two `in_review` drafts with six clues, measured media rows and files present; a second run of the same slots adds nothing (AC-46).
   - **(b)** a failure injected while writing the fifth clue's media row leaves no puzzle, clue or media row (AC-46); a `--dry-run` writes no row and no file in storage (AC-45).
   - **(c)** a guard table: target `staging` with an empty `IGDB_IMAGES_CLEARED_BY` is refused before any fetch; a missing salt is refused before any fetch; `CI=true` is refused; a fetch to a host off the allow list raises.
5. Docs: the build commands, the working folder, the gate, rebuilds.

Manual after G1: `--counts`, then `--dry-run --next 5`, then a real `--next 40` into the content database (R-11); every draft has six clues and the clip plays in a browser.

### PR M1-24a: the review page (AC-47 to AC-54, AC-86) — routes, code-review high + test-writer; wave C

1. `app/content/review/actions.py` (service functions; queries in `app/crud/puzzle.py` and `app/crud/exclusion.py`):
   - `approve(db, puzzle_id, now)`: only from `in_review` (else refused), sets `approved`, `approved_at = now`, date stays `NULL` (AC-49).
   - `reject(db, puzzle_id, reason)`: only from `in_review`, and only when the puzzle has no stored game (AC-86); inserts an `answer_exclusions` row with the reason, the slot and the union of the clues' `source_image_ids`, then deletes the puzzle (clues and media rows cascade) (AC-51 to AC-53).
2. `app/content/review/app.py`, a Starlette app (R-17):
   - `GET /`: the queue, drafts in review by slot, with a count.
   - `GET /drafts/{id}`: the draft as the player sees it: steps 1 to 6 at their real size in order, the clip `muted loop autoplay playsinline` with its poster, each hint with its label ("Critic score", "Platform", "Genre", "Release year", "Developer"), then the answer (name, year, franchise) and each clue's source link; the AC-48 checklist; one approve button and one reject form with the two reasons. One screen at 1280x800: steps as a grid of thumbnails at real aspect, click to view full size (AC-54).
   - `GET /files/{key}`: the file from local storage, the key checked with `is_media_key` (`app/media/signing.py`), content type from the media row, `nosniff`.
   - `POST /drafts/{id}/approve`, `POST /drafts/{id}/reject` (form field `reason`, only `rebuild` or `never`, else 422): check `Host`, `Origin` and the per-process token first; then redirect to the next draft (post, redirect, get).
   - Every text from IGDB goes through one escaping helper (`app/content/review/html.py`); `Content-Security-Policy: default-src 'self'; img-src 'self'; media-src 'self'`.
3. `scripts/review_puzzles.py [--port 8765]`: refuses unless `refusal_reason()` is `None` and `MEDIA_STORAGE` is `local` (AC-47); binds `127.0.0.1`; prints the URL.
4. Tests (`tests/test_review.py`, an httpx client over the review app; budget: one happy path per route):
   - **(a)** happy paths: the queue lists a draft; the draft page shows six clue elements, the answer and an escaped IGDB name (a fixture name with `<script>`); a file is served; approve moves it to `approved` with `approved_at`; reject "never" leaves an exclusion and no puzzle, clue or media row.
   - **(b)** one rules table at the service level: approve of an approved puzzle is refused; reject "rebuild" records the slot and the image ids; reject of a puzzle with a stored game is refused.
   - **(c)** one refusal table: a POST with a foreign `Origin`, a missing token, or a `Host` of `evil.example:8765` is 403 and changes nothing; the app refuses to start with `ENVIRONMENT=staging`.
5. Docs: how to review; the rebuild loop (`build_puzzles.py --rebuilds`).

Manual (G1, G3): the owner reviews 10 real drafts and times it (AC-54).

### PR M1-24b: readiness and scheduling (AC-55 to AC-60, AC-62, AC-86) — wave C

1. `app/games/modules/game_guesser.py` (R-14): `clue_layout_problem(clue) -> str | None` holds the AC-13b rule; `_media_layout` calls it and raises as before. No behaviour change in the view (the existing AC-13b table in `tests/test_games.py` still passes).
2. `app/content/readiness.py`: `puzzle_problems(puzzle, clues, *, file_exists) -> list[Problem]`, where `Problem` is a StrEnum: `missing_clue` (steps not exactly 1 to 6), `bad_media` (`clue_layout_problem`), `missing_file` (a key the writer cannot find), with the step number. `file_exists` is `MediaWriter.exists` (M1-22d). Used by scheduling (AC-58), the check (AC-74) and promote.
3. `app/content/schedule.py`:
   - `schedule(db, game, writer, *, today, until=None)`: first day = max(today + 1, `game.launch_date`) (AC-56); taken dates = every dated puzzle of the game and variant; approved puzzles in `approved_at`, id order; on each free date take the first one that is ready and keeps the series rule (no other scheduled answer with the same non-null normalized franchise within 14 days either side, AC-57); set `date` and `scheduled`; stop at the first date nothing fits, or at `until`, or when the pool is empty (R-16). Not ready ones stay `approved` and are reported with their problems (AC-58). Returns the scheduled dates and the buffer (AC-60).
   - `unschedule(db, game, puzzle_date, *, today)`: only `date > today` and no stored game (AC-59, AC-86); sets `approved`, `date NULL`.
   - Neither touches visibility (AC-62); nothing runs at 00:00.
4. `scripts/schedule_puzzles.py --target <env> [--until DATE] [--unschedule DATE] [--show-answers] [--confirm-target <env>]`: prints dates, answers only with the flag, and the buffer.
5. Tests (`tests/test_schedule.py`, factories plus a fake `file_exists`, injected `today`):
   - **(a)** one scheduling table: three approved puzzles fill tomorrow, +1, +2 in approval order; with the launch date in 10 days the first date is the launch date; a series pair puts the second 14 days later, and a third puzzle takes the day between (AC-55 to AC-57); a puzzle missing its step-6 file stays approved and is reported (AC-58); a series conflict with nothing else approved stops scheduling there (R-16).
   - **(b)** one unschedule table: tomorrow's puzzle goes back to approved with no date; today's and yesterday's are refused (AC-59).
6. Docs: scheduling commands and rules.

### PR M1-25: buffer and tomorrow check (AC-73 to AC-82) — wave D

1. `app/content/buffer_check.py`, read-only (it opens no write transaction and calls no writer method other than `exists`):
   - For every enabled game, its default variant (AC-73): `first = max(today + 1, launch_date)`. If `today < launch_date - 7`: status "not launched", no failure (AC-82). Else tomorrow's state = `ready` if a puzzle exists on `first`, is `scheduled`, on or after launch, and `puzzle_problems` is empty (AC-74); buffer = consecutive ready days from `first`, a gap ends it, counted up to 60 (AC-75).
   - Exit code: 2 if any game's first day is not ready (AC-76), else 1 if any buffer is under 7 (AC-77), else 0.
   - Output per game: slug, the date, what is wrong (`missing`, `wrong_status`, `missing_clue`, `bad_media`, `missing_file`) with step numbers, and the buffer in days. Never a title, a hint, an answer or a key (AC-79).
   - "Today" from `get_now()`, injectable (AC-81).
2. `scripts/check_puzzle_buffer.py`: no target guard (it writes nothing, AC-78) but prints the environment name; `ArgumentParser.error` overridden and every exception caught, so a usage error, a database or storage failure all exit **3** (AC-80; Findings). Imports nothing from `app/content/media.py`, `igdb.py` or `fetch.py`, so it runs with runtime dependencies only (R-4). Scheduling it daily by 22:00 UTC and sending the alert is M1-52.
3. Tests (`tests/test_buffer_check.py`, factories, a fake `file_exists`, injected clock):
   - **(a)** one code table with ids: 30 ready days gives 0; days 1 to 5 and 7 to 30 give buffer 5 and 1; tomorrow's step-6 file missing gives 2; tomorrow `approved` instead of `scheduled` gives 2; launch in 20 days gives 0 "not launched"; launch in 5 days with nothing scheduled gives 2; a database error gives 3 (AC-74 to AC-77, AC-80, AC-82).
   - **(b)** the clock edge: at 23:59:59 UTC tomorrow is the next day, at 00:00:00 it moves (AC-81).
   - **(c)** the output of every row of (a) contains none of the fixture answer's name, its hint values or any media key (AC-79).
4. Docs: the codes and what each means for M1-52 (2 pages, 1 goes to the digest, 3 is "unknown").

### PR M1-24c: promote approved puzzles, game settings (AC-2, AC-44, AC-56, AC-58, AC-61 enabler; R-10) — wave D

1. `scripts/manage_game.py --target <env> --slug game-guesser [--launch-date YYYY-MM-DD] [--enable|--disable]`: creates the game row if missing (`default_variant` `default`, kind `video_game`, disabled by default) or updates it; guard (R-13). This is how the owner sets the production launch date (G4, Q17).
2. `app/content/promote.py` and `scripts/promote_puzzles.py --source-database-url <url> --source-media-dir <dir> --target <env> [--confirm-target <env>]`:
   - Refused for a non-local target while `IGDB_IMAGES_CLEARED_BY` is empty (R-12, AC-2).
   - Reads the source's `approved` puzzles (read-only on the source). For each, in slot order: the answer's title must exist in the target by `igdb_id` (else report "run the title import on the target first"); the answer must not be an answer in the target already (AC-25); every file is checked with `measure` and put through the target's writer; then one transaction inserts the puzzle as `approved` (same slot, version, `approved_at`, clues, hints, sources, image ids, media rows). A slot already in the target is skipped, so a re-run is a no-op.
   - Never changes the source.
3. Tests (`tests/test_promote.py`, two schemas or two databases on the test server, two `tmp_path` writers): **(a)** one approved puzzle is copied whole, files present in the target; a second run adds nothing. **(b)** a refusal table: non-local target with the gate empty; answer title missing in the target; answer already used in the target.
4. Docs: the production flow end to end (import on target, build and review locally, promote, `manage_game` launch date, schedule on target, check).

## Hand-off to the frontend plan (`plans/04-phase-3-frontend.md`)

| Backend PR | Frontend PR | What the frontend needs |
|---|---|---|
| M1-22b | **FE-Q3**, same pass | `hint.kind` `critic_score`, label "Critic score" / "Оценка критиков" (`specs/04-…:223`). `metacritic_score` is no longer produced; its label may go. Dev data uses the new kind after the seed is re-run. |
| M1-22b, M1-22d | **M1-23** (can start now) | `source_url` is `https://www.igdb.com/games/<slug>` for every step of real puzzles; the dev seed sends `https://example.com/seed/source` on every step (so "Images via IGDB" does not show in dev unless a test fixture uses igdb.com). It is `null` until the game ends (SPEC-02 AC-26). |
| none | none | **No Orval regeneration in Phase 3.** No backend PR changes `openapi/openapi.json` (no route, no response schema; the review page is a separate app). If any PR's `export_openapi.py --check` shows a diff, that PR has become a boundary change: stop, and after its merge regenerate with `npm run api:generate` in `my-list-fe` in a G PR; never hand-patch `src/api/generated/`. |
| M1-46 (Phase 4) | footer | The fixed attribution line "Game data and images: IGDB.com" / "Данные об играх и изображения: IGDB.com", linked to igdb.com, must be live before any IGDB content reaches production (AC-71); the legal page names IGDB (AC-72). Not built in Phase 3. |

## Skills for implementer

The backend's project skill is `my-list-be/.claude/skills/fastapi-service-patterns/SKILL.md`; when the implementer runs from the platform folder it may not be listed, so read the file directly. No skill covers IGDB, Pillow, PyAV, Starlette apps, Alembic or uv: gaps filled with `docs` against the installed versions.

| Files | Load | Why |
|---|---|---|
| Every code change | `shvab:karpathy-guidelines` | Small, surgical diffs; state assumptions |
| `app/models/**`, `app/alembic/**`, `app/crud/**`, `app/games/**` | `fastapi-service-patterns`, `docs` | Layering, test budget, style; Alembic 1.19 autogenerate with `ARRAY` and named CHECKs; SQLAlchemy 2.0 nullable `Mapped` |
| `app/content/igdb.py`, `fetch.py`, `settings.py` | `fastapi-service-patterns` (style, no blocking in async), `docs` | IGDB API v4 (Apicalypse syntax, `game_type`, paging, limits), Twitch client-credentials flow, httpx `MockTransport` and event hooks, pydantic-settings `SecretStr` |
| `app/content/media.py` | `docs` | Pillow WebP options and metadata, PyAV encoding (H.264, `yuv420p`, `movflags=+faststart`, no audio) at the installed versions; imageio-ffmpeg if the spike fails. **Gap:** no media skill |
| `app/content/candidates.py`, `seed.py`, `hints.py`, `titles_import.py`, `builder.py`, `schedule.py`, `readiness.py`, `buffer_check.py`, `promote.py` | `fastapi-service-patterns`, `shvab:karpathy-guidelines` | Pure functions with data in and data out; queries stay in `app/crud/` |
| `app/content/review/**` | `docs`, `fastapi-service-patterns` | Starlette routing, forms and responses at the installed version; OWASP CSRF and DNS-rebinding checks. **Gap:** no skill for server-rendered HTML; escape every value |
| `app/media/writer.py` | `docs` | boto3 `put_object`/`head_object`, Hetzner Object Storage |
| `pyproject.toml`, `uv.lock` | `docs` | uv dependency groups and `default-groups` at 0.13.6 |
| `tests/**` | `fastapi-service-patterns` ("Tests") | Fixtures, naming, the budget |
| `scripts/*.py` | `shvab:karpathy-guidelines` | **Gap:** no script skill; follow `seed_dev.py`'s shape |
| `CLAUDE.md`, `CONTRACTS.md`, `.env.example` comments | `shvab:no-ai-slop` | The owner wants plain, short sentences |
| Review passes | `code-review` (high) | Execution mode |

Frontend skills (`shvab:react-*`, `shvab:zod`, `shvab:react-testing-library`) do not apply to this plan.

## Verification

### Local setup (never touches port 5433)

- Prefix commands with `PATH="$HOME/.local/bin:$PATH"`.
- `docker start dgc-dev-pg dgc-dev-redis` (Postgres 5544, Redis 6390); recreate them with `plans/01-phase-0-backend.md:182-185` if gone.
- `<4 values>` means, at the front of every `pytest` and `alembic` command (export them; zsh does not word-split):
  - `DATABASE_URL=postgresql+asyncpg://postgres:postgres@localhost:5544/daily_game_challenge`
  - `TEST_DATABASE_URL=postgresql+asyncpg://postgres:postgres@localhost:5544/daily_game_challenge_test` (in a wave: `..._test_<prefix>`)
  - `REDIS_URL=redis://localhost:6390/0`
  - `TEST_REDIS_URL=redis://localhost:6390/1`
- Do not edit `.env`. Stop the containers at the end.
- **Before any `alembic downgrade base`**, print `select current_database()` through the same `DATABASE_URL` and confirm it is the throwaway database. Never route it through a helper that resets `DATABASE_URL` (Phase 1: a helper did, and `downgrade base` emptied the shared dev database).
- No test touches the network: IGDB is a `MockTransport` and fixtures, storage is `tmp_path`.

### Per PR (run in `my-list-be/`)

| Check | Command | Pass |
|---|---|---|
| Lockfile | `uv lock --check` | exit 0 |
| Lint, format | `uv run ruff check .` and `uv run ruff format --check .` | clean |
| Snapshot | `uv run python scripts/export_openapi.py --check` | exit 0 and **no diff** (Hand-off) |
| Scoped tests | `<4 values> uv run pytest -q <files below>` | all pass |
| Full suite | `<4 values> uv run pytest -q` | only for M1-22a (the date type and the CHECK touch shared code) and M1-24b (the AC-13b refactor feeds every view); elsewhere CI's run is the third pass |
| Migration (M1-22a only) | `docker exec dgc-dev-pg createdb -U postgres daily_game_challenge` (ignore "exists"); `<4 values> uv run alembic upgrade head`; `uv run alembic heads` (one); `alembic check`; `downgrade -1`; `upgrade head`. **Then from an empty throwaway database**, as CI does: create it, point `DATABASE_URL` at it, print `current_database()`, `upgrade head`, `alembic check`, `downgrade base`, `upgrade head`, drop it. Compare the CHECK and `ARRAY` definitions of a migrated database with a `create_all` one (`pg_get_constraintdef`) | one head, no diff, both databases |
| Runtime-only import (M1-25) | `uv run --no-dev --no-group content python -c "import scripts.check_puzzle_buffer"` (or the equivalent the implementer finds with `docs`) | no ImportError: the check needs no content dependency |

| PR | Scoped tests | PR-specific pass |
|---|---|---|
| M1-22a | `tests/test_game_schema.py tests/test_visibility.py tests/test_games.py` | Constraint table; the downgrade refuses with a NULL date in the dev DB and runs clean on an empty DB |
| M1-20 | `tests/test_igdb_client.py` | Retry bounded; foreign host refused before sending; no secret in any captured log (`caplog`) |
| M1-21 | `tests/test_titles_import.py tests/test_title_search.py` | Second run changes nothing; AC-18 refusal counted |
| M1-22c | `tests/test_content_media.py` | Limits table; clip without audio; spike result in the PR text |
| M1-22b | `tests/test_content_seed.py tests/test_candidates.py tests/test_hints.py tests/test_games.py` | Funnel adds up; 84.5 gives "85"; seed differs with another salt; `git diff` of the platform repo shows only the `CONTRACTS.md` paragraph and the MB definition line |
| M1-22d | `tests/test_builder.py` | Atomic write; second run adds nothing; dry run writes nothing; gates refuse before any fetch |
| M1-24a | `tests/test_review.py` | Foreign Origin, missing token, foreign Host refused |
| M1-24b | `tests/test_schedule.py tests/test_games.py` | Series rule; today locked; the AC-13b view table unchanged |
| M1-25 | `tests/test_buffer_check.py` | Every code row by id; no answer text in output |
| M1-24c | `tests/test_promote.py` | Second run adds nothing; gate refuses |

CI must be green on all four jobs for each PR: lint, test, migrations (only M1-22a changes it), openapi (no diff).

### Manual acceptance (SPEC-04 "Definition of done", after the PR and gate named)

| DoD item | After | Check |
|---|---|---|
| 1 | M1-20, G1 | `igdb_list.py --limit 5` prints five games with every field or "missing" |
| 2 | M1-21, G1 | Import twice, the second all unchanged; "zlda" finds Zelda games with years; series names clean; `bench_title_search.py --existing` p95 under 150 ms |
| 3 | M1-22d, G1 | `--dry-run --next 5` writes nothing and prints no answers; `--next 40` writes 40 drafts in review; re-running the same slots adds nothing |
| 4 | M1-24a, G1, G3 | The page shows six clues, the clip, hints, answer and sources; approve, reject "rebuild" (then `--rebuilds` gives other screenshots) and reject "never" behave as AC-49 to AC-52 |
| 5 | M1-24b (local); M1-24c with G2, G4, G5 (production) | Scheduling fills from the first schedulable day with no series within 14 days; 30 or more scheduled, in production before launch (AC-61) |
| 6 | M1-24b and frontend M1-23 | Playing a scheduled real puzzle to the end shows Sources with six rows linking to igdb.com |
| 7 | M1-25 | The check exits 0 with 30 days, 1 with 5, 2 after deleting tomorrow's step-6 file from `var/content-media`, 3 with the database stopped, and prints no answers |

## Risks

- **PyAV has no H.264 encoder in its wheel** (R-5). Mitigation: the spike decides in 5 minutes; the fallback is `imageio-ffmpeg`. If both fail, stop: the alternative is system ffmpeg in CI (`apt-get`) and a Docker wrapper on the workstation, which changes `ci.yml` and needs the owner.
- **IGDB field names drift** (`category` became `game_type`; `collection` became `collections`). Fixtures are hand-made from the docs, so the first real run (G1) can disagree. Mitigation: AC-8 counts skips by reason, so a shape change shows as a large skip count, not a crash; compare one real record with the fixtures right after G1.
- **Clip quality.** A pan over stills may be too weak or too easy a clue (SPEC-04 Q2 accepted that). Mitigation: start values as named constants; the owner tunes after the first 10 drafts; the reviewer rejects with "rebuild".
- **Search speed with the real list** (Phase 1 risk: "the" took about 100 ms on synthetic data). Re-measured in M1-21 with `--existing`; fallbacks are the owner's.
- **The seed wipes content in a shared database** (`seed_dev.py:167`). Mitigation: R-11, a separate content database; the M1-21 docs say so.
- **Answer leaks through output.** Scripts print answers only with `--show-answers`; the check never prints them; the review page binds `127.0.0.1`. The salt is never printed (AC-83). Code review watches every `print` and log line in M1-20, M1-22b and M1-22d.
- **A wrong target.** The guard needs the `ENVIRONMENT` variable itself, the name typed or confirmed, and refuses in CI. Promote refuses a non-local target while the IGDB gate is closed.
- **Shared scratchpad and databases in waves** (Phase 1 wave 4). Mitigation: prefixes, separate test databases, and the `current_database()` print.
- **uv version.** Local 0.12.5, CI 0.13.6: lock with `uvx uv@0.13.6 lock` in M1-20 and M1-22c; check that only the intended packages were added.
- **Storage keys are not unique per clue** (`app/models/puzzle.py`, `key` not unique). A rejected draft's files stay in storage and may be reused by a later draft with the same bytes. Harmless; clean-up is a non-goal.

## Rollback

- Each PR is one squash commit; roll back with a revert PR, newest first.
- M1-22a: revert after `alembic downgrade -1`, which refuses while any puzzle has no date. In `local`, delete the content database or set dates by hand first; production has no Phase 3 data until promote runs.
- M1-22b: the platform commit (`CONTRACTS.md`) is reverted with it, and FE-Q3 may stay (an unused label is harmless).
- Scripts write data, not code paths: a reverted builder leaves its drafts; delete them with the review page's reject, or drop the content database.
- Files in storage are never deleted by a revert; they are private and unreferenced.

## Open points

All answered by the owner on 2026-11-12 (`SPEC.md` decision 69): every default below is accepted as written. In addition: the encoding spike tries PyAV, then `imageio-ffmpeg`, and if both fail the implementer stops and asks before changing CI; real content lives in a dedicated local content database, never the dev seed database.

1. **Promote step (R-10), M1-24c.** The spec has no path for a reviewed puzzle to reach production while review is local-only. Default: build and review in `local`, promote approved puzzles to the target. The alternative is to let the review page run against a non-local database from the workstation, which reverses AC-47's "refuses to start in any other" and puts unreviewed drafts and IGDB images in production before Q1 is cleared.
2. **AC-50 versus AC-51** (Findings). Default: a rejected draft is always deleted (AC-51); `draft` is not written by the tools; "rebuild" works through the exclusion row (R-9).
3. **"Number of ratings"** for AC-10 and AC-21. Default: IGDB `total_rating_count`, a setting; the owner measures with `--counts` (AC-24) before fixing the thresholds.
4. **Where the IGDB gate lives** (R-12). Default: the setting `IGDB_IMAGES_CLEARED_BY`, naming the `SPEC.md` decision. The alternative, a code constant, needs a PR to open the gate.
5. **Step-1 crop and clip parameters** (M1-22c). Default: crop a third of the width, 20 px blocks, 960x540; clip 12 s, 24 fps, 2 or 3 shots, 1 s fades, no WebM. Tuned by the owner after the first drafts.
6. **No WebM in Milestone 1.** Default: MP4 and poster only (WebM is optional, SPEC-02 Q20); saves encode time and storage.
7. **Scheduling stops at the first date nothing fits** (R-16) rather than leaving a hole. The owner then approves more puzzles of other series.
8. **Conservative AC-18 guard** (R-15). Default: refuse any normalized-name, franchise or kind change of a referenced title.
9. **A dedicated local content database** (R-11). Default: recommended in the docs, not enforced.
10. **The `answer_exclusions` table name** and the column names of M1-22a. Default as written; rename before M1-22a merges if wanted.

## Traceability

| AC | Part | Plan step | Check |
|---|---|---|---|
| AC-1 | Owner asks IGDB; decision in `SPEC.md` | Gate G2 | owner |
| AC-2 | IGDB image gate | R-12, M1-22d.2, M1-24c.2 | `test_builder.py` (c); `test_promote.py` (b) |
| AC-3 | Credentials from the environment, never printed | M1-20.2 | `test_igdb_client.py`; `caplog` |
| AC-4 | Token renewal once | M1-20.4 | `test_igdb_client.py` (a) |
| AC-5 | 4 per second, 8 open, bounded retries | M1-20.4 | `test_igdb_client.py` (a), (c) |
| AC-6 | Paging at 500 | M1-20.4 | `test_igdb_client.py` (a) |
| AC-7 | Fields per game | M1-20.4 | `test_igdb_client.py` (b) |
| AC-8 | Validation, skip and count | M1-20.4 | `test_igdb_client.py` (b) |
| AC-9 | Five games | M1-20.5 | manual DoD 1 (G1) |
| AC-10, AC-11 | Search list scope | M1-21.3, R-20 | `test_titles_import.py` (a); `test_candidates.py` subset |
| AC-12 | Franchise rule | M1-21.3 | `test_titles_import.py` (a) |
| AC-13 | Year | M1-21.3 | `test_titles_import.py` (a) |
| AC-14 | Near-duplicates | M1-21.3 | `test_titles_import.py` (b) |
| AC-15 | `igdb_id` | M1-22a.1, M1-21.3 | `test_titles_import.py` (b) |
| AC-16 | Idempotent | M1-21.3 | `test_titles_import.py` (b); manual DoD 2 |
| AC-17 | Never delete | M1-21.3 | `test_titles_import.py` (b) |
| AC-18 | Replay guard | R-15, M1-21.2, .3 | `test_titles_import.py` (b) |
| AC-19 | Counts | M1-21.3, .4 | review |
| AC-20 | Search latency on the real list | M1-21.5 | manual DoD 2 (G1) |
| AC-21, AC-22 | Filters as settings | M1-22b.1, .3 | `test_candidates.py` |
| AC-23 | "Never" excluded | M1-22b.3 | `test_candidates.py` |
| AC-24 | Funnel counts | M1-22b.3, .6 | `test_candidates.py`; manual (G1) |
| AC-25 | No repeated answer | M1-22b.3, R-7, M1-24c.2 | `test_candidates.py`; `test_promote.py` (b) |
| AC-26 to AC-28 | Seed and salt | R-8, M1-22b.2 | `test_content_seed.py` |
| AC-29 | Six clues, 5 images and a video | M1-22d.2 | `test_builder.py` (a) |
| AC-30, AC-31 | Hints, `critic_score` | M1-22b.4, .7 | `test_hints.py`; `CONTRACTS.md`; FE-Q3 |
| AC-32 | Hints stored at build | M1-22d.2 | `test_builder.py` (a) |
| AC-33 | `source_url`; image ids kept | R-18, M1-22a.1, M1-22b.4, M1-22d.2 | `test_builder.py` (a); `CONTRACTS.md` |
| AC-34 | Step-1 crop from an unused screenshot | M1-22b.3, M1-22c.2 | `test_candidates.py`; `test_content_media.py` (a) |
| AC-35 | WebP limits, no metadata | M1-22c.2 | `test_content_media.py` (a) |
| AC-36 to AC-38 | Clip from unused screenshots, no outside video | M1-22b.3, M1-22c.2, AC-85 allow list | `test_content_media.py` (b); allow-list row |
| AC-39 | Measured values, refuse over limits | M1-22c.2, M1-22d.2 | `test_content_media.py` (a), (b) |
| AC-40 | Poster is a frame | M1-22c.2 | `test_content_media.py` (b) |
| AC-41, AC-42 | Content-hash keys, private storage | M1-22d.1 | `test_builder.py` (a) |
| AC-43 | Nothing in Git; fixtures ours | M1-20.6, M1-22d.3 | review of `git status`; `.gitignore` |
| AC-44 | Named target, confirmation | R-13, M1-21.1 | `test_builder.py` (c) |
| AC-45 | Dry run | M1-22d.2 | `test_builder.py` (b) |
| AC-46 | Atomic draft; slot; optional date | R-6, R-7, M1-22a.1, M1-22d.2 | `test_game_schema.py`; `test_builder.py` (a), (b) |
| AC-47, AC-48 | Local-only page, player view, checklist | R-17, M1-24a.2, .3 | `test_review.py` (a), (c) |
| AC-49 | Approve | M1-24a.1 | `test_review.py` (a), (b) |
| AC-50 | Straight to `in_review` | M1-22d.2; Open point 2 | `test_builder.py` (a) |
| AC-51 to AC-53 | Reject, exclusions, nothing reachable | R-9, M1-24a.1 | `test_review.py` (a), (b) |
| AC-54 | Ten drafts in ten minutes | M1-24a.2 | manual (G3) |
| AC-55 to AC-58 | Scheduling rules | R-16, M1-24b.3 | `test_schedule.py` (a) |
| AC-59 | Unschedule, today locked | M1-24b.3 | `test_schedule.py` (b) |
| AC-60 | Printed dates and buffer | M1-24b.3, .4 | review |
| AC-61 | 30 scheduled from launch | M1-24b, M1-24c | manual DoD 5 (G2, G4, G5) |
| AC-62 | Visibility unchanged | M1-24b.3 | no change to `visible_puzzle_condition`; review |
| AC-63 to AC-70 | Frontend | Hand-off | `plans/04-phase-3-frontend.md` |
| AC-71, AC-72 | M1-46 | Hand-off | M1-46 |
| AC-73 to AC-82 | Check | M1-25 | `test_buffer_check.py`; manual DoD 7 |
| AC-83 | No secrets or answers printed | R-13, M1-20.2, M1-22d.2, M1-25.1 | `caplog`; `test_buffer_check.py` (c); review |
| AC-84 | Refuse in CI | R-13 | `test_builder.py` (c) |
| AC-85 | Allow list | M1-20.3 | `test_igdb_client.py` (a) |
| AC-86 | Never edit a puzzle with stored games | M1-22d.2, M1-24a.1, M1-24b.3 | `test_review.py` (b); `test_schedule.py` (b) |
