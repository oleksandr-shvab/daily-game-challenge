# Spec: Phase 1, backend core for games   |   Spec ID: SPEC-02   |   Status: agreed with the owner's answers (2026-11-02)

Covers Milestone 1, Phase 1, tasks M1-10 to M1-18 (`MILESTONE-1.md` section 4), plus M1-41 (the CSRF Origin check), which the owner moved from Phase 4 into Phase 1 (Q13). It is also the M1-09 deliverable: the backend side of the game module contract and the puzzle model.
It defines the API seam that the frontend's Phase 2 consumes and it changes `CONTRACTS.md`, so it lives in the root `specs/` folder next to SPEC-01.
Main input: the Phase 1 research report (2026-11-02), checked against `SPEC.md` (working copy, draft 22), `MILESTONE-1.md`, `ARCHITECTURE.md`, `CONTRACTS.md` and SPEC-01. Written 2026-11-02; open questions answered the same day.

## In short

1. The backend learns about games, puzzles and titles. A puzzle is keyed `(game, variant, date)` and becomes visible at 00:00 UTC on its date, with no job.
2. A player guesses a title from a fuzzy search list. The server checks every guess, sends only the clues already earned, and sends the answer only when the game ends.
3. Guests stay stateless: the browser resends its earlier guesses and the server replays them. Accounts store progress on the server, and that copy wins.
4. Accounts get stats and a streak with the 3-day grace. Guests compute the same numbers in the browser from shared test vectors in this spec.
5. One idempotent merge endpoint moves a guest's local results into the account on login.
6. An archive list of past days and a clock endpoint for the countdown. Clue media sits behind short-lived signed links: images for steps 1 to 5, and a short muted looping video for step 6 (Q4).
7. Every state-changing request, the existing auth routes included, must come from an allowed origin (Q13, M1-41 moved into Phase 1).
8. No roles. Phase 1 keeps two cheap hooks for them: one visibility function and an `is_test` flag on progress (Q12).

## Owner's answers (2026-11-02)

The owner answered all 17 questions, then Q18 to Q20, which came out of the Q4 and Q13 answers. "Accepted" means the recommended default was chosen. Two answers differ from the default (**Q4**, **Q13**), and the acceptance criteria below follow the answers.

