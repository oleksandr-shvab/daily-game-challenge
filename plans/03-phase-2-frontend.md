# Phase 2 frontend: the game in the browser — Implementation Plan

Status: draft, 2026-11-09. Scope: the frontend repo `my-list-fe/` (own git, GitHub `oleksandr-shvab/my-list-fe`, trunk-based, one PR per step), plus one docs-only change to the root `CONTRACTS.md` (platform repo). Line numbers were checked against frontend `main` at `e477165` and backend `main` at `f82e332`. On 2026-11-09 the owner answered SPEC-03's Q1 to Q12 with the recommended option (a) for each; this plan follows those answers.

## Source requirements

- Spec: `specs/03-phase-2-game-in-browser.md` (SPEC-03, draft, 2026-11-06), AC-1 to AC-112, tasks M1-30 to M1-37 (`MILESTONE-1.md:74-85`). Every AC is assigned to one PR in "Traceability".
- Shared test vectors: SPEC-02 AC-52 rows S1 to S19 and AC-54 rows T1 to T4 (`specs/02-phase-1-backend-core-games.md:182-212`). The backend runs them over `app/games/stats.py` in `my-list-be/tests/test_stats_rules.py:67-102` and `:152-180`; the frontend copies the same rows and ids.
- Hand-off notes from Phase 1: `plans/02-phase-1-frontend.md:174-187` (daily proof, the F2 refetch on sign-out, view, media, search, guest progress, stats, archive, merge, clock).
- Not in this plan: any backend change (SPEC-03 "Out of scope"); M1-23, M1-40, M1-42, M1-46, M1-47, M1-50.

