# Phase 1 frontend: error texts, Origin through the proxy, `signed_in: false`, game list from the backend — Implementation Plan

Status: draft, 2026-11-02. Scope: the frontend repo `my-list-fe/` (own git, GitHub `oleksandr-shvab/my-list-fe`, trunk-based, one PR per step). Phase 1 is mostly backend; this plan covers only the frontend's share of SPEC-02. The backend plan is being written in parallel as `plans/02-phase-1-backend.md`; it did not exist when this plan was finished, so each PR below names the backend task (M1-xx) and route it waits for, as SPEC-02 names them. Line numbers were checked against frontend `main` at `0f444a4` and backend `main` at `365c671`.

## Source requirements

- Spec: `specs/02-phase-1-backend-core-games.md` (SPEC-02, agreed 2026-11-02, owner's answers Q1 to Q20). Decisions 65 and 67 in `SPEC.md` (lines 79, 81) summarise SPEC-01 and SPEC-02.
- Frontend items in SPEC-02, all covered here:
  - **AC-7, AC-8** (`specs/02-…:116-117`): the nav shows only games known to both the registry and `GET /v1/games`; fallback to the registry when the call fails; `/` shows "Unknown game" when the default game is not in the backend's list. SPEC-02 "Out of scope" (`:382`) keeps these two in this spec ("except the seam rules AC-7 and AC-8 that M1-30 implements"). This closes SPEC-01's open edge case (`specs/01-…:215`).
  - **AC-42** (`:167`) and Q11 (`:34`), edge case `:301`: a game response with `signed_in: false` while the page shows a user switches the frontend to signed out.
  - **AC-75** (`:251`): the ten new error codes in both catalogues. **AC-89** (`:282`): `csrf_origin_mismatch` in English and Russian, no other change.
  - **AC-79** (`:265`): the client regenerated in the same pass as each backend snapshot change.
  - **AC-86** edge cases (`:325`) and the planner note (`:448`): the browser's `Origin` must reach the backend through the Vite dev proxy.
  - **Definition of done** (`:393-407`): local item 9 ("Login from the frontend still works"); CI: "the API-types check passes against the new snapshot; both catalogues have the new error codes".
- Not built here, only handed off (section "Hand-off to Phase 2"): everything SPEC-02 says M1-30, M1-32, M1-34, M1-36, M1-37 or M1-40 will need. The game screen is Phase 2.
- Not in this plan (backend plan): every `CONTRACTS.md` change of AC-78 (the "Games" section, the new codes in "Errors", the CSRF rule replacing `CONTRACTS.md:36-39`), backend docs and the dev seed.

**State of the code (checked 2026-11-02):**
- Frontend `main` is `0f444a4` (Phase 0 F4 merged), clean, on `main`.
- Backend `main` is `365c671`. Its snapshot has `info.title` "Daily Game Challenge API" and only the health and auth routes (nine operations); no game route exists yet.
- The frontend has no `LEARNINGS.md`.

## Clarifications & recommendations

No questions could be asked (this planner runs as a subagent). Facts were checked in the code; judgment calls are marked **R-n**. Questions for the owner are under "Open points", each with the default this plan proceeds on.

- **R-1. One small regeneration PR per backend PR that changes the snapshot** (the "G" PRs below), never folded into a feature PR. From the moment such a backend PR merges, the frontend `api-types` job fails on every PR and on `main` until the regenerated client is committed (`.github/workflows/ci.yml:56-75`). A mechanical PR is quick to verify and merge; the feature PR that needs the new function comes after it. Same reasoning as Phase 0's F0 (`plans/01-phase-0-frontend.md:34`).
- **R-2. All ten new error texts in one early PR (F1),** not one per backend task. They are only catalogue entries, harmless before the routes exist, and the DoD checks them all together. F1 merges after backend M1-41, because it also rewrites the "no CSRF protection" line in the frontend `CLAUDE.md:46`.
- **R-3. Also add `errors.validation_error` and `errors.not_found`.** AC-75 lists them as "reused", but the catalogues have no text for either (`src/i18n/locales/en.json:110-129`), so a 422 without field errors (archive `limit`, merge `entries`) or a 404 `not_found` shows the generic `errors.unknown`. Cheap; Open point 5.
- **R-4. `signed_in: false` handled in the session guard, by an axios success interceptor,** not by each game query. `installSessionGuard` already turns a 401 into the signed-out state (`src/features/auth/session-guard.ts:103-123`). Adding the same reaction for a 2xx JSON body from a `/v1/games/` path with `signed_in === false` means no Phase 2 query or mutation can forget it.
- **R-5. AC-7 and AC-8 in Phase 1 (F3),** because SPEC-02 keeps them in its scope and they need only `GET /v1/games` (M1-10), not the game screen. F3 can move to M1-30 unchanged if the owner prefers (Open point 1).
- **R-6. Game routes wait for `GET /v1/games`, and a failure never blocks.** `$slug` and `/` read the list in `beforeLoad` with a helper that returns `undefined` on any error, so a failed call falls back to the registry (AC-8) and an unknown or disabled game never flashes its screen before "Unknown game". The query has `retry: false` (the fallback covers failure, and a retry would delay the page by seconds) and `staleTime` 5 minutes, the same as the backend's `public, max-age=300` (AC-77). Open point 3.
- **R-7. The guest streak and stats tables (AC-52, AC-54) stay with M1-34.** Both ACs say "in the frontend's tests", but the frontend computation is the guest stats of M1-34 (Phase 2), SPEC-02 "Out of scope" does not except them, and the DoD lists the tables only for the backend (`:405`). Handed off with the exact row IDs. Open point 2.
- **R-8. No automated test for the proxy.** The Vite source shows the `Origin` header passes unchanged (facts below); a manual curl check after backend M1-41 proves it end to end, and a comment in `vite.config.ts` plus one line in `CLAUDE.md` stop someone adding a rewrite later. A test that starts a Vite server would also run the router plugin and cost more than it protects.

## Execution mode

- **Owner's choice (already decided, not asked again): one agent per PR, each checked by `plan-verifier`; the owner merges. Commits and PRs only when the owner asks.**
- My recommendation fits that: for each PR (F1, F2, F3 and every G PR), one `implementer` run on that PR's section only, then `plan-verifier` against that PR's acceptance checks. Add a `code-review` pass at `medium` effort after F2 (it changes the session guard, which every request goes through). G PRs are mechanical; `plan-verifier` alone is enough. `shvab:implement-plan` can drive implementer, plan-verifier and the review loop for one section.

## Assumptions about the backend

- Backend PRs follow SPEC-02 "Task dependencies and order" (`:435-446`): M1-41 first, then M1-10, M1-11, M1-17 (any time), M1-12, M1-13, M1-18, then M1-14, M1-15, M1-16, each one PR with the OpenAPI snapshot. Operation ids are `<tag>_<handler>` (`CONTRACTS.md:21-22`), so the generated function names are known only after each backend PR; this plan refers to routes, not function names.
- **The owner merges a backend PR that changes the snapshot only when its G PR is ready** (as in Phase 0, backend hand-off H2), so the frontend red window is minutes.
- `POST /v1/auth/logout` is sent with no body and no `Content-Type` (`src/api/generated/api.ts:80-89`). AC-76 asks for 415 only on a request that "carries a body", so logout must keep working. To confirm in the backend plan.
- The Origin check compares `Origin` with the allowed origins list (AC-86), not with the `Host` header. The dev proxy rewrites `Host` to `localhost:8000` (fact below), so a Host-based same-origin check would refuse every request from the dev frontend.
- The `signed_in` field is top-level in every game view (AC-25) and appears in the snapshot no later than M1-13 (AC-42 is in the M1-13 group). If the backend plan names it differently, F2 follows the generated model.

## Modules affected

| Where | Why | PR |
|---|---|---|
| `src/api/generated/` | New game routes and models from each backend snapshot | G-M1-xx |
| `src/i18n/locales/en.json`, `ru.json`, `src/i18n/catalogues.test.ts`, `src/lib/error-messages.test.ts` | Ten new error texts plus two reused codes; a test that pins the list | F1 |
| `vite.config.ts` | One comment: the proxy must keep the browser's `Origin` | F1 |
| `src/features/auth/session-guard.ts`, `src/test/routing.test.ts`, `src/test/router-harness.ts` | `signed_in: false` on a game response signs out locally | F2 |
| `src/features/games/` (`queries.ts`, `known-games.ts` new; `registry.ts` comment), `src/routes/_app/index.tsx`, `src/routes/_app/games/$slug.tsx`, `src/components/app-sidebar.tsx`, router and shell tests | Nav and routes use the games both sides know | F3 |
| `CLAUDE.md` (frontend) | Auth line on CSRF (`:46`), proxy and `Origin` (`:30-31`), the session guard (`:50`), Games section (`:55`, `:60`, `:66`) | F1, F2, F3 |
| Root `CONTRACTS.md` | Not edited by this plan (backend plan, AC-78). F2 checks that the "Games" section says how the frontend reacts to `signed_in: false`, and hands the sentence to the backend PR if it is missing | none |

## Facts found (file:line)

- **The Vite dev proxy keeps the browser's `Origin`.** Vite 8.2.2 (`node_modules/vite/package.json`). `changeOrigin: true` (`vite.config.ts:23`) rewrites only the `Host` header (`node_modules/vite/dist/node/chunks/node.js:18275`). Vite's own `Origin` rewrite (`node.js:19186-19197`) runs only for WebSocket upgrades (`proxyReqWs`, `node.js:19225-19226`) and only with the `rewriteWsOrigin` option, which this config does not set. Nothing else touches `origin` or `referer` on HTTP requests. So `POST /api/v1/auth/login` from `http://localhost:5173` reaches the backend with `Origin: http://localhost:5173`, which is `FRONTEND_URL` and in `BACKEND_CORS_ORIGINS` by default (`my-list-be/app/core/config.py:35`, `:37`). Still to prove end to end after M1-41 (Verification, F1).
- **`npm run preview` uses the same proxy** (`preview.proxy ?? server.proxy`, `node.js:35781`) but runs on `http://localhost:4173`, which is not an allowed origin. After M1-41, every POST from the preview build gets 403. Documented, not changed (Open point 7).
- The axios instance sends cookies with `baseURL: '/api'` (`src/lib/api-client.ts:54-57`); it never sets `Origin` (browsers forbid it). Generated POST functions with a body set `Content-Type: application/json` (`src/api/generated/api.ts:52-61`); logout has no body (`:80-89`).
- Error texts are looked up by `code` with a fallback to `errors.unknown` (`src/lib/error-messages.ts:17-35`). Forms show a non-field error as the root message (`src/features/auth/map-error-to-form.ts:30`), so a 403 `csrf_origin_mismatch` on login appears in the form once the text exists. Today's catalogue has no `validation_error`, `not_found` or any new code (`en.json:110-129`, `ru.json:114-137`).
- `catalogues.test.ts:28-34` already fails when the two catalogues have different keys; nothing checks that a given backend code has a text.
- The session guard reacts only to a 401 while a user is cached (`session-guard.ts:108-120`), via `signOutLocally` (`src/features/auth/session.ts:194-202`), which sets `me` to `null` and removes every other query.
- The registry is static and read synchronously by five callers: `app-sidebar.tsx:65` (nav entries) and `:89` (archive link fallback to the default game), `routes/_app/index.tsx:11`, `routes/_app/games/$slug.tsx:34`, `lib/page-title.ts:33`, `features/games/use-current-game.ts:31`. Its comment still says "Phase 1 moves the list to the backend" (`registry.ts:4-5`), and so does `CLAUDE.md:55`.
- `/_app/` has no `notFoundComponent` (`routes/_app/index.tsx:8-16`); `$slug.tsx:39` has `UnknownGame`. The page title already turns any not-found match into the not-found title (`page-title.ts:41-43`), and `resolveCurrentGame` gives no current game on a not-found page (`use-current-game.ts:25`).
- The router test harness answers 404 to any URL it was not told about (`src/test/router-harness.ts:94-99`), and `shouldRetryQuery` does not retry a 404 (`src/lib/query-retry.ts:82-90`). So once F3 adds the games call, existing tests see the "call failed" path unless the harness gets a default games reply.
- `FIRST_PUZZLE_DATE` (`src/lib/utc-date.ts:5`, used at `:41`) is the temporary lower bound for puzzle dates, "until Phase 1's backend answers which days exist" (`CLAUDE.md:60`).
- Logout signs out locally whatever the answer (`src/features/auth/mutations.ts:73-80`). A 403 on logout (wrong origin) would leave the server session alive and a reload shows the user again (Risks).

## Architectural constraints

From `my-list-fe/CLAUDE.md`:
- Generated API code is never hand-edited; CI's `api-types` job compares it with the backend contract (`CLAUDE.md:45`). Platform rule: regenerate, never hand-patch (root `CLAUDE.md`, "Working across both repos").
- The signed-in state lives only in the `/auth/me` query; nothing copies it; sign out with `signOutLocally`, never `queryClient.clear()` or removing `me` (`CLAUDE.md:47`, `:50`).
- Anything that touches the API goes through TanStack Query; Zustand only for state with no server counterpart (`CLAUDE.md:84`).
- Never write user-visible text in a component; both catalogues; backend errors translated by `code` only, never the backend's English (`CLAUDE.md:98`, `:100`).
- Query retries only network, 5xx, 408, 429, at most twice (`CLAUDE.md:101`).
- Registry entry has exactly five items; one default; slugs exact and case-sensitive; a bad slug throws `notFound()` and the not-found screen stays inside the layout (`CLAUDE.md:55-56`, `:60`).
- Router tests live in `src/test/` and import `browser-stubs.ts` first; component tests start with `// @vitest-environment jsdom` and import `dom-setup.ts` first; never a test in `src/routes/` (`CLAUDE.md:81-82`).
- Always `localhost`, never `127.0.0.1` (`CLAUDE.md:31`; root `CLAUDE.md`).

From the platform:
- A boundary change covers backend, frontend and `CONTRACTS.md` in one pass (root `CLAUDE.md`). Name, nav order and the default game stay in the frontend registry; `GET /v1/games` returns `slug`, `default_variant`, `launch_date` (SPEC-02 AC-14).
- Q18: no custom CSRF header; do not add `X-Requested-With` or anything like it (`specs/02-…:274`).
- The client may use the server clock only for display (AC-69); "today" for visibility is the server's.

## Approach

Every PR: branch from a fresh `main`, PR to `main`, all four CI jobs green (lint, build, test, api-types) before merge. Suggested branches: `p1-g-m1-xx` (G PRs), `p1-f1-error-texts`, `p1-f2-signed-in-false`, `p1-f3-known-games`.

Order: F1 after backend M1-41. G PRs as backend PRs land. F3 after G-M1-10. F2 after the G PR that first puts `signed_in` in a view (expected G-M1-13; earlier if M1-10's view already has it). F2 and F3 do not touch the same files except `CLAUDE.md` and the test harness; whichever merges second rebases.

### G-M1-xx. Regenerate the API client (one per backend PR that changes the snapshot)

Waits for: that backend PR merged on backend `main`. Expected for M1-10, M1-11, M1-12, M1-13, M1-14, M1-15, M1-16, M1-17, and M1-18 if it adds the local media route to the snapshot; M1-41 only if it documents 403/415 responses. If regeneration gives no diff, there is no G PR.

1. Regenerate exactly as CI does: `API_SPEC=https://raw.githubusercontent.com/oleksandr-shvab/my-list-be/main/openapi/openapi.json npm run api:generate`.
2. Expected diff: new functions in `src/api/generated/api.ts` and new files in `src/api/generated/models/` for the new routes only. If an existing function or model changes (an auth signature, a renamed operation), stop and report: the backend made a breaking change, which needs its `breaking-change` label and a frontend fix in the same PR (`CONTRACTS.md:122-128`).
3. Nothing else changes. Do not wrap the new functions in queries yet; Phase 2 does that, except where F2 or F3 need them.
4. It must be the next frontend merge after its backend PR. Open frontend PRs rebase on it.

Acceptance G: the api-types check prints nothing; `npm run build` and `npm test` pass; the diff is only under `src/api/generated/`. AC-79 (frontend half) for that backend task.

### F1. Error texts and the `Origin` rule (frontend part of M1-41; AC-75, AC-89)

Waits for: backend M1-41 merged (the `CLAUDE.md:46` change would be false before it). It can be prepared earlier.

1. **Catalogues** (`src/i18n/locales/en.json` and `ru.json`, under `errors`, same keys in both; Russian to be checked by the D6 reviewer, like Phase 0):
   - `csrf_origin_mismatch`: EN "This request came from an address the site does not accept. Open the site at its usual address and try again." RU "Запрос пришёл с адреса, который сайт не принимает. Откройте сайт по обычному адресу и попробуйте снова." (Also what a developer on `127.0.0.1:5173` sees.)
   - `unsupported_media_type`: EN "The request was sent in a format the server does not accept." RU "Запрос отправлен в формате, который сервер не принимает."
   - `game_not_found`: EN "There is no such game." RU "Такой игры нет."
   - `variant_not_found`: EN "This game has no such mode." RU "У этой игры нет такого режима."
   - `puzzle_not_found`: EN "There is no puzzle for this date." RU "На эту дату загадки нет."
   - `title_not_found`: EN "Pick a title from the list." RU "Выберите название из списка."
   - `duplicate_guess`: EN "You have already tried this one." RU "Этот вариант уже был."
   - `invalid_guess_history`: EN "The saved progress for this puzzle is not valid." RU "Сохранённый прогресс этой загадки некорректен."
   - `puzzle_already_finished`: EN "This puzzle is already finished." RU "Эта загадка уже завершена."
   - `invalid_media_link`: EN "The link to this clue has expired." RU "Ссылка на подсказку устарела."
   - R-3 (Open point 5): `validation_error`: EN "Some values are not valid." RU "Некоторые значения некорректны."; `not_found`: EN "Not found." RU "Не найдено."
   Phase 2 may reword any of these once the screens exist (the code stays, only the text changes).
2. **Test that pins the list** (`src/i18n/catalogues.test.ts`): a constant list of every backend code from `CONTRACTS.md` "Errors" (`:97-103`) plus the AC-75 codes, minus `method_not_allowed` (a client bug, never shown to a player); field-only codes (`passwords_do_not_match`, `new_password_same_as_old`) stay in the list, since they already have texts; the test fails when `en.errors` or `ru.errors` lacks one. Comment: "Add a code here when the backend adds one (CONTRACTS.md, Errors)". The DoD item "both catalogues have the new error codes" is this test.
3. **Message test** (`src/lib/error-messages.test.ts`): an `ApiError` with status 403 and code `csrf_origin_mismatch` gives the English text, and the Russian text after `i18n.changeLanguage('ru')` (AC-89).
4. **Proxy note** (R-8): one comment above the `/api` entry in `vite.config.ts:21`: the backend refuses unsafe requests whose `Origin` is not an allowed origin, and this proxy forwards the browser's `Origin` unchanged (`changeOrigin` rewrites only `Host`); do not add `rewriteWsOrigin`, `headers` or a `configure` hook that changes `Origin` or `Referer`.
5. **Docs** (`CLAUDE.md`): replace "The backend currently implements no CSRF protection — a backend gap, not something the frontend compensates for." (`:46`) with: the backend refuses any POST, PUT, PATCH or DELETE whose `Origin` (or `Referer`) is not an allowed origin (403 `csrf_origin_mismatch`) and any body that is not JSON (415); the frontend needs nothing for it, since browsers send `Origin` on its requests; there is no custom CSRF header, by decision (SPEC-02 Q18). In "This repo" (`:30-31`): the dev proxy keeps the browser's `Origin`; open the app at `http://localhost:5173`, because `127.0.0.1:5173` and the preview server on `4173` are not allowed origins and their POSTs get 403.

Acceptance F1: AC-75 (frontend catalogues), AC-89; DoD "both catalogues have the new error codes"; the manual Origin check in Verification passes (DoD local item 9, first half).

### F2. `signed_in: false` from a game route signs the page out (AC-42, Q11)

Waits for: the G PR that first brings a game view with `signed_in` (expected G-M1-13, after backend M1-13 `POST /v1/games/{slug}/puzzles/{date}/resume` and guest/account progress; can start after G-M1-10 if `GET /v1/games/{slug}/puzzles/{date}` already returns `signed_in`).

1. **Session guard** (`src/features/auth/session-guard.ts`): move the body of today's 401 branch (`:113-119`) into one local function, "the session ended". Add a success handler to the same interceptor registration (`apiClient.interceptors.response.use(onSuccess, onError)`), so the one eject at `:125` still removes both. The success handler calls "the session ended" when all hold: the request path starts with `/v1/games/`; the body is a JSON object whose top-level `signed_in` is exactly `false`; `getSignedInUser(queryClient)` is a user. It always returns the response unchanged. On an account-only page the existing toast and `router.invalidate()` follow; on a public page (every game page) the account area switches to "Log in" (AC-26b behaviour of Phase 0).
2. `signed_in: true` while the page shows a guest changes nothing in Phase 1 (Open point 4).
3. `signOutLocally` removes all other cached queries, including the game view that just answered. A mounted Phase 2 query then fetches again, now as a guest; that one extra request is accepted (Risks).
4. **Tests** (`src/test/routing.test.ts`, describe "a game response that says signed_in: false (AC-42)"; write it first and see it fail):
   - signed in, on `/`: the fake backend answers the game view route (the real path from the generated function; call the generated function itself) with a 200 view whose `signed_in` is `false`: afterwards the `me` data is `null`, the path is still `/`, no toast;
   - same body with `signed_in: true`: `me` data is still the user;
   - a non-game path whose body has `signed_in: false` (for example a made-up `/v1/other`): `me` unchanged;
   - a guest gets `signed_in: false`: nothing changes and no error is thrown.
   Build the view body from the generated model type, so a renamed field fails `tsc`.
5. **Docs:** `CLAUDE.md:50` ("401 mid-session"): one sentence that a game response with `signed_in: false` has the same effect, through the same interceptor. Check that the backend's `CONTRACTS.md` "Games" section states this frontend behaviour; if not, give the backend PR this sentence: "A game response with `signed_in: false` while the frontend shows a user means the session ended; the frontend switches to signed out, as for a 401."

Acceptance F2: AC-42 (frontend reaction), SPEC-02 edge case "Session expired while the frontend still shows the player signed in"; the tests above; the review pass after F2.

### F3. Show only the games both sides know (AC-7, AC-8)

Waits for: G-M1-10 (backend M1-10, `GET /v1/games` returning `slug`, `default_variant`, `launch_date`, AC-14).

1. **Query** (new `src/features/games/queries.ts`): `gamesQueryOptions()` with the generated `GET /v1/games` function, query key `['games']`, `staleTime` 5 minutes, `retry: false` (R-6). `knownGameSlugs(queryClient)`: `ensureQueryData` of it, mapped to a `Set` of slugs, and `undefined` on any error (it never throws).
2. **Pure rules** (new `src/features/games/known-games.ts`), so the routes, the sidebar, the title and the current game use one function:
   - `knownGames(slugs)`: `slugs` undefined (pending or failed) → the whole registry in `order` (AC-8); otherwise the registry entries whose slug is in `slugs`, in `order` (AC-7). Backend slugs the registry lacks are ignored.
   - `findKnownGame(slug, slugs)`: registry entry by exact slug (as `findGame`, `registry.ts:17-19`) and, when `slugs` is known, also in it.
   - `isDefaultKnown(slugs)`: `slugs` undefined or containing the default game's slug.
   - `useKnownGames()`: `useQuery(gamesQueryOptions())` and `knownGames` of its data (undefined while pending or failed).
3. **Routes:**
   - `src/routes/_app/games/$slug.tsx:33-38`: `beforeLoad` becomes async: keep the registry check first; then `await knownGameSlugs(context.queryClient)`; a known list without the slug throws `notFound()` → the existing `UnknownGame`.
   - `src/routes/_app/index.tsx:10-15`: same check for the default game; add `notFoundComponent` with the same "Unknown game" message (`NotFoundMessage` with `games.unknown_game` and `games.unknown_game_text`; share the `UnknownGame` component rather than copy it). Check in the router test that the not-found renders inside `_app` (the Phase 0 behaviour for `$slug`, `plans/01-phase-0-frontend.md:23`).
4. **Sidebar** (`src/components/app-sidebar.tsx`): entries from `useKnownGames()` instead of `getGamesInOrder()` (`:65`). Archive link (`:89`): the current game, else the default game if known, else the first known game; no link when no game is known. The archive page itself needs no change: it is under `$slug`, so step 3 covers it.
5. Page title and current game need no change: a removed game's page is a not-found match, which both already handle (facts above).
6. **Comments and docs:** `registry.ts:4-5`: the registry holds the games the frontend can open, their names, order and default; the backend decides which of them are enabled, and the nav shows the ones both know. `CLAUDE.md` "Games" (`:55`, `:60`) and "Shell" (`:66`): same rule, the fallback when `GET /v1/games` fails, the route check, and that `FIRST_PUZZLE_DATE` is still the date bound until the game screen reads `puzzle_not_found` (Phase 2).
7. **Tests:**
   - `src/features/games/known-games.test.ts`: `undefined` → full registry; a list with the slug → the entry; an empty list → none; a list with only an extra slug (`word-game`) → none; order kept with a fixture registry of two entries; `isDefaultKnown` for each case.
   - Harness (`src/test/router-harness.ts`): a `GAMES_URL` constant and a default reply listing `game-guesser`, so existing tests keep the success path; tests override it.
   - `src/test/routing.test.ts`: games list without `game-guesser` → `/`, `/games/game-guesser` and `/games/game-guesser/archive` give a not-found inside a successful `_app` match (AC-8); games list 500 or a network error → the pages load with the registry (AC-8; a never-answering list is not tested, see Risks); list with `game-guesser` and `word-game` → `/games/word-game` is not found (registry lacks it) and `/` loads (AC-7).
   - `src/test/shell.test.tsx` (jsdom): list with `game-guesser` → one game entry; list without it → no game entry and no archive link; list fails → the registry's entry (AC-7, AC-8). No crash in any case.

Acceptance F3: AC-7, AC-8 (nav and `/` parts); SPEC-02 edge cases "Backend lists a game the frontend has no screen for, or the reverse" and "`GET /v1/games` fails"; SPEC-01 edge case at `specs/01-…:215` closed.

## Hand-off to Phase 2 (notes only; not built here)

- **Sign-out from a game response refetches once (owner, 2026-11-06, after the F2 review).** When a game response says `signed_in: false`, `signOutLocally` drops every cached query, including the game query whose answer is being delivered, so its observer sends the same request again. The guard cannot spare that one query, because an axios request does not carry its TanStack query key. When M1-30 builds the game query, either pass the query key through the request config (`meta`) so the guard can exclude it, or let the screen use the `signed_in: false` answer itself and keep its data.
- **M1-30 (game screen):** query the view with `GET /v1/games/{slug}/puzzles/{date}` (a dated page) or `/today` (the body names the date it resolved to, AC-15); map 404 `puzzle_not_found` to the existing "No puzzle for this date" screen and 404 `game_not_found` to "Unknown game" (that also covers a game disabled after F3's list was cached), then drop `FIRST_PUZZLE_DATE` (`utc-date.ts:5`) in favour of the backend's answer and `launch_date` (SPEC-01 AC-45: "From Phase 1 the backend's answer decides"). The view is a tagged union on `type` (`game_guesser`, AC-3); switch on it. Step media: `image` steps have one source and `poster: null`; step 6 is a muted, looping, autoplaying, inline `<video>` (`playsInline`) with the `sources` list in order (WebM first when present, MP4 last) and the signed `poster`, plus a play control when autoplay is blocked (SPEC-02 `:446`, edge case `:313`). On a 403 `invalid_media_link` or an `<img>`/`<video>` load error after `expires_at`, ask for the view (or resume) again and swap the sources (AC-73, edge case `:310`). Disable Submit and Skip while a guess request runs (edge case `:296`). `duplicate_guess`, `title_not_found`, `puzzle_already_finished` texts exist after F1. "Each game screen shows its own error" (AC-8): use the error from the view query inside the screen; the Phase 0 `GameErrorBoundary` stays for crashes.
- **M1-30 / M1-32 and AC-42:** after F2, a guess or resume answered with `signed_in: false` means the request ran as a guest with whatever `previous` the client sent. The screen must then treat the answer as a guest result (from that point it keeps progress locally, M1-32), not as the account's state.
- **M1-31 (search):** `q` trimmed; under 2 characters gives an empty list, so do not call below 2; over 100 is 422; never padded; the year is shown (Q15, Q17).
- **M1-32 (guest progress):** send `previous` (at most 5 on a guess, 6 on a resume); keep `counts_for_streak` from the first guest guess, later responses send `null` (AC-40); 422 `invalid_guess_history` means local progress is bad, decide the UX there; nothing in storage may be keyed by language (AC-6). Day change while a page is open: the guess goes to the page's date and becomes an archive play (Q1).
- **M1-34 (stats):** guest stats in the browser must pass every row of S1 to S19 (AC-52) and T1 to T3 (AC-54), copied verbatim from SPEC-02 `:182-211` into one table-driven test; account stats come from `GET /v1/games/{slug}/stats`, which answers 401 for a guest (the session guard handles it); the win rate is computed by the client from `wins` and `played` (AC-46); `current_streak` and `max_streak` are `null` for a non-default variant (AC-51).
- **M1-35 (archive):** page with `before` and `next_before`; `limit` 1 to 100; for a guest `state` and `guesses_used` are `null` and the browser fills them (AC-63).
- **M1-36 (merge):** `POST /v1/games/{slug}/progress/merge`, at most 500 entries per request, so send larger histories in chunks; repeating is safe (AC-61, AC-62); rejected entries come back with `date`, `variant`, `code`.
- **M1-37 (countdown):** `GET /v1/clock` (`now`, `today`, `next_reset`); use the offset from `now` for display only (AC-69).
- **M1-40 (CSP):** add `media-src` for the object-storage origin (SPEC-02 `:446`).
- **Production proxy (Phase 4):** like the Vite proxy, it must pass `Origin` and `Referer` through unchanged.

## Skills for implementer

Project skills are in `my-list-fe/.claude/skills/`. If the implementer runs from the platform folder, read the `SKILL.md` files directly. No skill covers Orval, TanStack Router or TanStack Query: use `docs` against the installed versions (Orval 8.45, `@tanstack/react-router` 1.170, `@tanstack/react-query` 5.102, axios 1.20, Vite 8.2).

| Files | Load | Why |
|---|---|---|
| Every code change | `shvab:karpathy-guidelines` | Small, surgical diffs; state assumptions |
| `src/api/generated/**` (G PRs), `orval.config.ts` (read only) | `docs` | **Gap:** no Orval skill. Regenerate only; never edit |
| `src/features/auth/session-guard.ts`, `src/features/games/queries.ts`, `src/routes/_app/index.tsx`, `src/routes/_app/games/$slug.tsx` | `docs`, `shvab:react-best-practices` | **Gap:** no TanStack or axios skill. Check interceptor success/error handlers, `ensureQueryData`, async `beforeLoad` and `notFoundComponent` in the installed versions |
| `src/features/games/known-games.ts` (`useKnownGames`), `src/components/app-sidebar.tsx` | `react-state-patterns`, `react-hooks-and-effects`, `shvab:react-best-practices` | Derive the nav from the query, never copy it into state |
| `src/i18n/locales/*.json`, `vite.config.ts` | none | **Gap:** no skill. Follow `CLAUDE.md:97-100` for catalogues |
| `src/**/*.test.ts(x)`, `src/test/*` | `shvab:react-testing-library` | Router harness, fake backend, jsdom shell tests |
| `CLAUDE.md` | `shvab:no-ai-slop` | The owner wants plain, short sentences |

Not assigned: `shvab:zod` (no schema changes), `react-component-api` and `react-rendering-and-perf` (no new component or boundary).

## Verification

Run in `/home/alexandr/Developer/MyList project/my-list-fe`.

**Gate for every PR** (what CI runs):
- `npm run lint`, `npm run format:check`, `npm run build`.
- The scoped tests named below. CI runs `npm test` on every PR anyway; run it locally once for F2 and F3, which touch shared code.
- api-types check: `API_SPEC=https://raw.githubusercontent.com/oleksandr-shvab/my-list-be/main/openapi/openapi.json npm run api:generate && git status --porcelain -- src/api/generated` prints nothing.

**Per PR:**
- **G-M1-xx:** the api-types check; `git diff main --stat` shows only `src/api/generated/`; `git diff main -- src/api/generated/api.ts | grep '^-' | grep -v '^---'` shows no removed line except the regenerated header, else stop (breaking change); `npm test`.
- **F1:** `npx vitest run src/i18n/catalogues.test.ts src/lib/error-messages.test.ts`. **Manual Origin check** (after backend M1-41 is on the local backend checkout; backend on `http://localhost:8000`, `npm run dev`):
  1. `curl -s -o /dev/null -w '%{http_code}\n' -X POST http://localhost:5173/api/v1/auth/logout -H 'Origin: http://localhost:5173'` prints `204` (the proxy kept `Origin`);
  2. the same without the `Origin` header prints `403`, and with `-H 'Origin: https://evil.example'` prints `403` with `"code":"csrf_origin_mismatch"` in the body (add `-s` and drop `-o` to see it);
  3. in a browser at `http://localhost:5173`: log in, log out, register, forgot password; all work (DoD local item 9). DevTools Network shows `Origin: http://localhost:5173` on each POST;
  4. at `http://127.0.0.1:5173`, the login form shows the `csrf_origin_mismatch` text in English, and in Russian after switching.
- **F2:** `npx vitest run src/test/routing.test.ts src/features/auth`, then `npm test`. Review pass (`code-review`, `medium`).
- **F3:** `npx vitest run src/features/games src/test`, then `npm test`. Manual, with the dev seed (backend `CLAUDE.md` after M1-10): the sidebar shows "Game Guesser"; stop the backend and reload: the sidebar still shows it and `/` still loads; set the game's `is_enabled` to false in the local database (or stop the seed from creating it), wait 5 minutes or reload: no game entry, `/` and `/games/game-guesser` show "Unknown game" inside the layout.

**Phase 1 DoD, frontend part (owner, after the last G PR):** the api-types job is green on `main` against the final snapshot; `npx vitest run src/i18n/catalogues.test.ts` passes; manual Origin check 1-3 above passes.

## Risks

- **Red `api-types` window after each backend PR.** Mitigation: the G PR is prepared from the sibling checkout on the backend branch (`orval.config.ts:5` reads `../my-list-be/openapi/openapi.json`) and pushed right after the backend merge; the owner merges the backend PR only when it is ready.
- **Ten small G PRs.** Tedious, not risky. If two backend PRs merge back to back, one G PR may cover both; its title names both tasks.
- **A future proxy edit drops `Origin`.** Every POST from dev would get 403. Mitigation: the `vite.config.ts` comment and the `CLAUDE.md` line (F1); the manual check fails loudly.
- **Logout under a wrong origin** (`127.0.0.1`, preview on 4173): the request gets 403 but the frontend signs out locally (`mutations.ts:73-80`), so a reload shows the user again. Only on non-allowed origins, which F1 documents. Not changed.
- **F2 drops the game view query that just answered** (`signOutLocally` removes all other queries), so a mounted Phase 2 query fetches once more as a guest. Accepted: one extra request, and it is the right state.
- **F2 reads response bodies in an interceptor.** Kept narrow: only 2xx, only `/v1/games/` paths, only a top-level boolean `false`, and only while a user is cached.
- **F3 makes game pages wait for `GET /v1/games`.** A slow backend delays the game screen (the layout and nav still show). A never-answering call would hold the route on its pending state; axios has no timeout today (`api-client.ts:54-57`). Mitigation: `retry: false`, the 5-minute cache, and the response is `public, max-age=300`. If this shows up in practice, read the list without waiting and check the slug in the component instead (Open point 3).
- **F3 changes what the harness answers by default.** Existing router and shell tests could shift. Mitigation: the default games reply lists `game-guesser`, which matches today's registry.
- **Russian texts** are mine and not reviewed. Mitigation: D6 reviewer before launch; one file to change.

## Rollback

- Each PR is one squash commit on `main`; roll back with a revert PR (`git revert <sha>`).
- A G PR is reverted only together with its backend PR (backend first), or `api-types` turns red again.
- F1: revert restores the old `CLAUDE.md` line and removes the texts; the backend check stays, and the forms show `errors.unknown` for a 403.
- F2: revert brings back "401 only"; an expired session then shows the user until the next 401 (stats or merge) or reload.
- F3: revert brings back the static nav; a disabled game shows its placeholder screen. Revert F3 before any Phase 2 PR that relies on `useKnownGames`.
- Nothing in F1 to F3 stores data in the browser, so users need nothing.

## Open points

**Owner's answers (2026-11-02):** every default below is accepted as written, so each point is decided. The execution mode is one agent per PR, each checked by `plan-verifier`, and the owner merges.

1. **AC-7 and AC-8 in Phase 1 (F3) or in M1-30?** SPEC-02 tags them "(Frontend, M1-30)" but keeps them in its scope (`:382`). Default: **Phase 1, F3**, since it needs only `GET /v1/games`. Moving it to Phase 2 changes nothing else in this plan.
2. **AC-52 and AC-54 say "in the frontend's tests".** Default: **M1-34 builds the guest stats and runs those tables** (hand-off above), because the frontend computation does not exist before M1-34 and the Phase 1 DoD lists the tables only for the backend. Alternative: a small Phase 1 PR with a pure `computeStats` and the tables (about 0.4 day, no backend dependency), which pins the rule in both repos at the same time.
3. **Game routes wait for `GET /v1/games` (R-6).** Default: **yes**, with fallback on failure, `retry: false`, 5-minute cache. Alternative: do not wait; the page shows the game and flips to "Unknown game" when the list says so (a flash of the wrong screen, but no wait).
4. **`signed_in: true` while the page shows a guest** (signed in in another tab). Default: **nothing in Phase 1**; M1-32 and M1-36 decide, since it touches local guest progress and merge.
5. **Texts for the reused codes `validation_error` and `not_found` (R-3).** Default: **add them in F1**.
6. **Russian texts** of F1: to be checked by the D6 reviewer, as in Phase 0.
7. **`npm run preview` on port 4173 is not an allowed origin**, so its POSTs get 403 after M1-41. Default: **document only** (F1). A developer who needs it adds `http://localhost:4173` to the local `BACKEND_CORS_ORIGINS` in the backend `.env` (allowed in `local` by AC-86).
8. **For the backend plan, not the owner:** logout has no body and must not get 415 (AC-76 wording); the Origin check compares against the allowed list, not `Host`; the "Games" section of `CONTRACTS.md` should state the frontend's reaction to `signed_in: false` (F2 step 5).

## Traceability

| Item | What | PR, step | Checked by |
|---|---|---|---|
| AC-7 | Nav shows only games both sides know, never crashes | F3.2, F3.4 | `known-games.test.ts`; shell test; router test |
| AC-8 | Fallback to the registry on failure; `/` "Unknown game" when the default is missing | F3.1-F3.3 | router tests; shell test; F3 manual |
| AC-8 (screen error) | Each game screen shows its own error | Hand-off M1-30 | Phase 2 |
| AC-42 | `signed_in: false` → signed out | F2.1 | router tests (F2.4); review |
| AC-52, AC-54 | Streak and stats tables in the frontend's tests | Hand-off M1-34 (Open point 2) | Phase 2 |
| AC-75 | New codes in both catalogues | F1.1, F1.2 | `catalogues.test.ts` |
| AC-79 | Client regenerated with each snapshot | G-M1-xx | api-types job |
| AC-86 (edge cases) | Dev `Origin` reaches the backend; `127.0.0.1` refused | F1.4, F1.5 | manual Origin check 1-4 |
| AC-89 | `csrf_origin_mismatch` in EN and RU | F1.1, F1.3 | `error-messages.test.ts`; manual check 4 |
| DoD local 9 | Login from the frontend still works | F1 | manual Origin check 3 |
| DoD CI frontend | api-types green; catalogues have the codes | last G PR; F1.2 | CI; `catalogues.test.ts` |
| AC-78 | `CONTRACTS.md` "Games" and CSRF rule | Backend plan (F2.5 checks one sentence) | backend PR review |
| SPEC-01 edge case (`:215`) | Backend and frontend game lists disagree | F3 | as AC-7, AC-8 |