| # | Question | Answer | Criteria affected |
|---|---|---|---|
| Q1 | A daily play starts before 00:00 UTC and ends after it: daily or archive? | Accepted: daily if the first guess reaches the server on the puzzle's UTC date; stored once, never changed | AC-36, AC-40, AC-49, AC-52 (S18, S19) |
| Q2 | Guest merge: what does the server trust? | Accepted: replay the guesses, trust the "played as daily" flag; merged rows marked `origin = merge`; the account's row wins; at most 500 entries per request | AC-55 to AC-62 |
| Q3 | Grace example: played on day 1 and day 5. Streak 2? | Accepted: yes, 2. Day 1 and day 6 gives 1. Today is not missed until it is over | AC-49 to AC-53 |
| **Q4** | Step 6: image or video? | **A video in Milestone 1** (not the default). A muted, looping, autoplaying clip of about 12 seconds that plays inline like a GIF. H.264 MP4 is required; a WebM copy is optional. Media type `video` for step 6, `image` for steps 1 to 5 | AC-13, AC-13b, AC-25, AC-26, AC-70, AC-70b, AC-72, AC-72b, AC-72c, AC-74b, AC-77, AC-82 |
| Q5 | Status flow and puzzle routes | Accepted: `draft`, `in_review`, `approved`, `scheduled` (no `published`); visibility in one function; `GET .../puzzles/{date}` with a `/today` alias; optional `?variant=` | AC-9 to AC-12, AC-14 to AC-17 |
| Q6 | How does a guest get earned clues back after a reload? | Accepted: `POST .../puzzles/{date}/resume` with `{previous}`, read-only | AC-38, AC-39 |
| Q7 | Caching and media links in Phase 1 | Accepted: every puzzle response `private, no-store`; every step signed, step 1 included; public step-1 cache waits for M1-40 and M1-51 | AC-70, AC-72, AC-77 |
| Q8 | Keeping guest (browser) and account (server) stats in step | Accepted: one rule set, two implementations, one shared table of test vectors | AC-47, AC-52, AC-54 |
| Q9 | When is a guess correct; when does the franchise flag show? | Accepted: same title or same normalized name; franchise flag on the same normalized franchise; a missing franchise never matches | AC-27, AC-28 |
| Q10 | A title guessed twice | Accepted: 422 `duplicate_guess`, no guess used | AC-31 |
| Q11 | Expired session cookie on game routes | Accepted: treated as a guest, `signed_in: false`, never 401 (stats and merge still need login) | AC-25, AC-42 |
| Q12 | Roles hooks kept in Phase 1 | Accepted: the single visibility function and `is_test` (default false, never set) | AC-12, AC-43, AC-48 |
| **Q13** | CSRF: ship the Phase 1 POST routes before the Origin check? | **Bring M1-41 into Phase 1** (not the default; about 0.7 day; it leaves Phase 4). Every POST, PUT, PATCH and DELETE, the auth routes included, checks `Origin`, falling back to `Referer`, against the allowed origins; a mismatch or no value is 403 `csrf_origin_mismatch`. The JSON-only rule (415) stays | AC-75, AC-76, AC-78, AC-83 to AC-89 |
| Q14 | Clock: endpoint or `Date` header? | Accepted: `GET /v1/clock` | AC-67 to AC-69 |
| Q15 | Title table scope, and the year in the search list | Accepted: one `title` table with a `kind`; the search list shows the year. This changes M1-11's "title and franchise only": the year is shown too | AC-9, AC-18, AC-19 |
| Q16 | Puzzle number | Accepted: days since the game's launch date, plus 1; puzzles before the launch date are not visible | AC-9, AC-12, AC-63 |
| Q17 | Search details | Accepted: trimmed `q` under 2 characters gives an empty list; over 100 is 422; no padding to 200 | AC-20, AC-21 |
| Q18 | Add the custom CSRF header (`X-Requested-With`) that M1-41 and ARCHITECTURE 7 mention? | No. The Origin/Referer check, the JSON-only rule and `SameSite=Lax` are the full set | M1-41 group note |
| Q19 | The local API docs page sends the API's own origin. Allow it? | Yes, in `local` and `test` only: the API's own origin (the backend's base URL, for example `http://localhost:8000`) is allowed, so "Try it out" works. Production allows only `FRONTEND_URL`'s origin | AC-85, AC-86 |
| Q20 | A still frame for the step-6 clip, shown before it plays or when autoplay is blocked? | Yes. The builder stores one WebP still per clip; the step-6 media carries a signed `poster` link with the image-link lifetime | AC-13b, AC-25, AC-70, AC-71, AC-74b, AC-82 |

## Problem & Motivation

- Phase 0 gave the site a shell with a placeholder game screen. Nothing on the backend knows about games yet.
- The game guesser needs a server that holds the answer, checks guesses and hands out clues one step at a time. The reference ships its answers and all six clue files to the browser, so its reveal is only cosmetic (SPEC section 4). We must not repeat that (Milestone definition of done, item 6).
- Guests and accounts must play the same game. Guests keep no state on the server (decision 16). Accounts keep progress, stats and a streak across devices (decisions 3, 15, 51).
- Phase 1 adds the first state-changing routes besides auth (guesses, merge). The owner wants the CSRF Origin check in place before they exist, not after (Q13).
- Phase 2 (the game in the browser) can start only when this seam is fixed: routes, payloads, error codes and cache rules.
- Several source documents disagreed in small ways (status flow, routes, step 6, guest merge, CSRF timing). The owner's answers above settle them.

## Goals / Non-goals

**Goals**
- A game, puzzle, clue, title and progress model with the unique keys and checks from ARCHITECTURE 7.
- Read routes for the game list, a puzzle by date and today's puzzle; a fuzzy title search; a guess route; a guest resume route.
- Server-checked guesses: win, lose, skip, franchise flag; the answer only at the end.
- Stateless guests and authoritative accounts giving the same result for the same guesses.
- Account stats and streak, with the 3-day grace and "finishing counts" rules; archive plays count for stats only.
- An idempotent guest merge; a paged archive list; a clock endpoint.
- Clue media behind short-lived signed links, issued only for earned steps: images for steps 1 to 5, a video clip for step 6, with byte-range support so video plays in every browser. Local disk in development, S3-compatible storage in production.
- The CSRF Origin check on every state-changing route (M1-41).
- `CONTRACTS.md`, the OpenAPI snapshot and the frontend client updated in the same pass.

**Non-goals**
- Any frontend screen (Phase 2). This spec only fixes what the frontend will consume.
- Puzzle content: the IGDB client, title import, puzzle builder (including video cutting and encoding), review queue and alerts (Phase 3, M1-20 to M1-25). This spec only fixes the limits the builder must check (AC-74b).
- Roles, admin preview and reset (SPEC 3.13, not decided). Only the two hooks of Q12.
- Leaderboards, community stats, share text, rank.
- Rate limits (M1-42), audit log and account export or deletion (M1-44).
- Other games and variants beyond the game guesser's single default variant.

## User stories

| ID | As a ... | I want ... | Covered by |
|---|---|---|---|
| US-1 | guest | to open today's puzzle and see only the first clue | AC-14, AC-15, AC-25, AC-70 |
| US-2 | player | to search the title list with typos and pick a game | AC-18 to AC-24 |
| US-3 | player | to guess or skip and get the next clue, the franchise flag, and the answer only at the end | AC-25 to AC-34 |
| US-4 | guest | to reload the page and keep my game, with no account | AC-37 to AC-40 |
| US-5 | signed-in player | my game saved on the server and the same on every device | AC-41, AC-44, AC-45 |
| US-6 | signed-in player | stats and a streak that survive up to 3 missed days | AC-46 to AC-53 |
| US-7 | guest who signs up | my local results and streak moved into my new account | AC-55 to AC-62 |
| US-8 | player | a list of past days with my state for each, and to play any of them | AC-63 to AC-66 |
| US-9 | player | a countdown to the next puzzle that does not trust my device clock | AC-67 to AC-69 |
| US-10 | owner | answers and later clues never sent before they are earned, and no future puzzle visible | AC-12, AC-17, AC-29, AC-70 to AC-74 |
| US-11 | frontend developer | one documented seam with generated types, and a nav that never breaks when the two sides disagree on the game list | AC-1 to AC-8, AC-78 to AC-81 |
| US-12 | developer | a local database with a playable game, without real puzzle data in Git | AC-82 |
| US-13 | player at step 6 | a short clip that plays by itself, silently and in a loop, on my phone and laptop | AC-13, AC-13b, AC-25, AC-70b, AC-72b, AC-74b |
| US-14 | signed-in player | no other site able to make my browser guess, merge or change my account | AC-83 to AC-89 |

## Acceptance criteria (EARS)

Each group names its source. "Today" is the current UTC date from the server clock (decision 10, ARCHITECTURE 10). "Visible" is defined in AC-12. "View" is the puzzle view of AC-25. "Account request" is a request with a valid session; anything else is a guest request. "Media" means a clue's image or video file; a "signed link" is a URL to it that expires.

### M1-09 Module contract and the seam (SPEC 3.3, decision 8, SPEC 6 "per-game feedback types", SPEC-01 edge case)

The shared site owns routing, visibility, progress storage, stats, the archive and the clock. A game module owns what a puzzle shows, what a guess is and how the game ends. This is the shape of the boundary, not how either side is built.

| Crosses the boundary | Direction | Meaning |
|---|---|---|
| `slug`, `variant`, `date` | site to module | Which puzzle; the site has already checked visibility |
| progress (guesses so far, status) | site to module | The state to build a view from or to add a guess to |
| guess | site to module | A title id, or a skip |
| view | module to site | What the player may see now, never the answer before the end |
| new progress, feedback | module to site | The state after the guess and what to tell the player |

- **AC-1** The system shall route every game request through shared routes under `/v1/games/{slug}/...` and pick the game module by slug.
- **AC-2** Each game module shall provide two operations: build the view of a puzzle for a progress state (`get_puzzle`), and apply a guess to a progress state and return the new state with feedback (`submit_guess`). The signatures are the planner's choice.
- **AC-3** The view shall carry a `type` field that names the game's view type (`game_guesser` for this game), so that later games extend a tagged union in the API description without breaking the game guesser's clients.
- **AC-4** A game module shall never put the answer, or a clue of a step not yet earned, into a view before the game ends.
- **AC-5** The API shall expose no internal puzzle or progress id. A puzzle is addressed by `(slug, variant, date)` only.
- **AC-6** Progress shall not be keyed by interface language (SPEC-01 AC-55b). The game guesser is English only (decision 32).
- **AC-7** WHEN the frontend's game registry and `GET /v1/games` disagree, the frontend shall show in the nav only the games known to both, and shall not crash. *(Frontend, M1-30.)*
- **AC-8** IF `GET /v1/games` fails, THEN the frontend shall keep showing the static registry's entries, and each game screen shall show its own error on failure. IF the default game is not in the backend's list, THEN `/` shall show the in-layout "not found" screen with "Unknown game" (SPEC-01 AC-43). *(Frontend, M1-30.)*

### M1-10 Game registry and puzzle model (M1-10; ARCHITECTURE 7 and 9; SPEC 3.3; Q4, Q5, Q12, Q16)

- **AC-9** The `game` table shall hold: `slug` (unique, with a CHECK for `^[a-z0-9]+(-[a-z0-9]+)*$`), `default_variant`, `title_kind` (Q15), `launch_date` (Q16) and `is_enabled`.
- **AC-10** The `puzzle` table shall hold: game, `variant`, `date`, `status`, the answer as a reference to a title, and timestamps. `(game, variant, date)` shall be unique. `status` shall have a CHECK for exactly `draft`, `in_review`, `approved`, `scheduled` (Q5).
- **AC-11** A title referenced by a puzzle answer or by a stored guess shall not be deletable while referenced.
- **AC-12** The system shall decide visibility in one place, used by every puzzle route (view, today, resume, guess, archive, media, merge): a puzzle is visible only WHILE it is `scheduled`, its date is today or earlier, its date is on or after the game's launch date, and its game is enabled (Q5, Q12, Q16).
- **AC-13** The `puzzle_clue` table shall hold one row per step: puzzle, `step` (CHECK 1 to 6), `media_type` (CHECK `image` or `video`), an optional hint (`hint_kind`, `hint_value`), and an optional `source_url` (M1-23). `(puzzle, step)` shall be unique. For the game guesser, steps 1 to 5 are `image` and step 6 is `video` (Q4). The hints are stored on the puzzle when it is built, not read from the title later, so a later title fix cannot change a scheduled puzzle.
- **AC-13b** Each clue shall have one or more stored media files, each with its key, content type, byte size, width and height, and for video the duration. A video clue shall have exactly one `video/mp4` file (H.264), at most one `video/webm` file, and exactly one poster: a still frame of the clip as `image/webp` (Q20). An image clue shall have exactly one image file and no poster.
- **AC-14** `GET /v1/games` shall return the enabled games, each with `slug`, `default_variant` and `launch_date`. Name, nav order and the default game stay in the frontend registry (SPEC-01 AC-49).
- **AC-15** `GET /v1/games/{slug}/puzzles/{date}` shall return the view (AC-25) of that visible puzzle for the caller. `GET /v1/games/{slug}/puzzles/today` shall return the same body as for today's date, and the body shall name the date it resolved to.
- **AC-16** The `variant` query parameter shall be optional and default to the game's default variant. IF it names a variant the game does not have, THEN the system shall answer 404 `variant_not_found`.
- **AC-17** IF the slug is unknown or the game is disabled, THEN the system shall answer 404 `game_not_found`. IF the puzzle does not exist or is not visible (draft, not scheduled, future date, before launch), THEN the system shall answer 404 `puzzle_not_found`, the same body in every case (ARCHITECTURE 5). IF the date is not a real `YYYY-MM-DD` day, THEN the system shall answer 422 `validation_error` with field `date`. *Verify: tomorrow's scheduled puzzle and a nonexistent date give identical 404 bodies apart from `request_id`.*
- **AC-17b** The database metadata shall have a constraint naming convention before the first new table, so every new constraint has a stable name, and the migration shall pass the CI migrations job (upgrade, single head, `alembic check`).

### M1-11 Title table and search (M1-11; SPEC 4 "search list"; research "Must not miss"; Q15, Q17)

- **AC-18** The `title` table shall hold `kind` (CHECK, `video_game` now), `name`, a normalized name, an optional `franchise`, and an optional `year` (Q15).
- **AC-19** `GET /v1/games/{slug}/titles?q=` shall return at most 200 titles of the game's title kind, each with `id`, `name`, `franchise` and `year` (Q15; this widens M1-11's "title and franchise only"). It shall never mark or hint which title is an answer.
- **AC-20** WHEN the trimmed `q` is shorter than 2 characters, the system shall return an empty list. IF `q` is longer than 100 characters, THEN the system shall answer 422 `validation_error` (Q17).
- **AC-21** The search shall be fuzzy on the name and the franchise, and shall rank exact matches of the normalized name first, then prefix matches, then by similarity, then by name. It shall return only matches above the fuzzy threshold, never padding to 200. *Verify: "zlda" returns "The Legend of Zelda: Breath of the Wild" (full title in the fixture); "half life" returns "Half-Life 2"; "mario" lists a title named exactly "Mario" before "Super Mario Bros."; 250 matching titles return 200.*
- **AC-22** The search shall treat `q` as plain text: `%`, `_` and backslashes match themselves and never act as wildcards.
- **AC-23** The trigram extension shall be enabled by the migration and shall exist in the test database before its tables are created. (The current test setup builds tables without migrations, so it would miss the extension.)
- **AC-24** The search shall stay within the non-functional latency target with 50,000 titles (see Non-functional).