**State of the code (checked 2026-11-09):**
- The generated client already has every route Phase 2 needs (`src/api/generated/api.ts:164-307`: clock, games list, archive, merge, today, dated view, guess, resume, stats, titles). Backend Phase 1 is complete (backend `CLAUDE.md:9`). **No regeneration PR is needed**: the owner's answers to Q2, Q10 and Q11 need no backend change.
- The frontend has no `LEARNINGS.md` (none in either repo's tree outside `node_modules`).
- The game screen is still the placeholder (`src/features/games/game-guesser/placeholder-screen.tsx`, registered at `registry.ts:10`); the archive route is a placeholder (`routes/_app/games/$slug/archive.tsx:4-18`).

## Clarifications & recommendations

No questions could be asked (this planner runs as a subagent). Facts were checked in the code; judgment calls are marked **R-n**. New questions are under "Open questions for the owner".

- **R-1. The screen gets `date: string | null` instead of `date` and `isToday`.** Today the routes pass the device's UTC day (`routes/_app/index.tsx:18`, `$slug.tsx:22`) and the dated route checks `value > today` with the device clock (`lib/utc-date.ts:38`). AC-2 needs today's pages to ask `/today` and take the date from the answer; AC-3 drops the date bound. The screen must therefore know whether the address had a date, and "is this the current puzzle" (countdown, archive marker, "Play today's puzzle") must come from the server's today, not from a flag computed on the device. `null` means "today's page". This amends SPEC-01 AC-52 ("slug, date and is-today flag"); Open question 1.
- **R-2. The view query key names the viewer**: `['game-view', slug, date ?? 'today', viewer]` where `viewer` is the user id or `'guest'`, and the query waits until `useSession()` is no longer `pending`. A sign-in or sign-out then changes the key by itself (AC-54), and a guess answer is written into the key of the viewer the answer names (`signed_in`). This is how the Phase 1 hand-off "sign-out from a game response refetches once" (`plans/02-phase-1-frontend.md:177`) is closed: the guess's `mutationFn`, after the request resolves (the session guard has already run `signOutLocally`, `session-guard.ts:78-85`), writes a `signed_in: false` answer to the guest record (from M1-32) and seeds the guest key with `setQueryData`. The new guest query then has data and does not fetch (AC-52: no step-1 flash). Cost: one round trip on a cold load, because the view waits for `/auth/me` (Open question 2).
- **R-3. Guest records: one `localStorage` key per puzzle**, `dgc.guest.v1.<slug>.<variant>.<date>`, plus `dgc.nudge_dismissed` (AC-112 names them for the privacy policy). One key per puzzle means a write in tab A touches only that puzzle (AC-46). The shape is checked with a Zod schema on every read; a bad value reads as "no record" (AC-45). Every access is wrapped: when storage throws, the module switches to an in-memory map for the tab and reports "blocked" once (AC-44). Zod is installed (`package.json` `zod ^4.4.3`) and `CLAUDE.md` names it for client-side checks.
- **R-4. The record written after a guess is the answer's `guesses` list,** not the old record plus one. The server replays `previous` + the new guess and returns the whole list, so a stale tab that read the record at send time (AC-38) writes back the union in server order (AC-46).
- **R-5. Hand-built combobox, no new dependency.** The search is server-ranked (`CONTRACTS.md` "Title search"), so the client must not filter or reorder (AC-29); shadcn's combobox is Popover plus cmdk, which filters by default and puts the list in a portal. An input with `role="combobox"`, `aria-expanded`, `aria-controls`, `aria-activedescendant` and an in-page `role="listbox"` follows the APG pattern AC-33 names. The query key is the debounced trimmed text, so an older answer can never show for a newer text (AC-27) by construction.
- **R-6. Step tabs use shadcn `tabs` (Radix Tabs)**: its roving focus skips disabled triggers (AC-12 "locked steps are skipped"), and a locked step is a disabled trigger with an accessible name "Step N, locked". Every earned step's media stays mounted and only the selected one is shown, so going back to step 1 after its 600-second link expired does not request an expired link again.
- **R-7. The merge runs as a query, not inside the login mutation:** `['guest-merge', userId]`, enabled while a user is shown and this browser holds records with guesses, `retry: false`, `staleTime: Infinity`. That covers "after login or sign-up" (AC-95) and "on the next page load while signed in" (AC-98) with one mechanism, and the signed-in view query waits for it to settle (AC-100). A record is deleted only if its stored guesses still equal what was sent (another guest tab may have written meanwhile).
- **R-8. The clock is one query** (`['clock']`, `retry: false`, refetched when the page becomes visible, AC-105) with a hook that returns the offset, the server's today and the next reset, falling back to the device's UTC day and the next device midnight when it failed (AC-76, AC-102). It lands in the first PR, because the archive marker and today/past choices need the server's today from the start.
- **R-9. Tests stay few and must be able to fail.** The spec's mandatory tables (S1 to S19 and T1 to T4, the share spoiler test, the record shape check, merge chunking) are acceptance criteria and stay complete. Everything else: one test per behavior named in the PR's "Tests" list, no extra cases. `test-writer` adds a test only where a mutation of the code (delete the rule, invert the condition) leaves the suite green, and reports the mutation it used.
- **R-10. One shared fake-backend extension in the first PR.** `FakeBackend` keys replies by path and answers with a fixed reply (`src/test/router-harness.ts:88-150`). A guess or resume reply must depend on the body (`previous`), so the harness gets a function reply `(config) => Reply`, and keeps request bodies. Every later PR uses it; nothing else changes in the harness.

## Execution mode

- **Owner's choice (already decided, not asked again):** one `implementer` agent per PR, each checked by `plan-verifier`; the owner merges. Commits and PRs only when the owner asks.
- **Risky PRs** get `code-review` at `high` effort (up to two fix rounds) after `plan-verifier` passes, then `test-writer`, before the commit:

| PR | Risky | Why |
|---|---|---|
| M1-30a | **yes** | Every later PR builds on it; guess mutation, double send (AC-16), the account retry refetch (AC-53), the viewer-keyed query (R-2), route changes that touch the shell |
| M1-30b | **yes** | Media refetch must stop after one try (AC-25) or it loops against the server; autoplay and reduced motion |
| M1-31 | no | Stale answers are prevented by the query key (R-5); keyboard pattern checked by a component test and the manual pass |
| M1-32 | **yes** | Losing a guest's record loses their streak (SPEC-03 "Problem"); untrusted storage, two tabs, sign-out mid-game |
| M1-33 (with M1-37) | no | Spoiler-free share text is pinned by the mandatory unit test |
| M1-34 | no | The S/T tables pin the computation |
| M1-35 | no | Read-only list |
| M1-36 | **yes** | Merge deletes local data; partial failures, chunks, the 401 case, the view waiting on the merge |
| D-Q10 | no | Docs only |

- Non-risky PRs: `plan-verifier` only. `shvab:implement-plan` can drive implementer, plan-verifier and the review loop for one PR section.
- **Paired waves** (each PR still has its own implementer, plan-verifier, review and merge; the second to merge rebases):
  - **Wave A: M1-30b with M1-31, plus D-Q10.** No code dependency between them; both edit only the screen file where their component is mounted and the two catalogues (different key groups: `games.clue.*` and `games.search.*`). D-Q10 is in the other repo.
  - **Wave B: M1-34 with M1-35.** Both only read records through M1-32's `readGuestRecords`; shared files are the catalogues (`games.stats.*`, `games.archive.*`).
  - Not paired: M1-30a (everything builds on it), M1-32 (risky and large; M1-33 and M1-36 build on its records), M1-33 (the stats dialog marks the bar from the end screen), M1-36 (last).
  - **Costs of a wave:** two worktrees of `my-list-fe` (one per branch); one session scratchpad shared by both agents, so give each agent a file prefix (`p2_30b_`, `p2_31_`, `p2_34_`, `p2_35_`) and tell it never to run a scratch script it did not write; one dev server port each if both run the app (`npm run dev -- --port 5174` on the second; the backend allows only `http://localhost:5173`, so a POST from 5174 gets 403 `csrf_origin_mismatch`: the second agent tests GETs only, or the two agents take turns on 5173); the second PR rebases on the catalogues; the owner reviews two PRs at once.

## Order and estimates

Agent minutes are estimates, calibrated on Phase 1 (planners 7 and 13 min; implementer runs of similar scale). Owner review is separate and is usually the larger cost.

| Step | PR | Waits for | Implementer | plan-verifier | code-review high + fixes | test-writer | Agent total | Owner review |
|---|---|---|---|---|---|---|---|---|
| 1 | M1-30a screen, ladder, Skip, clock | nothing | 25 | 6 | 15 | 8 | ~55 min | 30-40 min |
| 2 (wave A) | M1-30b clip and media refetch | M1-30a | 15 | 5 | 12 | 6 | ~40 min | 15-20 min |
| 2 (wave A) | M1-31 title search and Submit | M1-30a | 15 | 5 | none | none | ~20 min | 15-20 min |
| 2 (wave A) | D-Q10 hint kinds in `CONTRACTS.md` | nothing | 3 | 2 | none | none | ~5 min | 2 min |
| 3 | M1-32 guest records, rollover, session changes | M1-31 (and M1-30b merged) | 25 | 6 | 15 | 8 | ~55 min | 30-40 min |
| 4 | M1-33 + M1-37 end screen, share, countdown | M1-32 | 15 | 5 | none | none | ~20 min | 15-20 min |
| 5 (wave B) | M1-34 stats dialog | M1-33 | 12 | 5 | none | none | ~17 min | 15 min |
| 5 (wave B) | M1-35 archive | M1-32 (start with M1-34) | 12 | 5 | none | none | ~17 min | 15 min |
| 6 | M1-36 nudge and merge | M1-33, M1-32 | 20 | 6 | 15 | 8 | ~50 min | 30 min |

Wall clock of agent time with the waves: about 55 + 40 + 55 + 20 + 17 + 50 ≈ **4 hours**, plus the owner's reviews and merges between steps (about 3 to 4 hours in total). Human-day estimate in `MILESTONE-1.md:74` (about 5 days) is not changed by this plan.

The owner answered SPEC-03's Q1 to Q12 on 2026-11-09, so no PR waits for an answer. Q9 (a) keeps the countdown on the end screen only, so wave B's two PRs stay independent.

## Modules affected

| Where | Why | PR |
|---|---|---|
| `src/features/games/types.ts`, `game-screen.tsx`, `routes/_app/index.tsx`, `routes/_app/games/$slug.tsx`, `$slug/index.tsx`, `$slug/$date.tsx`, `lib/utc-date.ts` | R-1: `date: string \| null`; drop `FIRST_PUZZLE_DATE` and the `> today` bound (AC-3) | M1-30a |
| `src/features/games/registry.ts` | The game guesser's `screen` points to the real screen (AC-1); the five items stay | M1-30a |
| `src/features/games/game-guesser/` (new screen files; `placeholder-screen.tsx` deleted) | The screen, header, guess list, end screen, share text | M1-30a, M1-31, M1-33 |
| `src/features/games/clue-ladder/` (new) | Step tabs, hint, image and clip; reads counts from the view (SPEC-03 Goals, SPEC 3.3) | M1-30a, M1-30b |
| `src/features/games/view-queries.ts` (new), `src/features/games/guess.ts` (new) | Viewer-keyed view query, resume, guess mutation (R-2) | M1-30a, M1-32 |
| `src/features/clock/` (new) | Clock query, offset, server today, countdown | M1-30a, M1-33 |
| `src/features/games/guest-records.ts` (new) | Storage, Zod shape check, fallback map | M1-32 |
| `src/features/games/stats/` (new) | Guest stats computation, stats dialog | M1-34 |
| `src/features/games/archive/` (new), `routes/_app/games/$slug/archive.tsx` | Archive list | M1-35 |
| `src/features/games/guest-merge.ts` (new), `src/features/games/sign-up-nudge.tsx` (new) | Merge query and nudge | M1-36 |
| `src/components/ui/tabs.tsx`, `dialog.tsx` (shadcn CLI) | Step tabs (R-6), stats dialog (AC-78) | M1-30a, M1-34 |
| `src/i18n/locales/en.json`, `ru.json` | The SPEC-03 string table (`specs/03-…:240-290`), each text with the PR that first shows it; remove `games.coming_soon`, `games.archive_coming_soon`, `games.puzzle_date` if unused | every PR |
| `src/test/router-harness.ts` | R-10 function replies and request bodies | M1-30a |
| `CLAUDE.md` (frontend) | "Games" section (`:53-60`): screen props, date check, view query, guest records, clock; "Translations" unchanged | M1-30a, M1-32, M1-36 |
| Root `CONTRACTS.md` | Q10 (a): list the five hint kinds in "Games", "The view" step paragraph (`CONTRACTS.md:356-357`) | D-Q10 |

## Facts found (file:line)

- The view (`src/api/generated/models/gameGuesserView.ts`) has `type: 'game_guesser'`, `max_guesses`, `guesses_left`, `guesses_used`, `guesses[]` (`name`, `result`, `title_id`), `steps[]` (only earned ones), `answer` (null until the end), `counts_for_streak`, `daily_proof`, `signed_in`, `number`, `date`, `status`. `HintRead.kind` is `string` (`hintRead.ts`), which is Q10.
- `GuessCreate` and `ResumeCreate` take `previous: (number | null)[]`, `null` a skip; `title_id: null` is a skip (`guessCreate.ts`). `MergeEntry` has `date`, `variant`, `guesses`, `played_as_daily`, optional `daily_proof`; `MergeCreate.entries` max 500 (`mergeCreate.ts`). `MergeRead` has `stored`, `already_present`, `rejected`, `rejected_entries`, `daily_unproven`.
- `ArchiveItem` gives `state` and `guesses_used`, both `null` for a guest (`archiveItem.ts`); paging by `before` and `next_before` (`archiveList.ts`).
- `StatsRead.distribution` is keyed 1 to `max_guesses` (`statsRead.ts`); win % is the client's (SPEC-02 AC-46).
- The session guard runs `signOutLocally` inside the response chain when a `/v1/games/` answer says `signed_in: false` (`session-guard.ts:18-24`, `:78-85`); `signOutLocally` removes every query but `me` (`session.ts:85-93`). Login and sign-up both call `onAuthSuccess` and push `redirect` (`mutations.ts:36-72`).
- Query retries: network, 5xx, 408, 429, twice (`lib/query-retry.ts:6-15`); mutations never retry (`lib/query-client.ts:17`). A guess is a mutation, so no automatic resend on 429 (AC-57) comes for free.
- Error texts by code: `getErrorMessage` (`lib/error-messages.ts:32-34`). The catalogues already have `duplicate_guess`, `title_not_found`, `invalid_guess_history`, `puzzle_already_finished`, `too_many_requests`, `service_unavailable`, `internal_error`, `network_error`, `csrf_origin_mismatch` (`en.json:118-133`).
- `ErrorScreen` shows the request id and "Try again" but calls `router.invalidate()` (`components/error-screen.tsx:7-29`); the game's view error needs a "Try again" that refetches the query instead. `NotFoundMessage` takes custom keys (`:36-55`), and `games.no_puzzle` and `games.unknown_game` exist (`en.json:29-32`).
- `GameScreen` keys the error boundary by `${slug}/${date}`, never by language (`game-screen.tsx:57-61`), so a language switch keeps state (AC-107).
- The test harness already has `gameView()` built from the generated type (`router-harness.ts:45-66`).
- Tests that depend on the placeholder: `src/features/games/game-screen.test.tsx:25-29` ("coming soon"), `src/test/app.test.tsx:57` (archive "coming soon"), and the route-context assertions at `src/test/routing.test.ts:177-228` (`isToday`). They change with M1-30a and M1-35.
- Dev seed: game `game-guesser` launched 3 days ago, puzzles for today and the 3 previous days, one for tomorrow, 12 titles ("Doom"/"DOOM" pair), step 1 hint null, a null Metacritic hint two days ago, placeholder WebP images, an MP4 clip and poster (`my-list-be/CLAUDE.md:152-156`). Media links default to `http://localhost:5173/api/v1/media/...` through the Vite proxy (`:159`).
- `CONTRACTS.md` "Clock" says the client never decides "today" from its own clock for visibility, streak flags and the archive (`CONTRACTS.md:454-460`). SPEC-03 AC-76 and AC-102 use the device's UTC day only as a display fallback for a guest's own stats and the countdown, which this does not contradict.

## Architectural constraints

From `my-list-fe/CLAUDE.md`:
- Generated code is never hand-edited; `api-types` CI fails on a diff (`CLAUDE.md` "Key architectural decisions", API types bullet). Platform rule: regenerate, never hand-patch (root `CLAUDE.md`, "Working across both repos").
- Anything that touches the API goes through TanStack Query; Zustand only for state with no server counterpart (`CLAUDE.md` "Conventions"). Guest records are browser data with a server counterpart only after merge: keep them in the storage module, read through hooks, not in Zustand.
- The signed-in state lives only in the `me` query; read it with `useSession()`; never `queryClient.clear()` or remove `me` (`CLAUDE.md` "Auth", "One source of truth", "401 mid-session").
- The registry entry keeps exactly five items; Phase 2 replaces only `screen` (`CLAUDE.md` "Games", last bullet; SPEC-01 AC-56).
- A game module must not key its progress by language (`CLAUDE.md` "Games", `GameScreen` bullet; SPEC-01 AC-55b).
- A screen is a lazy component, so its code loads only when its page opens (`CLAUDE.md` "Games"; SPEC-01 AC-53). Keep the clue ladder, search and end screen inside the lazy screen's import graph; the archive route may import its own feature module.
- Never write user-visible text in a component; both catalogues; Russian plurals need `_one`, `_few`, `_many`, `_other` and `count`; backend errors by `code` only (`CLAUDE.md` "Translations").
- shadcn components are vendored; add with `npx shadcn@latest add <name>`; the CLI once wrote `import { cn } from "cn"` and added a `cn` package, which had to be undone (`CLAUDE.md` "Vendored edits"). Check `tabs.tsx` and `dialog.tsx` for the same after the CLI.
- Touch controls 44 px high below 768 px (`max-md:`), at least 24 px everywhere (`CLAUDE.md` "Shell", last bullet).
- Tests: `*.test.ts` next to the code; router tests in `src/test/` import `browser-stubs.ts` first; component tests start with `// @vitest-environment jsdom` and import `src/test/dom-setup.ts` first; no test in `src/routes/`; no `jest-dom` (`CLAUDE.md` "Conventions").
- After adding, moving or deleting a route file, run `npx vite build` before `tsc -b` (`CLAUDE.md` "Conventions"). Phase 2 adds no route file; the archive route file exists.
- Always `localhost`, never `127.0.0.1` (`CLAUDE.md` "This repo").

From the platform and specs:
- A boundary change covers backend, frontend and `CONTRACTS.md` in one pass (root `CLAUDE.md`). Phase 2 has none: the owner chose Q2 (a), Q10 (a) and Q11 (a). D-Q10 is a docs-only change to `CONTRACTS.md`.
- The server alone decides "today" for visibility; the clock offset is display only (`CONTRACTS.md:454-460`; SPEC-02 AC-69).
- Media links are bearer links and never go into the share text (`CONTRACTS.md` "Clue media"; SPEC-03 AC-69).

## Approach

Every PR: branch from a fresh `main`, PR to `main`, the four CI jobs green (lint, build, test, api-types). Branches: `p2-m1-30a-game-screen`, `p2-m1-30b-clue-media`, `p2-m1-31-title-search`, `p2-m1-32-guest-records`, `p2-m1-33-end-screen`, `p2-m1-34-stats`, `p2-m1-35-archive`, `p2-m1-36-merge`; D-Q10 is a commit (or PR) in the platform repo. Each PR adds the catalogue texts it first shows (SPEC-03 string table), in both languages, and updates the frontend `CLAUDE.md` "Games" section where its rule is new.

**Test budget for every PR** (tell `implementer` and `test-writer` this up front): write the tests listed under the PR, no more. Each must fail when the rule it covers is removed; check one by mutating the code (for example, drop the `isPending` guard and watch the double-click test go red), then restore. `test-writer` (risky PRs only) adds a test only where such a mutation leaves the suite green, and names the mutation in its report.

### M1-30a. Game screen, clue ladder with images, Skip, clock (AC-1 to AC-20 image part, AC-50, AC-51, AC-53, AC-57 to AC-62, AC-88, AC-106, AC-107, AC-110, AC-111) — risky

1. **Shell props (R-1).** `GameScreenProps` becomes `{ slug, date: string | null }` (`types.ts:5-9`); `GameScreen` passes it on and keys the boundary by `${slug}/${date ?? 'today'}` (`game-screen.tsx:57-58`). `/` and `/games/$slug` pass `null`; `$date.tsx` passes the address date. `parsePuzzleDate` keeps only the format and real-day check (`utc-date.ts:24-41`); delete `FIRST_PUZZLE_DATE` and the `today` argument; `$slug.tsx` stops returning `today`. Future or pre-launch dates now come back as 404 `puzzle_not_found` (AC-3). Update `utc-date.test.ts`, `game-screen.test.tsx` and the context assertions in `routing.test.ts:177-228`.
2. **Clock** (`src/features/clock/clock.ts`): `clockQueryOptions()` with `clockGetClock`, key `['clock']`, `retry: false`; `useServerClock()` returns `{ offsetMs, today, nextReset }`, offset = `now` minus the device time when the answer arrived; on failure `today = todayUtc()` and `nextReset` = the next device 00:00 UTC (AC-76, AC-102). Refetch on `visibilitychange` to visible (AC-105).
3. **View query** (`src/features/games/view-queries.ts`, R-2): `gameViewQueryOptions({ slug, date, viewer })` calls `gamesGetTodayPuzzle` when `date` is `null`, else `gamesGetPuzzle`; key `['game-view', slug, date ?? 'today', viewer]`; enabled only when the session is not `pending` (a session `error` is treated as `'guest'` for the key; the answer's `signed_in` decides what is written). `staleTime: Infinity` (the screen refreshes only on purpose). The screen keeps its puzzle's date from the first answer (AC-2, AC-47).
4. **Screen** (`game-guesser/game-guesser-screen.tsx`, default export; registry `screen` points to it; delete `placeholder-screen.tsx`):
   - Switch on `view.type`; an unknown type shows the in-layout game error with "Try again" (AC-5). A view error: 404 `puzzle_not_found` → `NotFoundMessage` with `games.no_puzzle` and a link to today's puzzle; 404 `game_not_found` → `UnknownGame` (`unknown-game.tsx`); network or 5xx → an in-screen error with the request id and a "Try again" that calls the query's `refetch` (not `ErrorScreen`, which invalidates the router) (AC-4, AC-60).
   - Loading: a skeleton of the game's size (`components/ui/skeleton.tsx`) (AC-6).
   - Header: `t(game.nameKey)`, `#{number}`, `formatPuzzleDate(view.date, i18n.language)` (`utc-date.ts:43-48`) (AC-7). Tab title unchanged (`GAME_NAME_TITLE`).
   - Archive marker when `view.date < serverToday` (AC-88).
5. **Clue ladder** (`src/features/games/clue-ladder/`): one tab per step `1..max_guesses` (AC-8), shadcn `tabs` (R-6). A step not in `view.steps` is a disabled trigger named "Step N, locked" with no image (AC-9, AC-12). Select the newest earned step when one is added (AC-10), store the selected step in screen state (kept across a language switch, AC-107). Hint: label from a map of the five kinds, `games.hint.hint` for any other kind, value as sent (AC-11). Image: `<img>` with `width`/`height` from the view and an aspect-ratio box with a loading state (AC-19), `alt` "Clue N of M" (AC-20). All earned media stay mounted; only the selected one shows (R-6). Video steps render the poster as a still in this PR; M1-30b makes it play.
6. **Guess list and counter**: results as icon plus word (`lucide-react` icons; "Correct", "Right series", "Wrong", "Skipped") (AC-13); colors with 3:1 contrast in both themes (AC-111); "N guesses left" with plurals (AC-14).
7. **Guess mutation** (`src/features/games/guess.ts`): `useGuessMutation({ slug, date, viewer })` sends `gamesSubmitGuess(slug, view.date, { title_id, previous })` where `previous` is the shown guesses' `title_id`s (AC-51; M1-32 replaces the source for a guest). `onSuccess` writes the answer into the key of the viewer the answer names (`signed_in`), with no second request (AC-17, R-2). Skip button (AC-15) sends `title_id: null`. While `isPending`, Skip and (later) Submit do nothing (AC-16).
8. **Errors on a guess** (one function that maps an `ApiError` to the message under the controls, from `getErrorMessage`, `role="status"`/`aria-live="polite"`, AC-61, AC-62): 429 → message, no resend (AC-57); 403 `csrf_origin_mismatch` → message, no retry (AC-58); network, 503, 500 → message, controls usable again (AC-59). For a signed-in viewer, a network error first refetches the view, and only then re-enables the controls (AC-53).
9. **Announcement** (AC-110): after an answer, a polite live region says "{result}. Step {n} unlocked. {left}." (SPEC-03 string table).
10. **AC-18**: on `won`/`lost`, all steps selectable; the answer appears only from `view.answer`. The end screen itself is M1-33; until then the screen shows the answer name under the ladder.
11. **Harness** (R-10): `Reply` may be a function of the request config; `FakeBackend` records `config.data`.
12. **Docs:** `CLAUDE.md` "Games": the new screen props, the date check now format only (the backend decides with 404), the view query key and the clock hook. Remove the placeholder bullet.

Tests (component tests in `src/features/games/game-guesser/*.test.tsx` with the fake backend, or router tests in `src/test/`):
- a fake view with `max_guesses: 5` shows five tabs and "5 guesses left" (AC-8);
- arrow keys skip a locked tab, and a locked tab has no image (AC-9, AC-12);
- a double click on Skip sends one request (AC-16);
- device clock a day ahead (`vi.setSystemTime`) on `/`: the screen asks `/today` and shows the answer's date (AC-2);
- `/games/game-guesser/2099-01-01` with a 404 `puzzle_not_found` shows "No puzzle for this date" inside the layout; an unknown `type` shows the game error with "Try again" and the sidebar stays (AC-3 to AC-5);
- signed in, a guess fails with a network error: the view is fetched again before Skip is usable, and a skip already stored by the fake server is shown, not sent twice (AC-53);
- the language changes mid-game: the selected step stays (AC-107).

Acceptance M1-30a: AC-1 to AC-17, AC-18 (no early answer), AC-19 and AC-20 for images, AC-50, AC-51, AC-53, AC-57 to AC-62, AC-88, AC-110, AC-111; local DoD item 1 (with Skip only).

### M1-30b. The step-6 clip and media refetch (AC-19 video, AC-21 to AC-25) — risky; wave A

1. **Clip** (`clue-ladder/clue-video.tsx`): `<video muted loop playsInline autoPlay preload="metadata" poster=…>` with one `<source>` per `media.sources` entry in order (AC-21). A visible play/pause button named "Pause clip" or "Play clip", 44 px on phones (AC-22). Start with `play()` in an effect and catch its rejection: blocked autoplay leaves the poster and the play control, no error (AC-23). When `matchMedia('(prefers-reduced-motion: reduce)')` matches, do not call `play()` and drop `autoPlay` (Q5 answer). Load `react-hooks-and-effects` for the effect and cleanup.
2. **Refetch** (AC-24, AC-25): an `<img>` or `<video>` `error` event asks the screen for fresh links once per media failure: for an account, `refetch` of the view query; for a guest, the same (M1-32 makes the guest query a resume with stored guesses). New `sources` replace the old ones; the selected step stays, and a playing clip resumes playing. A second failure after one refetch shows "The clue didn't load." with "Try again" in the clue's place, and nothing refetches until the player presses it. Keep the "already refetched" flag per step and link set, so a new link set (from a guess) starts fresh.
3. CSP note for M1-40 is already handed off (`plans/02-phase-1-frontend.md:186`); nothing here.

Tests:
- an image `error` event leads to one view request and the same selected step; a second `error` shows "The clue didn't load." and no third request (AC-24, AC-25);
- with reduced motion stubbed in `matchMedia`, `play` is not called and the play control shows (AC-23).
Manual (Chrome, Firefox, Safari or iOS if available): the seed clip loops muted inline; pause works by keyboard; Low Power Mode or blocked autoplay shows the poster.

Acceptance M1-30b: AC-19 (video), AC-21 to AC-25; local DoD item 3 (clip part).

### M1-31. Title search and Submit (AC-26 to AC-36, AC-55, AC-56) — wave A

1. **Search query** (`game-guesser/title-search.tsx` and `title-queries.ts`): `gamesSearchTitles(slug, { q })`, key `['titles', slug, q]` where `q` is the trimmed text after a 250 ms debounce; enabled only for `q.length >= 2` (AC-26, AC-27); `staleTime` 5 minutes (the backend sends `public, max-age=300`). The list renders the data of the current key only, never `placeholderData` (AC-27).
2. **Combobox (R-5):** input `maxLength={100}` (AC-36); list states "Type at least 2 letters", "Loading…", "No games found", "Search failed. Try again." (AC-26, AC-28, AC-30); every item in server order, name plus year and franchise when not null (AC-29); a polite count "{{count}} results" (AC-29). A title whose `title_id` is in `view.guesses` is `aria-disabled` and marked "Already tried" (AC-31). Down/Up move `aria-activedescendant`, Enter picks, Escape closes, Tab leaves (AC-33). Items 44 px on phones, the list scrolls inside itself, no sideways scroll at 320 px (AC-34).
3. **Pick and Submit:** a pick fills the box and enables "Guess"; editing the text clears the pick; Enter with a pick submits (AC-32). Submit uses M1-30a's mutation with `title_id`. Accepted and still in progress: clear the box and keep focus in it (AC-35). 422 `duplicate_guess` and `title_not_found`: their catalogue texts, clear the pick (AC-55, AC-56); every other error keeps the pick (M1-30a step 8).
4. 200 items must stay responsive: render the list without per-item state; no virtualisation unless the manual check on a phone profile shows lag (Non-functional, checked in M1-50).

Tests:
- typing "a" sends no request and shows "Type at least 2 letters"; typing "do" then "doo" quickly, with the "do" answer arriving last, shows only "doo"'s items (AC-26, AC-27);
- a guessed title is "Already tried" and Enter on it picks nothing (AC-31);
- Down, Down, Enter picks the second item and the box shows its name; Escape closes the list (AC-32, AC-33);
- a 422 `duplicate_guess` clears the pick and shows the text (AC-55).

Acceptance M1-31: AC-26 to AC-36, AC-55, AC-56; local DoD item 1 (with a real guess).

### M1-32. Guest records, resend, restore, rollover, session changes (AC-37 to AC-49, AC-52, AC-54 sign-out half) — risky

1. **Storage module** (`src/features/games/guest-records.ts`, R-3): `GuestRecord = { guesses: { title_id: number | null, name: string | null, result }[], status, counts_for_streak: boolean | null, daily_proof: string | null }`, keyed by slug, variant, date. No answer, no media link, nothing by language (AC-37). Functions: `readGuestRecord`, `writeGuestRecord`, `readGuestRecords(slug)` (scan keys by prefix), `deleteGuestRecords(entries)`, `isStorageBlocked()`. Zod schema checks each read; a bad shape reads as `undefined` (AC-45). Any storage exception switches to an in-memory map for the tab and fires the one-time notice "This browser doesn't let the site save progress…" (AC-44, toast).
2. **Writes** (in the guess `mutationFn`, right after the request resolves, R-2): when the answer says `signed_in: false`, write `{ guesses: view.guesses, status }` (R-4); keep `counts_for_streak` from the first guess only, never overwrite with `null` (AC-41); keep any non-null `daily_proof`, never erase it with `null` (AC-40). The view and today's view also store a non-null `daily_proof` before any guess (AC-40). An answer with `signed_in: true` never writes a record (AC-50).
3. **Resend** (AC-38): for a guest, `previous` is read from the stored record at send time (falls back to the shown guesses when storage is blocked).
4. **Restore** (AC-39): the guest view query's function is `gamesResumePuzzle(slug, date, { previous })` when a record with guesses exists, else the plain view. For a today page the date is not known before the first answer: ask `/today` first, then resume if a record for its date has guesses, and show nothing until then (no step-1 flash). M1-30b's media refetch now uses this function for a guest (AC-24).
5. **Errors:** 422 `invalid_guess_history` on resume or guess → delete that record, show "The saved progress for this puzzle was damaged, so it starts again.", show the fresh view (AC-42). 409 `puzzle_already_finished` → resume with the stored guesses and show the finished view (AC-43).
6. **Sign-out mid-game** (AC-52): the guest key is seeded with the answer (R-2), and its guesses become the guest record. **Sign-out by the player** (AC-54, second half): the key becomes `'guest'`, and the screen shows this browser's record, which may be empty; the account's game is never copied in (SPEC-03 edge case).
7. **Day change** (AC-47 to AC-49, Q4 answer): a hook compares `serverToday` (clock) with the date the page opened as today (for `date === null` pages only). When it is later, on submit or on the page becoming visible (and, after M1-33, when the countdown hits zero; whichever PR lands second wires it), show "A new day has started (UTC)…" with "Play today's puzzle" (a `Link` to the same today route, which loads the new day's view because the clock has moved: the route reloads; the key `['game-view', slug, 'today', viewer]` must be invalidated on that navigation). The guess still goes to the page's date. Never switch by itself (AC-47).
8. **Docs:** `CLAUDE.md` "Games": the record key names, what a record holds, the Zod check, the fallback map, "records are written only from answers that say `signed_in: false`".

Tests:
- shape check: a valid record round-trips; a record with a string `title_id`, a missing `status` or non-JSON reads as none (AC-45);
- `counts_for_streak` from the first answer survives a later `null`; a `daily_proof` survives a later `null` (AC-40, AC-41);
- reload with a stored record: the first game request is resume with the stored `previous`, and no plain view renders first (AC-39);
- two tabs: record holds guess A; tab B (whose screen shows none) sends `previous` [A] and the record ends with [A, B] (AC-38, AC-46);
- 422 `invalid_guess_history` drops the record and shows the fresh view (AC-42);
- signed in, a guess answer with `signed_in: false`: the screen shows that answer, the record holds its guesses, and no plain view request follows (AC-52);
- storage that throws on `setItem`: the game goes on and the notice shows once (AC-44);
- with a fake clock past 00:00 UTC, a submit shows the day-change message and the request still goes to the page's date (AC-48).

Acceptance M1-32: AC-37 to AC-49, AC-52, AC-54 (sign-out); local DoD item 2.

### M1-33 with M1-37. End screen, share text, countdown (AC-63 to AC-69, AC-101 to AC-105)

1. **End screen** (`game-guesser/end-screen.tsx`): "You got it!" and "Solved in N guesses" (skips count) or "Not this time"; answer name, year and franchise when not null; the guess list (AC-63). Focus moves to its heading only when the game ends during play, not when a finished puzzle opens (AC-64). Buttons "Share result", "Statistics" (opens M1-34's dialog; until M1-34 lands, the button is left out) and "Play previous days" (archive link); the countdown for today's puzzle (`view.date === serverToday`), else "Play today's puzzle" (AC-65, AC-103, Q9 answer).
2. **Share text** (`game-guesser/share-text.ts`, pure, Q1 answer): line 1 `{app.name}: {game name} #{number}`; line 2 one square per guess (correct, right series, wrong, skipped, each its own emoji); line 3 `N/6` or `X/6` (from `max_guesses`); line 4 `${location.origin}/games/${slug}/${date}`. Words from the current language. Inputs are only `number`, `date`, `slug`, the results list, status and `max_guesses`, never the view, so no name, hint or URL can reach it (AC-68, AC-69).
3. **Copy:** `navigator.clipboard.writeText`; success → "Result copied" in a live region (AC-66); refused or missing → a read-only `textarea` with the text selected and the fallback message (AC-67).
4. **Countdown** (`src/features/clock/countdown.tsx`): "Next puzzle in hh:mm:ss" to `nextReset` with the offset, one interval per second (AC-101, AC-102); `role="timer"` (not live), so screen readers read it on demand (AC-104); at zero: "A new puzzle is ready" with "Play today's puzzle", no automatic load (AC-104); refetch the clock when the page becomes visible before showing it (AC-105, from M1-30a step 2). Wire the countdown-zero trigger of M1-32 step 7.

Tests:
- share text over a won game, a lost game and an all-skip game: contains `#N`, the squares in order and `N/6`/`X/6`; contains none of the view's `answer.name`, guess names, hint values or media URLs; equal for a guest and an account with the same guesses (AC-68, AC-69);
- clipboard rejected: the selectable box and the fallback text show (AC-67);
- countdown with a fake clock and an offset of +1 h: shows the server-based time; at zero shows "A new puzzle is ready" and sends no view request (AC-101, AC-104).

Acceptance: AC-18 (end screen), AC-63 to AC-69, AC-101 to AC-105; local DoD items 3 and 4.

### M1-34. Stats dialog (AC-70 to AC-79) — wave B

1. **Guest computation** (`src/features/games/stats/compute-guest-stats.ts`, pure): input a list of plays `{ variant, date, status, guessesUsed, countsForStreak }`, `today`, `maxGuesses`, `defaultVariant`; output `{ played, wins, currentStreak, maxStreak, distribution }`. Port the rules from `my-list-be/app/games/stats.py:40-100` (`compute_stats`, `streaks` at `:85`), not from memory: finished plays count in played, wins and distribution, daily and archive alike; a win with a guess count outside 1..`maxGuesses` has no bucket but still counts (T4); streak days are finished, default-variant, `counts_for_streak` true plays, by puzzle date, deduplicated; a gap of 1 to 3 missed days keeps the run without adding, 4 or more restarts it; current is 0 when more than 3 days are missed before today (AC-74). Today is `serverToday`, falling back to the device's UTC day (AC-76).
2. **Dialog** (`stats/stats-dialog.tsx`, shadcn `dialog`): title "Statistics"; played, win % (rounded, 0 when nothing is played), current, max, distribution 1..6 as bars each with its number as text (AC-71); the bar for the just-won game's count marked when opened from the end screen (AC-72). Signed in: `gamesGetStats` with placeholders of the same size while loading, error text with "Try again" on failure (AC-73); a 401 shows the guest numbers (AC-79). Guest: computed numbers and the note "Stats from this browser…" with a "Sign up" link carrying the current page as `redirect` (AC-77). Opened from a "Statistics" button in the screen header at any time and from the end screen (AC-70); Radix gives the focus trap, Escape and focus return (AC-78).

Tests:
- **one table-driven test with ids S1 to S19 and T1 to T4**, same rows, same day numbers and same expected values as `my-list-be/tests/test_stats_rules.py:67-102` (`STREAK_ROWS`) and `:152-180` (`COUNTER_ROWS`) (AC-75). Mutation check: change the grace from 3 to 2 days and see S5, S7 and S13 fail;
- the dialog for a guest shows the computed numbers and the note; for an account it shows the server's numbers, and a 401 switches to the guest numbers (AC-73, AC-77, AC-79).

Acceptance M1-34: AC-70 to AC-79; local DoD item 5 (stats part); CI "S1 to S19 and T1 to T4 by id".

### M1-35. Archive screen (AC-80 to AC-87, AC-89) — wave B

1. `routes/_app/games/$slug/archive.tsx` renders `src/features/games/archive/archive-list.tsx` (replace the placeholder, `:4-18`; delete `games.archive_coming_soon`).
2. `useInfiniteQuery` with `gamesListArchive(slug, { before, limit: 30 })`, key `['archive', slug, viewer]`, `getNextPageParam` from `next_before`; "Show more" only when it is not `null` (AC-80). Focus moves to the first new row after "Show more" (AC-89).
3. Each row: a `Link` to `/games/$slug/$date` (same screen, no full reload, new tab works) with `#N`, the date as a UTC day in the current language, the state text and six boxes from the state and `guesses_used` only (Q2 answer: used slots filled, the last one marked correct for a win, every used slot marked for a loss), with a text alternative equal to the state text (AC-81, AC-83 to AC-85). Guest state from `readGuestRecords(slug)` (no record: "Not played"); account state from `state` and `guesses_used` (AC-82).
4. "Back to today's puzzle" link at the top; never today, never the answer (the server's list already excludes today) (AC-86). Placeholder rows while loading; "No past puzzles yet"; error text with "Try again" inside the layout (AC-87).

Tests:
- a guest with one won record and one in-progress record: rows say "Solved in 3" and "In progress", the third "Not played"; boxes' accessible names match (AC-81, AC-82, AC-85);
- "Show more" sends `before` = `next_before`, appends rows and focuses the first new row; with `next_before: null` it is gone (AC-80, AC-89).
Update `src/test/app.test.tsx:57`.

Acceptance M1-35: AC-80 to AC-87, AC-89; local DoD item 5 (archive part).

### M1-36. Sign-up nudge and guest merge (AC-90 to AC-100, AC-54 sign-in half) — risky

1. **Nudge** (`src/features/games/sign-up-nudge.tsx`), on the end screen after a guest's win, unless `dgc.nudge_dismissed` is set: the text and "Sign up", "Log in", "Not now"; both links carry the current page as `redirect` (`resolveRedirect` rules, `features/auth/redirect.ts`); "Not now" sets the flag, or hides it for the tab when storage is blocked; never for a signed-in player; never a pop-up (AC-90 to AC-94, Q3 answer).
2. **Merge query** (`src/features/games/guest-merge.ts`, R-7): enabled while `useSession()` is `signed_in` and `readGuestRecords(slug)` has records with at least one guess. Per known game: entries `{ date, variant, guesses: record title ids, played_as_daily: record.counts_for_streak === true, daily_proof: record.daily_proof }` (AC-95), in chunks of 500 sent one after another (AC-96). All 200 → delete the sent records whose stored guesses still equal what was sent, and toast "Added {{count}} games…" with the sum of `stored`, nothing when 0 (AC-97, Q6 answer). Any failure → keep every record, toast "Couldn't move your games…" (not on 401), and the next page load tries again (AC-98, AC-99). Mount it once in the `_app` layout so it runs on any page after login, sign-up or reload.
3. **The view waits** (AC-100, AC-54 sign-in half): the signed-in view query is enabled only when the merge query for that user is settled (success, error, or not needed).
4. **Docs:** `CLAUDE.md` "Games": when the merge runs, what is deleted, that the account's view waits for it.

Tests:
- 501 records → two requests of 500 and 1; records deleted only after both answer 200 (AC-96, AC-97);
- the second request answers 500 → no record deleted, failure toast; a 401 → no record deleted, no toast (AC-98, AC-99);
- entries carry `played_as_daily` from `counts_for_streak` and the stored `daily_proof` (AC-95);
- signed in with records: no view request until the merge answers (AC-100);
- "Not now" hides the nudge and it stays hidden after a re-render with a new win (AC-93).

Acceptance M1-36: AC-54, AC-90 to AC-100; local DoD item 6; SPEC-03 "Verify (no progress lost)".

### D-Q10. List the hint kinds in `CONTRACTS.md` (Q10 answer) — platform repo, docs only

In `CONTRACTS.md` "Games", the step paragraph (`:356-357`, "`hint` (`{"kind", "value"}`, or `null`…)"), add: the kinds today are `metacritic_score`, `platform`, `genre`, `year` and `developer`; the frontend shows any other kind under a generic "Hint" label, so a new kind needs no frontend change to stay visible, only a label to read well; `value` is English (decision 32). Commit in the platform repo (`git` from the root folder, per root `CLAUDE.md`). No backend or frontend change. Can merge any time; M1-30a does not wait for it.

## Owner's answers to SPEC-03 (2026-11-09)

The owner chose the recommended option (a) for all of Q1 to Q12 (`specs/03-phase-2-game-in-browser.md`, "Owner's answers"). For this plan that means:

- **No boundary task.** Q2 (a) keeps archive boxes built from state and count, Q10 (a) is the docs-only D-Q10, and Q11 (a) needs no `Retry-After` handling. There is no backend PR and no client regeneration.
- **Q1:** the share text in M1-33 is in the interface language and ends with the puzzle's link; archive plays are not marked.
- **Q3:** M1-36 shows the nudge after every guest win until "Not now" is pressed once.
- **Q4:** M1-32 step 7 keeps the open puzzle and shows the day-change message; it never switches by itself.
- **Q5:** M1-30b does not autoplay the clip under reduced motion.
- **Q6 to Q8:** M1-36 reports only the stored count; M1-32 keeps records until merged and drops a record the server calls invalid.
- **Q9:** the countdown is on today's end screen only, so M1-34 and M1-35 stay a wave.
- **Q12:** no "How to play" dialog in Phase 2.

## Skills for implementer

Project skills are in `my-list-fe/.claude/skills/`; if the implementer runs from the platform folder, read the `SKILL.md` files directly. No skill covers TanStack Router, TanStack Query, Radix Tabs or Dialog: use `docs` against the installed versions (`@tanstack/react-router` 1.170, `@tanstack/react-query` 5.102, `radix-ui` 1.6, Zod 4.4, Vitest 5).

| Files | Load | Why |
|---|---|---|
| Every code change | `shvab:karpathy-guidelines` | Small, surgical diffs; state assumptions |
| `src/features/games/view-queries.ts`, `guess.ts`, `guest-merge.ts`, `src/features/clock/*`, `archive/*` (queries) | `docs`, `shvab:react-best-practices` | **Gap:** no TanStack Query skill. Query keys, `enabled`, `setQueryData`, `useInfiniteQuery`, mutation lifecycle in the installed version |
| `game-guesser/*.tsx`, `clue-ladder/*.tsx`, `stats/stats-dialog.tsx`, `archive/archive-list.tsx`, `sign-up-nudge.tsx` | `shvab:react-best-practices`, `react-state-patterns`, `react-component-api` | Derive state from the view, never copy it; component boundaries for the reusable ladder |
| `clue-ladder/clue-video.tsx`, the countdown, the day-change hook, `title-search.tsx` (debounce, active descendant) | `react-hooks-and-effects` | Effects that sync with the DOM (`play()`, `visibilitychange`, intervals, `matchMedia`); cleanup |
| `title-search.tsx` (200 items), `clue-ladder` (mounted media) | `react-rendering-and-perf` | Keep typing responsive with 200 items; no needless re-renders |
| `src/features/games/guest-records.ts` | `shvab:zod` | The stored-record schema and `safeParse` (AC-45) |
| `src/components/ui/tabs.tsx`, `dialog.tsx` | `react-component-api` (shadcn/Radix section) | Vendored; check the `cn` import after the CLI |
| `src/i18n/locales/*.json` | none | **Gap:** no skill. Follow `CLAUDE.md` "Translations" (plural forms) |
| `src/**/*.test.ts(x)`, `src/test/*` | `shvab:react-testing-library` | Router harness, fake backend, jsdom component tests, `userEvent`, fake timers |
| `CLAUDE.md`, `CONTRACTS.md` (D-Q10) | `shvab:no-ai-slop` | The owner wants plain, short sentences |

## Verification

Run in `/home/alexandr/Developer/MyList project/my-list-fe`.

**Gate for every PR** (what CI runs, scoped where possible):
- `npm run lint`, `npm run format:check`, `npm run build`.
- The PR's own tests: `npx vitest run <the test files the PR adds or changes>`.
- api-types check: `API_SPEC=https://raw.githubusercontent.com/oleksandr-shvab/my-list-be/main/openapi/openapi.json npm run api:generate && git status --porcelain -- src/api/generated` prints nothing (no Phase 2 PR touches `src/api/generated/`).

**Full suite (`npm test`) only where a scoped run cannot catch the regression:** M1-30a (changes the shell props, routes and the harness every router test uses), M1-32 (the view query and the session-change path), M1-36 (runs on every page after login). Elsewhere the scoped run plus CI's `npm test` is enough.

**Per PR:**
- **M1-30a:** `npx vitest run src/features/games src/features/clock src/lib/utc-date.test.ts src/test`, then `npm test`. Manual with the dev seed (both servers, `http://localhost:5173`, signed out): `/` shows step 1 with no hint; Skip shows step 2 and "5 guesses left"; `/games/game-guesser/2099-01-01` shows "No puzzle for this date"; DevTools offline + Skip shows the network text.
- **M1-30b:** `npx vitest run src/features/games` (the tests live in `game-guesser/game-guesser-screen.test.tsx`). Manual: reach step 6 with skips; the clip loops muted inline with a pause button; enable "Emulate CSS prefers-reduced-motion: reduce" and reload: poster plus play button; block the media URL in DevTools: one view refetch, then "The clue didn't load."
- **M1-31:** `npx vitest run src/features/games/game-guesser/title-search.test.tsx`. Manual: type "do" → "Doom" and "DOOM"; keyboard only: Down, Enter, Enter submits; at 320 px the list does not scroll the page sideways.
- **M1-32:** `npx vitest run src/features/games`, then `npm test`. Manual: guess twice as a guest, reload: same state, no flash of step 1 (DevTools shows a `resume` request); two tabs guess in turn: nothing lost; DevTools Application → Local Storage shows only `dgc.guest.v1.*` keys and no answer or URL.
- **M1-33/37:** `npx vitest run src/features/games/game-guesser src/features/clock`. Manual: lose a game: end screen, answer, countdown; "Share result" pasted into a text editor has `#N`, squares, `X/6`, the link, no title.
- **M1-34:** `npx vitest run src/features/games/stats`. Manual: guest stats after one game; signed in, the same game shows server numbers.
- **M1-35:** `npx vitest run src/features/games/archive src/test/app.test.tsx`. Manual: the seed's three past days with states; one opens at `/games/game-guesser/{date}` with the archive marker.
- **M1-36:** `npx vitest run src/features/games`, then `npm test`. Manual = SPEC-03 DoD item 6 and the "no progress lost" check: as a guest win today and finish two archive puzzles, sign up from the nudge: back on the same page, stats played 3, current streak 1, `dgc.guest.v1.*` gone, archive shows three states.
- **D-Q10:** `git diff` in the platform repo shows only the `CONTRACTS.md` paragraph.

**Phase 2 DoD (owner, after M1-36):** SPEC-03 "Definition of done" items 1 to 10 (`specs/03-…:386-396`), and CI green on `main`.

## Risks

- **The view waits for `/auth/me` (R-2).** One extra round trip on a cold load. Mitigation: `/auth/me` is cheap and already started by the root route; Open question 2 offers the alternative.
- **Seeding the guest key after a sign-out depends on ordering** (the guard's `signOutLocally` runs before the mutation's continuation). Mitigation: the AC-52 test asserts no plain view request follows; if the ordering ever changes, the fallback is the guest resume query, which shows the same state with one extra request.
- **`localStorage` is synchronous and shared across tabs.** A write in one tab is not seen by an open second tab until its next guess (it shows a stale counter meanwhile). Accepted by AC-46; Open question 4.
- **Safari's 7-day storage eviction** (SPEC risk 18): accepted; the nudge is the mitigation.
- **Media refetch storms**: if a clue file is broken on the server, every player refetches once per failure. Bounded by AC-25's "once"; `code-review` checks the flag reset rules.
- **Autoplay differs by browser**; only manual checks until M1-50.
- **Russian texts** are the spec's, not yet checked by the D6 reviewer; one file to change.
- **Wave PRs collide in the catalogues**; mitigated by separate key groups and a rebase of the second PR.

## Rollback

- Each PR is one squash commit on `main`; roll back with a revert PR, newest first (M1-36, then M1-34/M1-35, M1-33, M1-32, M1-31/M1-30b, M1-30a).
- Reverting M1-36 leaves guest records in browsers; they merge when it returns (the merge is idempotent, SPEC-02 AC-61).
- Reverting M1-32 leaves `dgc.guest.v1.*` keys unread in browsers; harmless, and read again when it returns (the Zod check guards the shape).
- Reverting M1-30a brings back the placeholder; the later PRs must be reverted first.
- D-Q10 reverts as a docs commit.

## Open questions for the owner

New questions found while planning (SPEC-03's Q1 to Q12 are answered in the spec). Recommended option first. The plan proceeds on the recommended option.

1. **Screen props (R-1), an amendment to SPEC-01 AC-52.** (a) **Recommended:** the shell gives `slug` and `date`, with `date` `null` on today's pages; whether a puzzle is today's comes from the server's clock inside the screen. (b) Keep three props and redefine `isToday` as "this page has no date in its address" (same code, a misleading name). Either way `CLAUDE.md` "Games" changes in M1-30a.
2. **The view waits for the session check (R-2).** (a) **Recommended:** yes; one extra round trip on a cold load, and a guest's restore never flashes step 1. (b) Send the view at once and switch to resume when the session turns out to be a guest with a record (faster first paint, a possible flash of step 1 and an extra request).
3. **A game answer says `signed_in: true` while the page shows a guest** (logged in in another tab). Phase 1 left this to M1-32 and M1-36 (`plans/02-phase-1-frontend.md:254`); SPEC-03 has no AC for it. (a) **Recommended:** treat it as a sign-in: invalidate `me`, write no guest record, and let M1-36's merge run before the account's game shows (one extra line in M1-36). (b) Ignore it until the next reload (the guest record misses that guess; the server stored it in the account).
4. **Refresh a second tab when the first one guesses?** (a) **Recommended:** no in Phase 2 (AC-46 is met by resending the stored record; the stale tab catches up on its next guess). (b) Listen to the `storage` event and resume the open puzzle when its record changes (about 10 agent min in M1-32, one more test).

## Traceability

| AC | PR, step | Checked by |
|---|---|---|
| AC-1 | M1-30a.4 | manual DoD 1 |
| AC-2, AC-3 | M1-30a.1, .3 | AC-2 clock test; 404 router test |
| AC-4 to AC-6 | M1-30a.4 | router tests (404s, unknown type) |
| AC-7 | M1-30a.4 | review; manual |
| AC-8 to AC-12 | M1-30a.5 | `max_guesses: 5` test; locked-tab test |
| AC-13, AC-14 | M1-30a.6 | covered in the AC-8 test (counter); manual |
| AC-15 to AC-17 | M1-30a.7 | double-click test |
| AC-18 | M1-30a.10, M1-33.1 | review; manual DoD 3 |
| AC-19, AC-20 | M1-30a.5, M1-30b.1 | review; manual |
| AC-21 to AC-25 | M1-30b | refetch-once test; reduced-motion test; manual |
| AC-26 to AC-36 | M1-31 | search tests; manual keyboard and 320 px |
| AC-37 to AC-46 | M1-32.1 to .5 | shape, proof, restore, two-tab, 422, storage tests |
| AC-47 to AC-49 | M1-32.7 | day-change test |
| AC-50, AC-51 | M1-30a.7, M1-32.2 | review |
| AC-52 | M1-32.6 | signed-out-mid-game test |
| AC-53 | M1-30a.8 | account network-retry test |
| AC-54 | M1-32.6 (sign-out), M1-36.3 (sign-in) | merge-wait test; manual |
| AC-55, AC-56 | M1-31.3 | duplicate test |
| AC-57 to AC-62 | M1-30a.8 | review; manual offline check |
| AC-63 to AC-69 | M1-33.1 to .3 | share-text test; clipboard test |
| AC-70 to AC-79 | M1-34 | S1 to S19 and T1 to T4 table; dialog test |
| AC-80 to AC-89 (except AC-88) | M1-35 | archive tests |
| AC-88 | M1-30a.4 | manual DoD 5 |
| AC-90 to AC-100 | M1-36 | merge and nudge tests; manual DoD 6 |
| AC-101 to AC-105 | M1-33.4, M1-30a.2 | countdown test |
| AC-106, AC-107 | every PR; M1-30a | `catalogues.test.ts` parity; language test |
| AC-108, AC-109 | every screen PR | manual 320/360/768/1280 and keyboard pass (Playwright and axe in M1-50) |
| AC-110, AC-111 | M1-30a.6, .9 | review; manual contrast check in both themes |
| AC-112 | M1-32.1, M1-36.1 | review; names handed to M1-46 (privacy policy) |
| Q10 (a) | D-Q10 | diff review |