### M1-12 Guess endpoint (M1-12; SPEC 4 "clue ladder"; decisions 9, 32; Q4, Q9, Q10)

The game guesser has 6 steps and 6 guesses. Step 1 is a pixelated crop; steps 2 to 5 are screenshots with the hints Metacritic score, platform, genre and year; step 6 is a muted looping clip of about 12 seconds with the developer as the hint (Q4).

- **AC-25** The view shall hold: `type`, `slug`, `variant`, `date`, `number`, `status` (`in_progress`, `won`, `lost`), `max_guesses` (6), `guesses_used`, `guesses_left`, the guess list (each: `title_id` and `name`, or a skip; and `result`: `correct`, `wrong`, `franchise` or `skipped`), the earned steps, `answer` (`null` until the end), `counts_for_streak` and `signed_in`. Each earned step holds `step`, `hint` (`kind` and `value`, or `null`) and `media`: `type` (`image` or `video`), `width`, `height`, `expires_at`, `sources`, a list of `{url, content_type}`, and `poster`: for a video `{url, content_type, expires_at}` of its still frame, for an image `null` (Q20). For a video the list has the WebM file first when there is one and the MP4 file last, so a browser picks the first it can play. For an image it has one entry.
- **AC-26** WHILE the game is in progress, the view shall contain exactly the steps 1 to `guesses_used + 1`. WHEN the game ends, the view shall contain all six steps with their `source_url`.
- **AC-27** `POST /v1/games/{slug}/puzzles/{date}/guesses` with body `{title_id, previous}` shall check the guess on the server. `title_id: null` is a skip. A guess is correct when its title is the answer title or has the same normalized name (Q9).
- **AC-28** WHEN a guess is wrong and its title and the answer have the same normalized franchise, the system shall return `result: franchise`. A missing franchise on either side shall never match. A skip shall never get the franchise flag.
- **AC-29** WHEN a guess is correct, the system shall set `status: won`. WHEN the sixth guess or skip is not correct, the system shall set `status: lost`. WHEN the status becomes `won` or `lost`, and only then, the view shall include `answer` with `title_id`, `name`, `franchise` and `year`. *Verify: walk a full lost game and a full won game; no response before the end contains the answer's title id or name.*
- **AC-30** The score shall be the number of guesses used to win, skips included (decision 9).
- **AC-31** IF the guessed title was already guessed in this game, THEN the system shall answer 422 `duplicate_guess` and use no guess (Q10).
- **AC-32** IF `title_id` is not a title of the game's kind, THEN the system shall answer 422 `title_not_found` and use no guess.
- **AC-33** IF the game is already won or lost, THEN the system shall answer 409 `puzzle_already_finished` and change nothing.
- **AC-34** The guess response shall be the new view (AC-25), so the client needs no second call.

### M1-13 Guest and account progress (M1-13; decision 16; SPEC 3.2, 6; ARCHITECTURE 7; Q1, Q6, Q11, Q12)

- **AC-35** The `progress` table shall hold: user (deleted with the user), puzzle, `status` (CHECK `in_progress`, `won`, `lost`), the ordered guess list with skips, `started_at`, `finished_at`, `counts_for_streak`, `is_test` (default false, Q12) and `origin` (CHECK `play`, `merge`). `(user, puzzle)` shall be unique, which is `(user, game, variant, date)` because a puzzle is unique on `(game, variant, date)`.
- **AC-36** WHEN an account's first guess on a puzzle is stored, the system shall set `counts_for_streak` to true if today (server clock, at that moment) equals the puzzle's date, else false, and shall never change it afterwards (Q1).
- **AC-37** WHEN a guest sends a guess, the system shall rebuild the state by replaying `previous` through the same check as AC-27 to AC-33, then apply the new guess, and shall store nothing.
- **AC-38** `POST /v1/games/{slug}/puzzles/{date}/resume` with body `{previous}` shall return the view after replaying `previous`, and shall change nothing (Q6). For an account request it shall return the stored state.
- **AC-39** IF `previous` has more than 5 entries on a guess (6 on a resume or in a merge entry, where it may hold a whole lost game), contains an unknown title, contains a duplicate, or has any entry after a correct guess, THEN the system shall answer 422 `invalid_guess_history`. IF `previous` already ends the game (its last entry is correct), THEN a guess shall get 409 `puzzle_already_finished` and a resume shall return the finished view.
- **AC-40** WHEN a guest sends its first guess (`previous` empty), the view shall carry `counts_for_streak` computed as in AC-36. On later guest requests the field shall be `null`; the browser keeps the first value.
- **AC-41** WHEN an account request arrives, the system shall use the stored progress and shall ignore `previous` completely. *Verify: an account with two stored guesses sends a forged `previous` of five skips; the stored state and the view are unchanged apart from the new guess.*
- **AC-42** IF the session cookie is missing, invalid or expired, THEN game routes other than stats and merge shall treat the request as a guest request and answer with `signed_in: false`, never 401 (Q11).
- **AC-43** The system shall create progress with `is_test` false in Phase 1. No route shall set or return it.
- **AC-44** The same guesses shall give the same view for a guest and for an account. *Verify: one table-driven test runs each sequence both ways and compares the views, apart from `signed_in`, `counts_for_streak` and the signed links.*
- **AC-45** WHILE two requests for the same account and puzzle run at once, the system shall apply them one after the other, so the stored guess list never loses or duplicates a guess.

### M1-14 Stats and streak (M1-14; decisions 14, 15, 26, 51; SPEC 3.1, 3.5; Q1, Q3, Q8)

- **AC-46** `GET /v1/games/{slug}/stats?variant=` shall return for the signed-in account: `played`, `wins`, `current_streak`, `max_streak` and `distribution` (wins by guesses used, keys 1 to 6, zeros included). A guest request shall get 401 `not_authenticated`. The win rate is computed by the client from `wins` and `played`.
- **AC-47** `played` shall count finished plays (won or lost), daily and archive alike. In-progress plays shall not count. Archive plays shall count toward `played`, `wins` and `distribution` (decision 14).
- **AC-48** Stats and streaks shall skip rows with `is_test` true.
- **AC-49** A day shall count for the streak only WHEN the play of that day's puzzle is finished (won or lost), has `counts_for_streak` true, and is of the default variant (decisions 15, 30, 51). The streak day is the puzzle's date, not the finish date.
- **AC-50** The streak shall follow this rule (Q3): walk the streak days in order; a gap of 1 to 3 missed days keeps the run without adding to it; a gap of 4 or more starts a new run at 1. `current_streak` is the last run's length WHILE the number of missed days since the last streak day, not counting today, is 3 or fewer, and 0 otherwise. `max_streak` is the longest run ever.
- **AC-51** For a variant other than the default, `current_streak` and `max_streak` shall be `null`.
- **AC-52** The streak shall match every row of this table, in the backend's tests and in the frontend's tests (Q8). Days are UTC day numbers; "daily finishes" are streak days as in AC-49.

| # | Daily finishes | Other plays | Today | Current | Max | Why |
|---|---|---|---|---|---|---|
| S1 | none | none | 1 | 0 | 0 | nothing played |
| S2 | 1 | | 1 | 1 | 1 | |
| S3 | 1 | | 2 | 1 | 1 | today not over, not missed |
| S4 | 1, 2, 3 | | 3 | 3 | 3 | |
| S5 | 1, 5 | | 5 | 2 | 2 | 3 missed days keep it (Q3) |
| S6 | 1, 6 | | 6 | 1 | 1 | 4 missed days reset it |
| S7 | 1 | | 5 | 1 | 1 | days 2 to 4 missed, day 5 still open |
| S8 | 1 | | 6 | 0 | 1 | days 2 to 5 missed |
| S9 | 1, 2, 4, 5 | | 5 | 4 | 4 | a missed day adds nothing |
| S10 | 1, 3, 5, 7 | | 7 | 4 | 4 | |
| S11 | 1, 2, 3, 8, 9 | | 9 | 2 | 3 | |
| S12 | 1, 2, 3, 4, 5, 10 | | 12 | 1 | 5 | day 11 missed only |
| S13 | 1, 2, 3 | | 7 | 3 | 3 | days 4 to 6 missed |
| S14 | 1, 2, 3 | | 8 | 0 | 3 | days 4 to 7 missed |
| S15 | 1, 3 | archive finish of day 2, played on day 3 | 3 | 2 | 2 | archive never fills a day |
| S16 | 1, 3 | day 2 started as daily, never finished | 3 | 2 | 2 | unfinished is not activity |
| S17 | 1 (lost), 2 (won), 3 (lost) | | 3 | 3 | 3 | losing counts (decision 51) |
| S18 | 1 | day 2 first guess on day 3 (Q1: archive), finished | 3 | 1 | 1 | started after midnight |
| S19 | 1, 2 (first guess on day 2 at 23:59, finished on day 3) | | 3 | 2 | 2 | started before midnight (Q1) |

- **AC-53** The system shall compute the streak when stats are read, from stored progress, with no stored streak counter.
- **AC-54** The stats counters shall match this table in both repos (one variant, guesses used for wins):

| # | Plays | played | wins | distribution |
|---|---|---|---|---|
| T1 | won in 1 (daily), won in 3 (daily), lost (daily), won in 6 (archive), one in progress | 4 | 3 | 1:1, 3:1, 6:1, others 0 |
| T2 | lost (archive), lost (archive) | 2 | 0 | all 0 |
| T3 | nothing | 0 | 0 | all 0 |

### M1-15 Guest merge (M1-15; SPEC 3.2, 6; decision 16; Q2)

- **AC-55** `POST /v1/games/{slug}/progress/merge` shall take `{entries: [{date, variant, guesses, played_as_daily}]}` for the signed-in account. A guest request shall get 401 `not_authenticated`.
- **AC-56** For each entry, the system shall replay `guesses` through the same check as a guess (AC-27 to AC-33) and store the resulting status. The client never sends an outcome, and none is trusted.
- **AC-57** WHEN an entry is stored, the system shall set `origin: merge` and `counts_for_streak` from `played_as_daily` (Q2).
- **AC-58** IF the account already has progress for that puzzle, THEN the system shall keep the account's row unchanged and skip the entry (Q2).
- **AC-59** IF an entry names a puzzle that is not visible, an unknown variant, or guesses that fail AC-39's rules, THEN the system shall skip that entry and report it, and shall still merge the others.
- **AC-60** The response shall report the counts of stored, already-present and rejected entries, and for each rejected entry its `date`, `variant` and a `code`.
- **AC-61** WHEN the same request is sent twice, the second shall change nothing. *Verify: replay the request; stored rows and stats are identical.*
- **AC-62** IF a request has more than 500 entries, THEN the system shall answer 422 `validation_error` (field `entries`, code `too_long`, `params.max` 500) and store nothing. The client sends larger histories in several requests, which is safe because of AC-61.

### M1-16 Archive (M1-16; decisions 7, 14, 20; SPEC 3.4; ARCHITECTURE 7; Q16)

- **AC-63** `GET /v1/games/{slug}/archive?variant=&before=&limit=` shall list visible puzzles dated strictly before `before` (default and maximum: today), newest first. Each item: `date`, `number` (days since the game's launch date, plus 1; Q16), and for an account request `state` (`not_played`, `in_progress`, `won`, `lost`) and `guesses_used`; for a guest request both are `null` and the browser fills them. The response carries `next_before` (the last item's date, or `null` at the end).
- **AC-64** `limit` shall default to 30 and accept 1 to 100; outside that range the system shall answer 422 `validation_error`. A `before` later than today shall be treated as today.
- **AC-65** The archive list shall never include today or a future date, and never an answer. Days with no visible puzzle shall be left out, not shown as empty rows.
- **AC-66** A past visible puzzle shall be played through the same view, resume and guess routes as today's. Its plays count toward stats only (AC-47, AC-49).

### M1-17 Clock (M1-17; decision 10; ARCHITECTURE 9, 10; Q14)

- **AC-67** `GET /v1/clock` shall return `now` (UTC timestamp), `today` (UTC date) and `next_reset` (the next 00:00 UTC), from the server clock, without touching the database.
- **AC-68** The clock response shall carry `Cache-Control: no-store`.
- **AC-69** The server clock shall be the only authority for "today" in visibility, streak flags and the archive. The client may use the offset from `now` only for display (ARCHITECTURE 10). *Verify: tests with an injected clock at 23:59:59 and 00:00:00 UTC; tomorrow's puzzle turns visible exactly at 00:00:00.*

### M1-18 Clue media (M1-18; Milestone DoD item 6; SPEC 3.13 caching notes; ARCHITECTURE 7, 9, 10; decision 62; Q4, Q7)

- **AC-70** The system shall give each earned step's media files as signed links, and shall give `expires_at` with them. Every step is signed, step 1 included (Q7). Image links and poster links shall expire after a configured time (default 600 seconds, allowed 60 to 3600).
- **AC-70b** Video links shall expire after their own configured time (default 3600 seconds, allowed 600 to 86400), because a browser keeps asking for parts of a looping clip for as long as it plays, and each request is checked when it starts.
- **AC-71** The system shall issue a link for a step only WHEN that step is earned and the puzzle is visible. *Verify: at step 1, no response contains a link or key for step 3, the step-6 video or its poster.*
- **AC-72** WHERE storage is the local folder (development and tests), the backend shall serve the signed links itself; WHERE storage is S3-compatible (production), the links shall point at the bucket. In both cases a link shall load from the frontend's page as an `<img>` source or a `<video>` source with no extra header or cookie, and shall be served with the stored content type (`image/webp`, `video/mp4`, `video/webm`) and `X-Content-Type-Options: nosniff`.
- **AC-72b** WHERE the backend serves a signed link itself, it shall support byte ranges on `GET` and `HEAD`: a full response carries `Accept-Ranges: bytes`; a request with one valid `Range` gets 206 with `Content-Range` and only those bytes; a range outside the file gets 416 with `Content-Range: bytes */<size>`. The signature and expiry shall be checked on every request, ranged or not. (Safari plays `<video>` only from servers that answer range requests.) *Verify: route tests for `bytes=0-1`, `bytes=100-`, `bytes=-500`, an unsatisfiable range, and an expired link with a `Range` header.*
- **AC-72c** Before production relies on S3-compatible storage, M1-18 shall show on a real Hetzner bucket that a presigned GET link answers a `Range` request with 206 and plays the step-6 clip in a browser. IF it does not, THEN production shall serve media through the backend's own signed route (AC-72b), as in development.
- **AC-73** IF a signed link is expired or its signature is wrong, THEN the request shall fail with 403 `invalid_media_link` and reveal nothing about the file. The client gets fresh links by asking for the view again (AC-15, AC-38).
- **AC-74** Media keys shall be random or content hashes, never built from the date, game, step or answer (ARCHITECTURE 10). The storage shall be private: no file is reachable without a valid signature.
- **AC-74b** The puzzle builder (M1-22) shall refuse to store a clue file that breaks these limits, and the stored values of AC-13b shall come from the file it checked. Video: content type `video/mp4` with H.264 (required) or `video/webm` (optional copy); no audio track; duration 8 to 15 seconds; at most 1280 by 720 pixels; at most 4 MB per file. Image and poster: `image/webp`, at most 1920 by 1080 pixels, at most 1 MB (Q20). These are starting values; M1-22 may change them, and this table is then updated.

### Cross-cutting: errors, caching, docs, dev data (CONTRACTS "Errors"; ARCHITECTURE 5, 7, 14; Q7, Q13)

- **AC-75** Every new error shall use the contract body (`code`, `params`, `request_id`, `errors`). New codes, all added to `CONTRACTS.md` and to both frontend catalogues: `game_not_found` (404), `variant_not_found` (404), `puzzle_not_found` (404), `title_not_found` (422), `duplicate_guess` (422), `invalid_guess_history` (422), `puzzle_already_finished` (409), `invalid_media_link` (403), `unsupported_media_type` (415), `csrf_origin_mismatch` (403). Reused: `validation_error` (422), `not_authenticated` (401), `not_found` (404).
- **AC-76** IF a POST, PUT or PATCH request on any API route carries a body whose `Content-Type` is not `application/json`, THEN the system shall answer 415 `unsupported_media_type` and change nothing (Q13). This covers the existing auth routes too.
- **AC-77** The system shall send these `Cache-Control` values (Q7):

| Response | Cache-Control |
|---|---|
| `GET /v1/games` | `public, max-age=300` |
| `GET .../titles` | `public, max-age=300` |
| Puzzle view, today, resume, guess, archive, stats, merge | `private, no-store` |
| Clock | `no-store` |
| Any error response, including every 404 for a future date and every 403 | `no-store` |
| An image or video served by the backend (local storage), full or partial | `private, max-age` no longer than the link's remaining lifetime |

- **AC-78** `CONTRACTS.md` shall gain a "Games" section in the same pass as the code: the routes, the view and its media shape, guest and account rules, merge, archive paging, clock, signed links with byte ranges, cache rules and the new error codes. Its "Auth" section shall replace the "No CSRF protection exists yet" note with the Origin rule of AC-83 to AC-87 and the JSON-only rule of AC-76.
- **AC-79** The OpenAPI snapshot shall be rewritten and the frontend client regenerated in the same pass. Operation ids follow `<tag>_<handler>`.
- **AC-80** The backend `CLAUDE.md` shall describe the game domain, the storage settings, the Origin check and how to seed a local game.
- **AC-81** The game routes shall answer for a guest with no cookie at all (no route except stats and merge requires login).
- **AC-82** A dev seed command shall create one enabled game (`game-guesser`), at least 10 titles (full names, some with franchises, one pair of near-duplicates), visible puzzles for today and the 3 previous days, one scheduled puzzle for tomorrow, one draft, generated placeholder images for steps 1 to 5 and a placeholder MP4 clip for step 6 with its poster, both made by us (no third-party footage). It shall refuse to run outside `local`. No real screenshot, clip or answer list is committed (decision 59).

### M1-41 CSRF Origin check, moved into Phase 1 (Q13; ARCHITECTURE 7 "CSRF" and "Headers and CORS"; CONTRACTS "Auth"; about 0.7 day, BE and FE)

`SameSite=Lax` stays as defense in depth (ARCHITECTURE 7). "Allowed origins" are the exact origins (scheme, host and port) listed in AC-86.

**Note (Q18):** the Origin/Referer check (AC-83 to AC-87), the JSON-only rule (AC-76) and `SameSite=Lax` are the full CSRF set. There is no custom request header such as `X-Requested-With`; do not add one.

- **AC-83** WHEN a request uses POST, PUT, PATCH or DELETE on any API route (the game routes, the existing auth routes such as login, register, logout, forgot, reset and update password, and every later route), the system shall check its origin before any other check: before the session, the body, the content type and the route's own rules.
- **AC-84** The request's origin shall be the `Origin` header. IF `Origin` is absent, THEN the system shall use the origin of the `Referer` header.
- **AC-85** IF neither header is present, the value is `null`, or the origin is not exactly one of the allowed origins, THEN the system shall answer 403 `csrf_origin_mismatch` and change nothing. *Verify: route tests per method with an allowed `Origin`; `https://evil.example`; no headers; `Referer` only (allowed and foreign); `Origin: null`; `http://localhost:5174` (port); `https://localhost:5173` (scheme); `http://localhost:5173.evil.example` (suffix); `http://localhost:8000` (allowed in `local` and `test`, refused when the environment is `production`).*
- **AC-86** The allowed origins shall be the origin of `FRONTEND_URL`, plus, in `local` and `test` only, the origins in `BACKEND_CORS_ORIGINS` and the API's own origin (the backend's base URL, for example `http://localhost:8000`), so the docs page's "Try it out" works (Q19). Staging and production allow only `FRONTEND_URL`'s origin. No wildcard and no suffix match. In production the site and the API share one origin (ARCHITECTURE 2), so it is the only allowed origin there; the existing startup checks already refuse localhost origins in staging and production.
- **AC-87** GET, HEAD and OPTIONS shall not be checked, and no route shall change state on them. The health endpoints stay unchecked (they are GET only).
- **AC-88** The existing auth tests and every new test that sends an unsafe request shall send an allowed `Origin`, so the suite proves the check does not break the normal flow. *Verify: the full suite passes with the check on, and a test without `Origin` on login gets 403.*
- **AC-89** The frontend shall show a translated text for `csrf_origin_mismatch` in English and Russian. It needs no other change: browsers send `Origin` on the POST requests the client makes. *(Frontend part of M1-41.)*

## Edge cases

| Case | Expected | AC |
|---|---|---|
| Backend lists a game the frontend has no screen for, or the reverse (SPEC-01 open edge case) | Nav shows only games known to both; never a crash; a direct URL to the missing game shows "Unknown game" | AC-7, AC-8, AC-17 |
| `GET /v1/games` fails | Nav falls back to the static registry; each screen handles its own error | AC-8 |
| No puzzle scheduled for today | `/today` gives 404 `puzzle_not_found`; the frontend shows "No puzzle for this date"; the M1-25 alert should have fired the day before | AC-17 |
| Future date, draft, approved-but-unscheduled, before launch date | Same 404 `puzzle_not_found`, `no-store`, for every route including media, merge and archive | AC-12, AC-17, AC-77 |
| View loaded at 23:59:59, first guess arrives at 00:00:01 | The guess goes to the explicit date; it is an archive play (Q1); the frontend shows the day-change message (M1-32) | AC-36, AC-40 |
| First guess at 23:59, last guess after 00:00 | Still a daily play (Q1) | AC-36, S19 |
| Guess after the game ended | 409 `puzzle_already_finished`, nothing changes | AC-33 |
| Same title guessed twice, or a double-click on Submit | 422 `duplicate_guess`, no guess used | AC-31 |
| Double-click on Skip | Two skips are used; the frontend disables the button while the request runs | AC-45 |
| Guest `previous` with 6 entries on a guess (7 on a resume), an unknown id, a duplicate, or an entry after a win | 422 `invalid_guess_history` | AC-39 |
| Guest forges `previous` to see a later clue | Works for the guest only; accepted risk (decision 16) | AC-37 |
| Account sends a forged `previous` | Ignored; stored state used | AC-41 |
| Two tabs of one account guess at once | Applied one after the other; no lost guess | AC-45 |
| Session expired while the frontend still shows the player signed in | Request runs as a guest; view says `signed_in: false`; the frontend switches to signed out | AC-42 |
| Guest signs in mid-game | The local in-progress play is merged; the account's row wins if it exists | AC-55, AC-58 |
| Merge sent twice, or in several chunks | No change on repeat; chunks are safe | AC-61, AC-62 |
| Merge entry for a future or hidden puzzle, or with an impossible guess list | That entry rejected and reported; others merged | AC-59, AC-60 |
| Answer title has no franchise, or the guessed one has none | No franchise flag | AC-28 |
| Near-duplicate title of the answer picked | Correct (Q9) | AC-27 |
| Search `q` empty, one letter, `%`, or 101 characters | Empty list, empty list, literal match, 422 | AC-20, AC-22 |
| Nonsense search | Few or no results, never padded (Q17) | AC-21 |
| Image link expired while the tab was open | 403 `invalid_media_link`; the frontend asks for the view or resume again | AC-73 |
| Video link expires while the clip is looping and the browser asks for another range | That range gets 403; the frontend asks for the view again and swaps the source (M1-30); the 3600-second default makes this rare | AC-70b, AC-72b, AC-73 |
| Safari or iOS opens the step-6 clip | Range requests get 206, so the clip plays | AC-72b |
| Browser cannot play WebM, or no WebM copy exists | It plays the MP4 source, which is always listed | AC-13b, AC-25 |
| Autoplay is blocked (for example iOS Low Power Mode) | The frontend shows the poster with a play control (M1-30) | AC-25 |
| `Range` header that is malformed or past the end of the file | 416 with `Content-Range: bytes */<size>` | AC-72b |
| A player shares a signed step-3 or step-6 link | Anyone can open it until it expires (a bearer link); the TTL keeps this short | AC-70, AC-70b |
| A scheduled puzzle has no Metacritic score | That step's `hint` is `null` | AC-25 |
| A scheduled puzzle misses a whole step, or step 6 has no MP4 | 500 `internal_error` with the request id in the log; the builder, review queue and alert (M1-22, M1-24, M1-25) must catch it before the date | AC-13, AC-13b, AC-74b |
| Archive `before` in the future, or a missing day in the past | Clamped to today; the missing day is left out | AC-64, AC-65 |
| Unknown `variant` | 404 `variant_not_found` | AC-16 |
| A title still referenced by a puzzle or guess is deleted by an import | Refused by the database | AC-11 |
| Account deleted | Its progress goes with it | AC-35 |
| Device clock wrong by hours | Countdown uses the server's `now`; "today" comes from the server | AC-67, AC-69 |
| Hetzner presigned links do not answer `Range` (not verified) | Production serves media through the backend's own signed route, as in development | AC-72c |
| A form on another site posts to `/v1/auth/logout` or a guess route | 403 `csrf_origin_mismatch`; nothing changes | AC-83, AC-85 |
| A developer opens the frontend at `127.0.0.1:5173` | Its origin is not allowed, so POSTs get 403; always use `localhost` (CONTRACTS "Auth") | AC-86 |
| curl or a script sends a POST without `Origin` | 403; it must send an allowed `Origin` | AC-85 |
| A browser or privacy extension strips `Referer` and the request has no `Origin` | 403; browsers send `Origin` on POST, so this should not happen for the site's own requests | AC-84, AC-85 |
| A cross-site POST also has a bad body or no session | 403 `csrf_origin_mismatch`, not 401 or 422, because the origin is checked first | AC-83 |

## Non-functional

- **Performance:** guess submit p95 under 300 ms at the load of the M1-51 test (ARCHITECTURE 9 SLO). Title search p95 under 150 ms on a local machine with 50,000 titles (an estimate to confirm in M1-11). The clock route touches no database (AC-67). A guest request replays at most 5 earlier guesses (AC-39), so its extra cost is bounded. The Origin check reads two headers and touches no database or Redis.
- **Media size:** a step-6 clip is at most 4 MB (AC-74b). Byte ranges let a browser start playing before the whole file arrives (AC-72b).
- **Security:** the answer and unearned clues never leave the server before the end (AC-4, AC-29, AC-71); visibility in one function (AC-12); identical 404s hide future puzzles (AC-17); user text is never built into SQL, and search wildcards are escaped (AC-22); every unsafe request must come from an allowed origin (AC-83 to AC-86) and carry JSON (AC-76); media is served with its stored content type and `nosniff` (AC-72). Rate limits stay in M1-42 and must land before public launch.
- **Privacy:** progress is personal data, deleted with the account (AC-35) and covered later by export (M1-44). Logs carry user ids, not emails, and no request bodies (ARCHITECTURE 9).
- **Contract stability:** the view is a tagged union from the start (AC-3), and clue media has a type and a list of sources (AC-13, AC-25), so later games and formats are additive changes.

## Inputs (provenance)

| Input | Tag |
|---|---|
| Games, puzzles, clues, titles | [new: Postgres tables; filled by the dev seed now, by the Phase 3 scripts later; no runtime cost] |
| Signed-in state | [existing: session cookie and Redis session, as for `/auth/me`] |
| Account progress | [new: `progress` table, one row per account and puzzle] |
| Guest progress | [existing: browser storage, sent as `previous` and merge entries; nothing stored on the server] |
| "Today", `now`, `next_reset` | [derived: server clock in UTC] |
| `counts_for_streak` | [derived: server clock at the first guess; for merge entries, the client's `played_as_daily` flag (Q2)] |
| Puzzle number | [derived: date and the game's launch date (Q16)] |
| Stats and streak | [derived: computed on read from `progress`] |
| Clue images (steps 1 to 5) | [new: local folder in development; S3-compatible object storage in production (decision 62), with an S3 client added only in M1-18; small storage cost] |
| Step-6 clips | [new: same storage; up to 4 MB per puzzle in MP4, plus an optional WebM copy, so up to about 3 GB a year for one game. Egress is up to 4 MB for each player who reaches step 6, the largest bandwidth item per puzzle; no estimate of player numbers yet] |
| Signing key for local media links | [new: a separate secret setting, not `SECRET_KEY`] |
| Allowed origins | [existing: `FRONTEND_URL` and `BACKEND_CORS_ORIGINS` settings] |
| `Origin` and `Referer` headers | [existing: sent by the browser on each request] |
| Trigram search | [new: the `pg_trgm` Postgres extension, shipped with `postgres:16-alpine`, no cost] |

**Where the requirements come from:** decisions 3, 7, 8, 9, 10, 14, 15, 16, 26, 30, 32, 51, 59, 62 (`SPEC.md` section 2); SPEC 3.1 to 3.5, 3.13 (hooks only), 4 (clue ladder, search list, step-6 video in the reference), 6 (feasibility table); `MILESTONE-1.md` M1-09 to M1-18, M1-41 and the definition of done; `ARCHITECTURE.md` sections 2, 5, 7, 9, 10, 14; `CONTRACTS.md` "API base", "Auth", "Errors", "API types"; SPEC-01 AC-43 to AC-56 and its open edge case; the Phase 1 research report; the owner's answers of 2026-11-02.

## Untrusted inputs

Everything below comes from the client and is data, never instructions. Each is checked at the route boundary; a bad value gives a defined error, never a crash or a 500.

| Input | Rule | Bad value gives |
|---|---|---|
| `Origin`, `Referer` on unsafe methods | Exact match of an allowed origin; checked first | 403 `csrf_origin_mismatch` |
| `Content-Type` on a request with a body | Must be `application/json` | 415 `unsupported_media_type` |
| `slug` path | Exact match of an enabled game | 404 `game_not_found` |
| `date` path | Real `YYYY-MM-DD` day; then visibility | 422 `validation_error`, or 404 `puzzle_not_found` |
| `variant` query | One of the game's variants | 404 `variant_not_found` |
| `q` query | Trimmed; 2 to 100 characters; wildcards escaped | empty list, or 422 |
| `title_id` | An existing title of the game's kind, or `null` | 422 `title_not_found` |
| `previous` | At most 5 entries on a guess, 6 on a resume or merge entry; known titles or `null`; no duplicates; nothing after a win; ignored for accounts | 422 `invalid_guess_history` |
| Merge `entries` | At most 500; each entry replayed, never trusted; `played_as_daily` trusted by Q2 | per-entry rejection, or 422 |
| Archive `before`, `limit` | Real date, clamped to today; limit 1 to 100 | 422 `validation_error` |
| Signed link parameters | Signature and expiry checked in constant time, on every request | 403 `invalid_media_link` |
| `Range` header on a media link | One range, inside the file | 416 |
| Session cookie | Unknown or expired means guest on game routes | guest view, `signed_in: false` |
| Clue files given to the builder (M1-22) | Content type, codec, audio, duration, size and pixel limits of AC-74b | file refused |

## Out of scope

- All frontend work (Phase 2, M1-30 to M1-37), except the seam rules AC-7 and AC-8 that M1-30 implements and the catalogue text of AC-89.
- IGDB, title import, puzzle builder (with its new video cutting and encoding), review queue, buffer alerts, credits page (M1-20 to M1-25). Phase 1 only stores `source_url` (AC-13) and fixes the file limits (AC-74b).
- Roles, admin preview, reset, `require_permission` (SPEC 3.13, open questions 2 to 5 of SPEC section 9).
- Leaderboards, community stats, rank, share text, results endpoint.
- Public cached step-1 view and Redis warm-up (Q7, M1-40, M1-51).
- Rate limits (M1-42), real email (M1-43), account export and deletion and the audit log (M1-44).
- Separate migrator and app database roles (deploy work in Phase 4).
- Other games and the word game's variants.

## Definition of done for Phase 1

**The owner can check locally (after the dev seed; with curl, add `-H 'Origin: http://localhost:5173'` to every POST):**
1. `GET /v1/games` lists `game-guesser`. `GET /v1/games/game-guesser/puzzles/today` shows step 1 only, with an image that opens in the browser.
2. Tomorrow's date and a draft's date give the same 404 `puzzle_not_found`.
3. Searching "zlda" lists a Zelda title with its year.
4. As a guest: guess wrong, skip, and get step 3; the step-3 link was not in the step-1 response. After five misses, step 6 is a clip that plays muted and loops in Chrome and Firefox; Safari or an iPhone is checked in M1-50 at the latest. A sixth miss loses and shows the answer.
5. As a signed-in player: the same game on a second browser shows the same state. A forged `previous` changes nothing.
6. Stats after a few plays match the tables in AC-52 and AC-54 for the same history.
7. A merge request sent twice leaves the stats unchanged after the first time.
8. The archive lists the 3 seeded past days and not today. `GET /v1/clock` shows the time to 00:00 UTC.
9. A POST with `Origin: https://evil.example`, or with no `Origin`, gets 403 `csrf_origin_mismatch`, on a guess and on login. Login from the frontend still works, and "Try it out" on the local docs page (`http://localhost:8000/docs`) can post a guess.

**CI must show (backend green; frontend green after regeneration):**
- Backend: lint, format, tests (including the S1 to S19 and T1 to T3 tables, the guest-versus-account table, the injected-clock tests, the range tests and the Origin table), migrations job, OpenAPI snapshot check.
- Frontend: the API-types check passes against the new snapshot; both catalogues have the new error codes.
- `CONTRACTS.md` has the "Games" section and the new CSRF rule in "Auth" (AC-78).

## Test strategy (what and at which level)

| What | Level |
|---|---|
| Streak and stats rules: S1 to S19, T1 to T3 | Pure unit tests over a list of plays, in both repos with the same rows |
| Guess rules: win, lose, skip, franchise, null franchise, near-duplicate, duplicate, after finish | Unit tests of the game module; then route tests |
| Guest replay equals account state for the same sequence | Table-driven route test, both paths |
| Forged history cannot change an account | Route test |
| Visibility: each status, future, before launch, disabled game, on every route | Route tests, one table |
| Day boundary at 23:59:59 and 00:00:00 UTC | Route tests with an injected clock |
| No answer or unearned link before the end | Route test that scans every response body of a full game |
| View media shape: steps 1 to 5 `image` with `poster: null`, step 6 `video` with MP4 last and a signed poster | Route test |
| Title search ranking, typo, cap, wildcards, short and long `q` | Route tests on a real Postgres with `pg_trgm` and full-title fixtures |
| Merge idempotence, conflicts, rejections, cap | Route tests |
| Archive paging, clamping, gaps, guest nulls | Route tests |
| Concurrent guesses for one account | Route test with two requests at once |
| Signed links: valid, expired, tampered; image and video lifetimes | Unit tests of the signer; route tests of the local media route |
| Byte ranges: 206, `Content-Range`, `Accept-Ranges`, 416, `HEAD`, expired link with `Range`, content types, `nosniff` | Route tests of the local media route |
| Builder file limits (AC-74b) | Unit tests in M1-22, with small generated files |
| Origin check: every unsafe method, auth and game routes, each row of AC-85, order before 401 and 422 | Route tests, one table |
| 415 on a non-JSON body | Route test |
| Cache-Control per route, on 404s and 403s, on media | Route tests |
| Migration | Existing CI migrations job |
| Hetzner presigned GET with `Range`, clip playback | Manual check on a real bucket (AC-72c) |
| Clip plays muted, looping, inline in Chrome, Firefox, Safari and iOS | Manual now; Playwright in M1-50 |

## Task dependencies and order

1. **The owner's answers are in** (2026-11-02). Q4 and Q13 changed the plan: step 6 is a video, and M1-41 moves from Phase 4 into Phase 1.
2. **M1-41 first** (about 0.7 day, BE and FE): it touches every unsafe route, the existing auth routes included, and their tests. Landing it before the first game POST route means no game route ever ships without it. `MILESTONE-1.md` should move M1-41 into Phase 1, which grows Phase 1 from about 5 to about 5.7 days, before M1-18's extra video work.
3. **M1-10** next: naming convention, tables, visibility function, games and puzzle read routes, dev seed (AC-82) with placeholder images and a placeholder clip on local disk.
4. **M1-11**: titles and search, with the extension in the migration and in the test setup.
5. **M1-17** any time; it has no dependencies.
6. **M1-12, then M1-13**: guesses on a pure game module, then guest replay, resume and account storage.
7. **M1-18** right after M1-12: local storage, signed links with two lifetimes, and byte ranges, so earned images and the step-6 clip work end to end. The S3 client is added in this task only. Check presigned GET with `Range` on a Hetzner bucket before Phase 4 relies on it (AC-72c). Byte ranges and the video lifetime add work to the 1-day estimate (my guess: about 0.3 day).
8. **M1-14, M1-15 and M1-16** after M1-13; they read the same progress rows and can be done in any order.
9. Each task is one backend PR with the OpenAPI snapshot. `CONTRACTS.md` and the frontend client regeneration follow in the same pass (AC-78, AC-79). Phase 2 can start against the seam once M1-10, M1-12 and M1-13 are merged.
10. **Knock-on work in later phases (Q4):** M1-22 (puzzle builder) gains cutting a clip of about 12 seconds, removing audio, encoding H.264 MP4 (and optionally WebM), saving a WebP poster frame and checking the limits of AC-74b; its 1.5-day estimate will grow. M1-30 needs a muted, looping, autoplaying `<video>` that plays inline (not full screen on iPhones), uses the `sources` list in order and the `poster`, shows a play control when autoplay is blocked, and refreshes the view when a link expires. M1-40's CSP needs `media-src` for the object-storage origin, since ARCHITECTURE 7's proposal lists only `img-src`.

**Notes for the planner (not requirements):** the backend's `CLAUDE.md` and its `fastapi-service-patterns` skill disagree on where the query layer lives; pick one before the first game domain. The root `CLAUDE.md` still says "pip + `.venv`"; the backend uses uv. The research measured that "zlda" misses the full Zelda titles at the default trigram thresholds and matches at a word-similarity threshold of 0.4. Requests through the Vite dev proxy keep the browser's `Origin` (`http://localhost:5173`) unless the proxy is set to rewrite it; check this when wiring AC-86.
