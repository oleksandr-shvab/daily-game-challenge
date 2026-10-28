# Phase 0 frontend: rename, optional login, game routes, sidebar nav — Implementation Plan

Status: draft, 2026-10-28. Scope: the frontend repo `my-list-fe/` (own git, GitHub `oleksandr-shvab/my-list-fe`, trunk-based, one PR per step). The backend plan is `plans/01-phase-0-backend.md` (PRs B1, B2, B3). Line numbers below were checked against frontend `main` at `227ce08`.

## Source requirements

- Spec: `specs/01-phase-0-rebrand-optional-login-shell.md` (SPEC-01, agreed, owner's answers Q1 to Q16). Where older text in `MILESTONE-1.md` or the research report differs, the "Owner's answers" table wins.
- Tasks: `MILESTONE-1.md` M1-01, M1-02, M1-03, M1-04, M1-06, M1-07 (frontend side), and the frontend parts of M1-05 and M1-08.
- Acceptance criteria this plan covers: AC-1 to AC-6, AC-7 (frontend regeneration), AC-8 (frontend package name only), AC-9 to AC-70 except AC-8b. The traceability table at the end maps each one to a step.
- Not in this plan (backend plan): the API title itself (AC-7, B2), backend and database names (AC-8, B1), AC-8b, `CONTRACTS.md` line 1, lines 36-39 and the "API types" section (backend hand-off H3), backend docs and skills.

**State of the code (checked 2026-10-28):**
- PR #9 (`c3-i18n`) is merged on GitHub: `main` is `227ce08`, merged 2026-10-27 15:09 UTC. Nothing waits for it. The local clone is stale: it is checked out on `c3-i18n` and local `main` is still `85091cb`. Before F1: `git fetch origin && git switch main && git pull --ff-only`.
- Backend `main` still says `"title": "FastAPI"` in `openapi/openapi.json` (read through the GitHub API on 2026-10-28). So the frontend client cannot be regenerated yet (F0 waits).
- The root `CLAUDE.md` has no AC-57 leftovers (`grep` for all six words gives no output). No change there.
- The frontend has no `LEARNINGS.md`.

## Clarifications & recommendations

No questions could be asked (this planner runs as a subagent). Facts were checked in the code; my judgment calls are marked **R-n**. Questions for the owner are under "Open points".

Facts that shape the design (all verified):
- An unknown path such as `/lists` is not matched by the pathless `_app` layout. I ran the installed router (`@tanstack/react-router` 1.170.32, `router-core` 1.171.27) in memory: `/lists` gives only the `__root__` match, so the not-found screen would render without the layout. A splat route `_app/$` that throws `notFound()` keeps it inside the layout. `notFound()` thrown in a `games/$slug` or `$date` route's `beforeLoad` also stays inside `_app`. Router paths are case-insensitive: `/LOGIN` matches `/login`.
- TanStack `Link` adds `aria-current="page"` itself when active, after the props you pass (`node_modules/@tanstack/react-router/dist/esm/link.js:346`, `:355-358`).
- The phone sidebar is a Radix Dialog opened by a plain button, not by `Dialog.Trigger`. On close Radix focuses `triggerRef`, which is empty here (`node_modules/@radix-ui/react-dialog/dist/index.mjs:154-157`), so focus does not go back to the sidebar button by itself. The focus trap ends as soon as the panel closes (`index.mjs:152`).
- `SidebarInset` renders `<main>` (`src/components/ui/sidebar.tsx:304-315`). Today the header sits inside it (`src/routes/_app.tsx:36-40`), so it is not a banner landmark.
- The vendored sidebar has fixed English screen-reader texts: the phone panel title "Sidebar" and its description (`sidebar.tsx:197-200`, not reachable by props), "Toggle Sidebar" in the trigger (`:274`, can be overridden with `aria-label`) and in the rail (`:286`, `:289`, can be overridden by props).
- `routeTree.gen.ts` is committed. `npm run build` runs `tsc -b` first (`package.json:8`), and `tsc` fails on a stale tree after a route file is added, moved or deleted. Regenerate it first with `npx vite build` (the router plugin rewrites it) or by starting `npm run dev` once.
- Test files must not live in `src/routes/`: the router plugin would treat them as routes. Router tests go in `src/test/`.
- `/auth/me` today: root `beforeLoad` awaits it and blocks every page (`src/routes/__root.tsx:13-28`). A signed-out visitor is sent to `/login` by `_app.tsx:15-19`. The 401 interceptor clears the Zustand store only (`src/features/auth/session-guard.ts:5-13`), so the cached `/auth/me` result restores the signed-in state on the next navigation (research section 2, reproduced there).

Recommendations:
- **R-1. One source of truth for the session (Open point 2).** The `/auth/me` query in the TanStack Query cache becomes the only session state. Its data is `User` (signed in) or `null` (guest, from a 401). A query error means "unknown" (network or 5xx). The Zustand auth store (`src/features/auth/store.ts`) is deleted. Reason: the stale-cache bug comes from two copies of the same server state, and `CLAUDE.md:58` already says Zustand is only for state with no server counterpart. Zustand stays in the project for `use-theme.ts`.
- **R-2. A different PR split than suggested.** (a) The API client regeneration is its own small PR, F0, merged right after backend B2, not in the last PR: from the moment B2 merges, the frontend `api-types` job fails for every PR until the regenerated client is on `main` (`.github/workflows/ci.yml:56-75`; backend hand-off H2). The package rename joins F0 because it also waits for the backend (hand-off H1, B1 merges before B2). (b) Docs are not left to the end. F1 removes the wrong text from `CLAUDE.md` (item/list tracker, `field_schema`, image uploads), because every later implementer reads that file. Each later PR updates the `CLAUDE.md` section it changes. F4 does the final AC-57 and AC-60 check.
- **R-3. In-layout not-found** through `src/routes/_app/$.tsx` (splat) plus a `notFoundComponent` on the game routes (facts above).
- **R-4. Per-game error boundary as a component, not a route option.** A small class boundary around the lazily loaded screen, inside the game screen host. It works the same on `/` and on `/games/...`, which is what `ARCHITECTURE.md:121` asks ("Wrap each game module in its own error boundary").
- **R-5. Desktop collapse control.** The sidebar keeps its icon-collapse mode and the `sidebar_state` cookie (AC-38). Today the only keyboard-visible toggle is in the header that Phase 0 removes on desktop. Add the sidebar toggle as the last item of the sidebar footer at 768 px and wider, after the account area, so the AC-27a order of the named items stays.
- **R-6. Auth pages when `/auth/me` fails with a network error or 5xx:** show the login, sign-up or forgot-password page anyway. AC-22 asks them to wait; AC-24 does not say what to show after a failure.
- **R-7. Phones:** the "Games" navigation region exists while the sidebar panel is open. With the panel closed, the slim header shows the sidebar button that opens it. I read AC-63 this way.
- **R-8. AC-61 exception:** the language buttons keep the codes "EN" and "RU" (`src/components/language-switcher.tsx:6`). They are language codes, the same in both languages, and the button `title` is already translated.
- **R-9. Favicon:** the letter "D" drawn as a path (not a font glyph) on a rounded square in the light-theme primary colour (`src/index.css:29`). The sidebar brand square uses the same letter.
- **R-10. Brand link on `/`:** it gets `aria-current="page"` from TanStack on `/` because it points to the current page. AC-30 counts game entries only, so this is allowed.
- **R-11. Registry check extra:** also check that `order` values are unique, so the nav order is never ambiguous. Not required by AC-50 or AC-51; it costs one line.
- **R-12. "Session expired" message** is a toast (sonner, already used for the reset flow at `src/features/auth/mutations.ts:95`), not a new search parameter, so nothing new appears in URLs.

## Execution mode

- **Recommended: multi-agent, one PR at a time.** For each PR (F1, F2, F3, F4): one `implementer` run for that PR's section only, then `plan-verifier` against that PR's acceptance checks, then the owner merges. Add a review pass (`code-review` at `medium` effort) after F2 (security: redirect validation, 401 handling, session state) and after F4 (accessibility and layout). F0 runs whenever backend B2 is merged and must be the next frontend merge after it. `shvab:implement-plan` can drive implementer, plan-verifier and the review loop for one PR section.
- Why not one agent for everything: F2 and F4 change shared layout and auth code; a check between PRs catches mistakes before the next PR builds on them.
- **Owner's choice (2026-10-28): one agent per PR, each checked by `plan-verifier`,** as recommended here, with the review passes after F2 and F4.

## Assumptions about the backend

- **Before F0 starts:** backend B1 (package and database rename) and B2 (title) are merged on backend `main`, and `https://raw.githubusercontent.com/oleksandr-shvab/my-list-be/main/openapi/openapi.json` has `info.title` "Daily Game Challenge API". Check: `curl -s https://raw.githubusercontent.com/oleksandr-shvab/my-list-be/main/openapi/openapi.json | python3 -I -c 'import json,sys; print(json.load(sys.stdin)["info"]["title"])'`.
- F0 may be prepared early from the sibling checkout with the B2 branch checked out (`npm run api:generate` reads `../my-list-be/openapi/openapi.json`, `orval.config.ts:5`), but it is committed and pushed only after B2 is on `main` (hand-off H2).
- F1 to F4 need no backend change. They rely on today's backend behaviour listed in the backend plan, hand-off H5: `401 not_authenticated` for a missing or unknown session, problem details with `request_id` for other failures, `204` on logout even when the session is gone, and a reset that ends all sessions of the reset account.
- `CONTRACTS.md`: this plan does not touch line 1, lines 36-39 or the "API types" section (hand-off H3). F2 changes one sentence at lines 30-31 (platform repo, local commit), see step 2.13.

## Modules affected

| Where | Why | PR |
|---|---|---|
| `src/api/generated/` (15 files), `package.json`, `package-lock.json` | New API title in the generated header; package name | F0 |
| `src/i18n/locales/en.json`, `ru.json`, `src/i18n/catalogues.test.ts` | Brand, tagline, removed and new keys | F1 to F4 |
| `index.html`, `public/favicon.svg` | Static title, letter mark, storage-safe theme script | F1, F2 |
| `src/routes/` | Lists removed, splat route, public layout, `_account` guard, game routes, titles | F1 to F4 |
| `src/features/auth/` | Session model, redirect validation, guards, 401 handling, account area | F2, F4 |
| `src/features/games/` (new) | Registry, screen host, error boundary, placeholder screen | F3, F4 |
| `src/components/` | Sidebar content, brand link, phone header, skip link, error screens; `ui/dropdown-menu.tsx` added by the CLI; one small edit in `ui/sidebar.tsx` (Open point 4) | F1, F4 |
| `src/lib/`, `src/hooks/use-theme.ts`, `src/main.tsx`, `src/router.ts` (new) | Page titles, UTC dates, query client and router factories, storage guard | F1 to F3 |
| `src/test/` (new) | Router tests in Node with the real route tree | F2, F3 |
| `src/index.css` | Scroll padding under the phone header | F4 |
| `CLAUDE.md`, `README.md`, `.claude/skills/dynamic-category-schema/`, `docs/specs/password-reset-update.md` | Leftovers, current shell description | F1 to F4 |
| Root `CLAUDE.md` | Checked only: clean | none |
| Root `CONTRACTS.md` lines 30-31 | One sentence about when the frontend calls `/auth/me` | F2 |

## Architectural constraints

From `my-list-fe/CLAUDE.md` (line numbers on `main`):
- `src/components/ui/` is vendored by the shadcn CLI: "treat as vendored — don't hand-edit beyond what the CLI generates" (`CLAUDE.md:44`; also `.prettierignore:3-4`). Add components with `npx shadcn@latest add <name>`; style `radix-nova` (`components.json:3`).
- Routes are file-based, one file per route; `routeTree.gen.ts` is generated and never hand-edited (`CLAUDE.md:56`).
- "Anything that touches the API goes through TanStack Query; Zustand only for state with no server counterpart" (`CLAUDE.md:58`).
- Client-side validation is a convenience, not a security boundary (`CLAUDE.md:59`). The route guard is the same (spec, "Non-functional", Security).
- Never write user-visible text in a component; add keys to both catalogues; Russian plurals need four forms (`CLAUDE.md:71-72`).
- Unexpected errors go through `src/lib/report-error.ts`; Query retries only network, 5xx, 408 and 429; lazy chunk failures reload once (`CLAUDE.md:75`).
- Generated API code is never hand-edited; CI's `api-types` job compares it with the backend contract (`CLAUDE.md:50`; `CONTRACTS.md:117-128`).

From the platform:
- A boundary change covers both repos and `CONTRACTS.md` in one pass; regenerate types, do not hand-patch them; use `localhost`, not `127.0.0.1` (root `CLAUDE.md`, "Working across both repos").
- The forgot-password response must not be used to infer account existence (`CONTRACTS.md:46-49`) → AC-70.
- A reset ends all sessions of the account; the frontend must not assume an old session still works (`CONTRACTS.md:64-67`) → AC-19b.
- One error boundary per game module, so a crashing game leaves the nav working (`ARCHITECTURE.md:121`). Version skew: reload once on a failed lazy chunk (`ARCHITECTURE.md:123`).
- Repo folder and GitHub names stay, so `orval.config.ts:5` and `ci.yml:67` keep `my-list-be` (decision 26, `SPEC.md`). The game guesser stays English only (decision 32). Public game names are chosen before launch (decision 53). Sidebar stays (decision 64).
- Untrusted URL inputs and the `redirect` test table: spec section "Untrusted inputs".

## Approach

Every PR: branch from a fresh `main`, PR to `main`, all four CI jobs green (lint, build, test, api-types) before merge. Suggested branch names: `p0-f0-api-title`, `p0-f1-rename`, `p0-f2-optional-login`, `p0-f3-game-routes`, `p0-f4-sidebar-nav`.

### F0. API client title and package name (timed by the backend)

Starts only when B1 and B2 are merged on backend `main` (see "Assumptions about the backend"). It must be the next frontend merge after B2. Open frontend PRs rebase on it afterwards.

1. Regenerate exactly as CI does: `API_SPEC=https://raw.githubusercontent.com/oleksandr-shvab/my-list-be/main/openapi/openapi.json npm run api:generate`. Expected: 15 files under `src/api/generated/` change one header line each, `FastAPI` → `Daily Game Challenge API` (today at `src/api/generated/api.ts:4`). If any other line changes, stop and report: the backend changed more than the title.
2. `package.json:2`: `"name": "daily-game-challenge-fe"` (proposed name, Open point 1). Update the lockfile without touching `node_modules`: `npm install --package-lock-only --ignore-scripts`. Expected diff: `package-lock.json:2` and `:8` only.
3. Do not change `orval.config.ts:5` or `.github/workflows/ci.yml:67` (repo paths stay, decision 26).

Acceptance F0: `api-types` job green; `npm ci` works; the diff is the 15 header lines plus the two name lines in each package file. AC-7 (frontend half), AC-8 (frontend name).

### F1. Rename, remove Lists, page titles, favicon, leftovers in docs

1. **Catalogues** (`src/i18n/locales/en.json`, `ru.json`; same keys in both):
   - `app.name` (`en.json:2`, `ru.json:2`): "Daily Game Challenge" in both (Latin in Russian, AC-6).
   - Add `app.tagline`: EN "Daily puzzle games", RU "Ежедневные игры-загадки" (Q8).
   - `profile.account_description` (`en.json:134`, `ru.json:142`): EN "Your account details.", RU "Данные вашего аккаунта." (no brand, so no Russian declension problem).
   - Remove `nav.lists` (`:5` in both), the whole `home` block (`en.json:116-126`, `ru.json:124-134`) and the whole `lists` block (`en.json:127-130`, `ru.json:135-138`). Keep `nav.home` until F4.
2. **Static page:** `index.html:7` `<title>Daily Game Challenge</title>` (AC-2). `lang="en"` stays; `src/i18n/index.ts:16-26` sets it at runtime.
3. **Favicon:** replace `public/favicon.svg` (the Vite logo) with the letter mark of R-9. `index.html:5` stays.
4. **Brand link:** new `src/components/brand-link.tsx`: a `Link` to `/` with the letter mark (`aria-hidden`) and `t('app.name')`. Use it in the sidebar header (`src/components/app-sidebar.tsx:43-50`, replacing the "M" square at `:45-47`) and in `src/features/auth/components/auth-page.tsx:4-11` at the top start corner (AC-27b, Q15). The language switcher stays at the end corner (`auth-page.tsx:7`).
5. **Remove Lists (AC-9, AC-10):** delete `src/routes/_app/lists.tsx`. In `app-sidebar.tsx` remove the `/lists` item (`:24`) and the `ListChecks` icon import (`:3`); keep Home until F4. Rewrite `src/routes/_app/index.tsx` as a neutral placeholder: heading `app.name`, text `app.tagline`, no cards, no user email (spec "Task dependencies" item 5). Delete `src/components/quick-action-card.tsx`; its only user was `index.tsx:5`, and its hard-coded "Go there →" (`:49`) goes with it.
6. **In-layout not-found (AC-10, AC-48):** add `src/routes/_app/$.tsx` (splat). Its `beforeLoad` throws `notFound()`; its `notFoundComponent` is `NotFoundScreen`. In `src/components/error-screen.tsx` drop `min-h-svh` (`:12`, `:34`) so both screens sit centred in the `_app` content area and still look right when the router renders them alone. Keep `defaultErrorComponent` and `defaultNotFoundComponent` (`src/main.tsx:36-37`).
7. **Page titles (AC-3, AC-4):** new `src/lib/page-title.ts` with:
   - a `staticData` type augmentation for TanStack Router: `pageTitle`, a catalogue key typed with i18next's key type so `tsc` rejects a wrong key;
   - a pure resolver: from the current matches, take the deepest `pageTitle`; if any match has status `notFound`, use `error_screen.not_found_title`;
   - a pure formatter: "{page name} | {app.name}", or `app.name` alone when there is no page name;
   - a hook `useDocumentTitle()` that sets `document.title` in an effect that depends on the resolved key and the current language. Call it in `RootComponent` (`src/routes/__root.tsx:38-45`).
   Titles from keys only, so the reset token can never reach the title. Route keys in F1: `/` → `app.tagline` (until F3), `/profile` → `profile.title`, `/login` → `auth.login.title`, `/register` → `auth.register.title`, `/forgot-password` → `auth.forgot.title`, `/reset-password` → `auth.reset.title`.
8. **Tests:** in `src/i18n/catalogues.test.ts` (`:21-41`) add: no value in either catalogue contains "MyList"; no key under `lists`, `home` or `nav.lists`. New `src/lib/page-title.test.ts`: formatter in English and Russian (switch with `i18n.changeLanguage`), resolver with hand-made match lists (key, no key, not-found).
9. **Route tree:** `npx vite build`, then commit `src/routeTree.gen.ts`. Check `npm run format:check` still passes for it.
10. **Docs and skills (AC-57, AC-58, AC-59, part of AC-60):**
    - Delete `.claude/skills/dynamic-category-schema/` (whole folder). No other frontend skill names it (checked with `grep`).
    - `CLAUDE.md`: line 7 → "frontend of Daily Game Challenge"; delete lines 25-35 (the "item-list-frontend" heading, tracker description, old backend name and old `/auth/...` path text) and rewrite "This repo" in three lines from `CONTRACTS.md` "API base and routing"; delete line 49 ("Variable fields per category") and line 52 ("Image uploads"); line 21: remove `icons.svg` and `src/assets/` (neither is tracked); line 79: drop the wrong `src/routes/index.tsx` path and keep the CSS-variable note only if it is still true; line 83: drop "`field_schema` shape, image upload flow"; Commands (`:9-16`): add `npm run format`, `npm run format:check`, `npm run api:generate`. Line 51 (Auth) is rewritten in F2.
    - `README.md` (the Vite template, 73 lines): replace with a short real one: what the repo is (the frontend of Daily Game Challenge; backend repo `my-list-be`; contract in the platform folder's `CONTRACTS.md`), install (`npm ci`), run (`npm run dev` with the backend on `http://localhost:8000`; open `http://localhost:5173`, not `127.0.0.1`), check (`npm run lint`, `npm run format:check`, `npm run build`, `npm test`), regenerate the API client (`npm run api:generate`).

Acceptance F1: AC-1 to AC-6; AC-9 and AC-11; AC-10 for signed-in users (guests still go to login until F2); AC-27b; AC-57 (frontend files), AC-58, AC-59; `/lists` gone from `routeTree.gen.ts`.

### F2. Optional login

1. **Factories for tests and `main.tsx`:** move the `QueryClient` setup (`src/main.tsx:20-31`) to `src/lib/query-client.ts` and the router setup (`main.tsx:33-44`, including the `Register` declaration) to `src/router.ts`, with the history as an optional argument. `main.tsx` uses both, then installs the session guard (step 7). Remove the side-effect import at `main.tsx:12`.
2. **Session model (R-1):**
   - `src/features/auth/api.ts:34-36`: `getMe` returns `null` when the answer is a 401 (`ApiError` with status 401) and rethrows anything else. `meQueryOptions` (`queries.ts:8-15`) keeps `retry: false` and `staleTime: 'static'`, so a guest is not re-checked on every navigation.
   - New `src/features/auth/session.ts`: `useSession()` (states `pending`, `signed_in`, `guest`, `error`, plus `user`, `error` and a `retry` function, all derived from the query; no copy in state); `ensureSession(queryClient)` for guards (cached value or one fetch; throws on network or 5xx); `signOutLocally(queryClient)` (sets the `me` data to `null` and removes every other query); `isOnAccountOnlyPage(router)` (any current match has `staticData.accountOnly`); `finishLogout(queryClient, router)` (sign out locally, then go to `/` only from an account-only page). Plain functions, so router tests can call them without React.
   - Use `setQueryData(me, null)`, not `queryClient.clear()` or `removeQueries` on `me`: a mounted `useQuery` keeps reading a removed query object and would keep showing the old user.
   - Delete `src/features/auth/store.ts` and every import of it: `__root.tsx:6,16,19`, `_app.tsx:12,16`, `_app/index.tsx` (no longer reads the user after F1), `_app/profile.tsx:14,37`, `login.tsx:4,8`, `register.tsx:4,8`, `forgot-password.tsx:4,8`, `reset-password.tsx:12,19`, `app-sidebar.tsx:20,31`, `mutations.ts:21,32,70`, `session-guard.ts:2,9`.
3. **Root route** (`__root.tsx:13-28`): `beforeLoad` starts the `/auth/me` request without awaiting it (a prefetch never throws). Remove `pendingComponent: RootPending`; move its spinner markup (`:30-36`) into a small shared pending component used below. Public pages no longer wait (AC-21).
4. **Layout split (AC-12, AC-13, AC-22):**
   - `src/routes/_app.tsx:15-19`: delete the guard. The layout is public.
   - New `src/routes/_app/_account.tsx` (pathless): `staticData.accountOnly = true`; `beforeLoad` awaits `ensureSession`; a guest gets a thrown router `redirect` to `/login` with the search parameter `redirect` set to `location.href`; an error is rethrown, so `ErrorScreen` shows the request id inside the layout (AC-24); a `pendingComponent` (the spinner) shows if the answer is slow.
   - Move `src/routes/_app/profile.tsx` to `src/routes/_app/_account/profile.tsx`. The URL stays `/profile`. Read the user from `useSession()` instead of the store (`:14`, `:37`). After regeneration, check that the `createFileRoute('...')` id matches the new path.
5. **Redirect validation (AC-14 to AC-17):** new `src/features/auth/redirect.ts` with a pure `resolveRedirect(value, origin)`:
   - not a non-empty string → `undefined`;
   - resolve with the WHATWG `URL` against `origin` (catch parse errors) → `undefined` unless `url.origin === origin`;
   - take `pathname + search + hash` of the resolved URL, never the raw value;
   - `undefined` if the path, lower-cased and without a trailing slash, is `/login`, `/register`, `/forgot-password` or `/reset-password` (the router is case-insensitive, so `/LOGIN` is the login page).
   Use it in `validateSearch` of `src/routes/login.tsx` and `src/routes/register.tsx` with `window.location.origin` (same style as `reset-password.tsx:15-17`). A rejected value is dropped without a message (AC-17). The pages pass `redirect` to the forms. The forms keep it on their cross links: `login-form.tsx:104-109` (to `/register`) and `register-form.tsx:102-107` (to `/login`).
6. **Auth routes:**
   - `login.tsx:7-11`, `register.tsx:7-11`, `forgot-password.tsx:7-11`: `beforeLoad` awaits `ensureSession`; signed in → a thrown router `redirect` to `/` (AC-18); on an error, show the page (R-6). Add the shared spinner as `pendingComponent`.
   - `reset-password.tsx:18-22`: delete the `beforeLoad`. A signed-in user sees the form with the token (AC-19a).
7. **401 handling (AC-25, AC-26):** rewrite `src/features/auth/session-guard.ts` as `installSessionGuard({ queryClient, router })`, which adds the axios interceptor and returns a function that removes it (tests need that). On an `ApiError` with status 401, and only while the `me` data is a user:
   - call `signOutLocally`;
   - if `isOnAccountOnlyPage(router)`: show the toast `auth.session_expired` and call `router.invalidate()`, so the `_account` guard sends the user to `/login?redirect=<current page>` (AC-26a);
   - else do nothing more; the account area switches to the guest state (AC-26b).
   A failed login (401 `invalid_credentials`) happens while signed out, so it changes nothing.
8. **Mutations** (`src/features/auth/mutations.ts`):
   - `onAuthSuccess` (`:31-34`): set the `me` data only.
   - Login (`:36-47`) and register (`:49-60`): take the validated target as an argument; on success go to the target, or to `/` when there is none, with `router.history.push` (the pattern in TanStack's "Authenticated Routes" guide; the value is already validated). Replaces `navigate({ to: '/' })` at `:44` and `:57` (AC-14).
   - Logout (`:62-81`): call `finishLogout` in `onSettled` instead of `:70-72` (AC-20, Q14). Keep the error report.
   - Reset (`:89-99`): call `signOutLocally` before `navigate({ to: '/login' })`, because the backend ended the sessions (AC-19b; backend plan H5 and its Open point 6: do not wait for `/auth/me` to say 401).
9. **Account area, first version (AC-21, AC-23, AC-24, AC-32):** new `src/features/auth/components/account-area.tsx`, placed in the sidebar footer instead of `app-sidebar.tsx:78-115`:
   - `pending`: a `Skeleton` (`src/components/ui/skeleton.tsx`) of the same size as the guest buttons, so nothing jumps;
   - `error`: a "Retry" button that calls `retry`, with a short visible or screen-reader text that the sign-in check failed;
   - `guest`: "Log in" and "Sign up" links to `/login` and `/register`, each with the search parameter `redirect` set to the current location's `href`;
   - `signed_in`: the existing Profile link with the email and the Log out button (F4 turns this into the menu).
   Keep `closeMobileSidebar` (`app-sidebar.tsx:35-37`) on every link.
10. **Storage guard (AC-68):** `src/hooks/use-theme.ts:9` and `:32`: wrap `localStorage` access in `try/catch`, like `src/i18n/language.ts:13-18` and `:30-36`. The theme then works for the tab without being saved. `index.html:8-17`: wrap the inline script body in `try/catch`, so blocked storage cannot stop it.
11. **Catalogue keys** (both files): `nav.log_in` (EN "Log in", RU "Войти"), `nav.sign_up` (EN "Sign up", RU "Зарегистрироваться"), `nav.retry` (EN "Retry", RU "Повторить"), `nav.account_check_failed` (EN "Couldn't check your sign-in.", RU "Не удалось проверить вход."), `auth.session_expired` (EN "Your session has ended. Please log in again.", RU "Сеанс завершён. Войдите снова.").
12. **Tests** (write the 401 test first and see it fail on the old guard):
    - `src/features/auth/redirect.test.ts`: every row of the spec's `redirect` table (base `http://localhost:5173`), plus `/LOGIN`, `/login/`, `/reset-password?token=x` (rejected, so a token is never copied), a number, an array, and a value with a hash.
    - `src/test/browser-stubs.ts`: the minimal globals the route tree needs in Node: `window` and `self`, `window.location` with origin `http://localhost:5173`, `localStorage`, `matchMedia`, and a small `document` (`documentElement`, `cookie`, `getElementsByTagName`, `createElement`). Import it as the first import of each router test file, not as a global `setupFiles` entry, because `src/i18n/language.test.ts:12-14` calls `vi.unstubAllGlobals()`.
    - `src/test/router-harness.ts`: builds the real router from `src/router.ts` with `createMemoryHistory({ initialEntries: [path] })` and a fresh query client; replaces `apiClient.defaults.adapter` (as `src/lib/api-client.test.ts:12-22` does) with a fake that answers `/v1/auth/me` with a user, 401, 500, a network error, or a promise that never settles, and answers other endpoints as the test needs; installs and later removes the session guard.
    - `src/test/routing.test.ts`, one case each: guest `/` stays and `_app` is a success match (AC-12); guest `/profile` ends at path `/login` with search string `?redirect=%2Fprofile` (AC-13); signed-in `/profile` stays; signed-in `/login`, `/register`, `/forgot-password` end at `/` (AC-18); signed-in `/reset-password?token=abc` stays with `token` "abc" (AC-19a); guest and signed-in `/lists` give a not-found match inside `_app` (AC-10); `/login?redirect=%2F%2Fevil.com` gives `redirect` undefined and `/login?redirect=%2Fprofile` gives "/profile" (AC-15, AC-17); with `/auth/me` never answering, `router.load()` for `/` finishes and `/profile` does not (AC-21, AC-22); with `/auth/me` answering 500, `/` loads and the `_account` match is an error carrying the request id (AC-24); 401 mid-session on `/profile` (fake `update-password` answers 401) ends at `/login?redirect=%2Fprofile` with `me` data `null` (AC-25, AC-26a); 401 mid-session on `/` stays on `/`, and after a new navigation to `/` the `me` data is still `null` even though the fake `/auth/me` would answer with a user (AC-25, AC-26b, the research's stale-cache case); `finishLogout` from `/profile` ends at `/`, from `/` stays (AC-20); reset success leaves `me` data `null` (AC-19b).
13. **Docs:** `CLAUDE.md:51` (Auth): rewrite for R-1 (query as the session source, `useSession`, `ensureSession`, `installSessionGuard`, the `_account` guard, `redirect` validation) and add a "Tests" line (router tests live in `src/test/`, never in `src/routes/`). `docs/specs/password-reset-update.md`: add a three-line note under the title "Changed by SPEC-01 (Phase 0)": profile moved to `src/routes/_app/_account/profile.tsx`; a reset now also clears the signed-in state; the auth store was replaced by the `/auth/me` query. Leave the history text. Root `CONTRACTS.md:30-31` (platform repo, local commit, not a backend-owned line): "`GET /auth/me` returns the current user; the frontend requests it on every page load without blocking public pages, and treats a 401 as a guest."

Acceptance F2: AC-10 (guests), AC-12 for `/`, AC-13 to AC-26b, AC-68; the AC-69 storage search gives only the known sites; AC-70 review (no new text about accounts beyond "session ended").

### F3. Game registry, game routes, placeholder screen

1. **UTC dates (AC-44 to AC-46):** new `src/lib/utc-date.ts`: `todayUtc(now)` (`YYYY-MM-DD` from the UTC getters); `parsePuzzleDate(value, today)` (exact `^\d{4}-\d{2}-\d{2}$`, a real day checked by a round trip through `Date.UTC`, not after `today`; returns the date and an "is today" flag, or a failure); `formatPuzzleDate(date, language)` (`Intl.DateTimeFormat` with `dateStyle: 'long'` and `timeZone: 'UTC'`).
2. **Registry (AC-49 to AC-53, AC-56):**
   - `src/features/games/types.ts`: the entry type with exactly `slug`, `nameKey`, `order`, `isDefault`, `screen`; screen props with exactly `slug`, `date`, `isToday` (AC-52 enforced by the type).
   - `src/features/games/registry.ts`: one entry: slug `game-guesser`, name key `games.game_guesser.name`, order 1, default, `screen` = `React.lazy` import of the placeholder (AC-53). Helpers: find by exact slug, the default game, entries sorted by `order`.
   - `src/features/games/validate-registry.ts`: a pure check that returns a list of problems: not exactly one default; a slug that fails `^[a-z0-9]+(-[a-z0-9]+)*$`; a duplicate slug; a name key missing in the English or Russian catalogue; a duplicate `order` (R-11).
   - `src/features/games/game-guesser/placeholder-screen.tsx` (default export, so the lazy import is simple): an `h1` with the game name, the date from `formatPuzzleDate` in the current language, and `games.coming_soon` (AC-47). Phase 2 replaces only this file's entry in the registry (AC-56).
3. **Screen host and error boundary (AC-54, AC-55a):**
   - `src/features/games/game-error-boundary.tsx`: a class error boundary. Fallback inside the content area: `games.error` text and a "Try again" button (`error_screen.try_again`) that clears the error. Do not call `reportError` here; `createRoot`'s `onCaughtError` already reports caught errors (`src/main.tsx:49`).
   - `src/features/games/game-screen.tsx`: renders the entry's screen inside the boundary and a `Suspense` with a small loading text (`games.loading`). Key the boundary by slug and date, never by language.
   - Note: `React.lazy` keeps a failed import, so "Try again" cannot download a missing chunk again. The existing reload-once handler (`src/lib/version-skew.ts`) covers the deploy case. Accept this in Phase 0.
4. **Routes:**
   - `src/routes/_app/index.tsx` (`/`, AC-39, AC-42): `beforeLoad` returns the default game and `todayUtc()`; the component renders the game screen with `isToday` true. `staticData.pageTitle` marks "game name".
   - `src/routes/_app/games/$slug.tsx` (layout): `beforeLoad` finds the game by exact slug or throws `notFound()` (AC-43, case-sensitive); returns the game and today. `notFoundComponent`: `NotFoundScreen` with `games.unknown_game` and `games.unknown_game_text`. Its component renders an `Outlet`.
   - `src/routes/_app/games/$slug/index.tsx` (`/games/{slug}`, AC-40): today's screen.
   - `src/routes/_app/games/$slug/$date.tsx` (AC-41, AC-44, AC-45): `beforeLoad` runs `parsePuzzleDate` against the parent's today or throws `notFound()`. `notFoundComponent`: `NotFoundScreen` with `games.no_puzzle` and `games.no_puzzle_text`. Today's date gives the same props as `/games/{slug}`, with no redirect (AC-41b).
   - `src/routes/_app/games/$slug/archive.tsx` (AC-31): `games.archive_title` heading and `games.archive_coming_soon`. A static segment wins over `$date` (verified).
   - `NotFoundScreen` takes an optional title and text, and its link says `error_screen.go_home` (new text below) and goes to `/`.
     - Built differently (2026-10-28): `NotFoundScreen` keeps no props, because the router passes its own props to it and a title or text prop failed `tsc`. A new `NotFoundMessage` takes `titleKey` and `textKey`, and the game routes use it. The texts and the link are as planned. The plan-verifier flagged this as a contradiction; the behaviour is the same, so the plan now records the built shape.
   - "Today" is computed once per route load, so an open page keeps its date across 00:00 UTC (spec edge case; rollover is M1-32).
5. **Page titles:** extend `src/lib/page-title.ts`: the "game name" marker resolves to the `nameKey` of the game from the `slug` param, or of the default game on `/` (AC-3); the archive route uses `games.archive_title`.
6. **Catalogue keys** (both files; Russian texts to be checked by the reviewer of decision D6): `games.game_guesser.name` "Game Guesser" in both (Open point 5); `games.coming_soon` (EN "This game is coming soon.", RU "Эта игра скоро появится."); `games.puzzle_date` (EN "Puzzle for {{date}}", RU "Загадка на {{date}}"); `games.archive_title` (EN "Archive", RU "Архив"); `games.archive_coming_soon` (EN "The archive is coming soon.", RU "Архив скоро появится."); `games.unknown_game` (EN "Unknown game", RU "Неизвестная игра"); `games.unknown_game_text` (EN "There is no game at this address.", RU "По этому адресу нет игры."); `games.no_puzzle` (EN "No puzzle for this date", RU "Нет загадки на эту дату"); `games.no_puzzle_text` (EN "Check the date in the address, or play today's puzzle.", RU "Проверьте дату в адресе или сыграйте в сегодняшнюю загадку."); `games.error` (EN "This game ran into a problem.", RU "В игре произошла ошибка."); `games.loading` (EN "Loading the game…", RU "Загружаем игру…"). Change `error_screen.go_home` (`en.json:114`, `ru.json:122`) to EN "Go to today's puzzle", RU "К сегодняшней загадке".
7. **Tests:**
   - `src/lib/utc-date.test.ts`: with `vi.setSystemTime` and `process.env.TZ` set per case (restore after): 2026-10-28T04:30Z under `Etc/GMT+5` (23:30 local on the 27th) gives "2026-10-28"; 2026-10-27T22:00Z under `Europe/Moscow` (01:00 local on the 28th) gives "2026-10-27" (AC-46). `parsePuzzleDate`: `2026-10-01` ok; `2026-02-30`, `2026-02-29`, `2026-1-5`, `today`, ` 2026-10-01`, `2026-10-01x` fail; `2024-02-29` ok; today ok with "is today"; tomorrow fails (AC-44, AC-45). `formatPuzzleDate` in English and Russian.
   - `src/features/games/validate-registry.test.ts`: the real registry gives no problems; fixtures with zero defaults, two defaults, `Game-Guesser`, `game--guesser`, a duplicate slug, a key missing in Russian each give a problem (AC-50, AC-51); every entry's `screen` is a React lazy component (AC-53).
   - `src/test/routing.test.ts`, with the clock fixed: guest `/games/game-guesser`, `/games/game-guesser/2026-10-01`, `/games/game-guesser/archive` load inside `_app` with no redirect (AC-12); `/` and `/games/game-guesser` and `/games/game-guesser/<today>` give the same slug, date and "is today" in the leaf route context (AC-39 to AC-42); `/games/nope` and `/games/Game-Guesser` give a not-found at the `$slug` match (AC-43); `/games/game-guesser/2026-02-30`, `/2026-1-5`, `/today` and tomorrow give a not-found at the `$date` match (AC-44, AC-45); in every not-found case the `_app` match is a success (AC-48). Page-title resolver on `/` and `/games/game-guesser` gives `games.game_guesser.name` (AC-3).
   - Component tests (only if the owner accepts Open point 3): add `jsdom`, `@testing-library/react` and `@testing-library/user-event` as dev dependencies; DOM test files opt in with a `// @vitest-environment jsdom` first line, and `vitest.config.ts:13` keeps `node` as the default. Tests: the boundary shows the fallback when the screen throws, and "Try again" renders the screen again; the placeholder shows name, date and "coming soon", and keeps its DOM node when the language changes (AC-55a).
8. **Docs:** `CLAUDE.md` new section "Games": the registry contract (AC-49 to AC-52), "add a game = one registry entry", screens load lazily, one error boundary per screen, "today" is UTC, a game module never keys progress by language (AC-55b), routes list.

Acceptance F3: AC-3 (game pages), AC-12 (game routes), AC-31 (page), AC-39 to AC-56; `ls dist/assets | grep -i placeholder-screen` after `npm run build` shows a separate chunk (AC-53).

### F4. Sidebar navigation, phone header, accessibility, final docs check

1. **Account menu component:** `npx shadcn@latest add dropdown-menu`. Check that `src/components/ui/dropdown-menu.tsx` imports from `radix-ui` (not Base UI) and that `package.json` did not change.
2. **Vendored sidebar edit (Open point 4):** in `src/components/ui/sidebar.tsx:181-204`, let `Sidebar` take two optional texts for the phone panel's hidden title and description (defaults stay the CLI's English). Mark the lines with one comment, and list the change in `CLAUDE.md` next to the "vendored" rule. Nothing else in the file changes.
3. **Current game:** new `src/features/games/use-current-game.ts`: from the current matches, the game shown (slug param of a known game, or the default game on `/`) and whether the archive page is open. On `/profile` and not-found pages there is no current game.
4. **Sidebar content** (`src/components/app-sidebar.tsx`, AC-27a, AC-28 to AC-31, AC-38), in this order:
   - Header: `BrandLink`. Remove `ThemeToggle` here (`:51`; it moves to the footer).
   - A `nav` element labelled with `nav.games` that wraps: a `SidebarContent` with the game entries from the registry in `order` (one in Phase 0), and below it, outside the scrolling part, the archive link to `/games/{slug}/archive` for the current game, or the default game when none (AC-31).
   - Each game entry: a `Link` to `/games/$slug` with the exact-match active option (`activeOptions.exact`), plus `aria-current="page"` and `isActive` set by you when `use-current-game` says it is the game shown and the archive is not open. Exact matching stops TanStack from marking the entry on the archive page; your attribute covers `/` and `/games/{slug}/{date}` (AC-30; see the `link.js` fact above). An icon for icon-collapse mode (for example lucide `Gamepad2`) with the name as tooltip.
   - `SidebarContent` gets `className` that keeps scrolling in icon mode too (the vendored class sets `overflow-hidden` there, `sidebar.tsx:373`), so 8 entries can scroll (AC-36). When the current entry changes, scroll it into view with `block: 'nearest'`.
   - Footer: `LanguageSwitcher`, `ThemeToggle`, `AccountArea`, then the sidebar toggle at 768 px and wider (R-5), with the accessible name `nav.toggle_sidebar`. Pass the same label to `SidebarRail` (`sidebar.tsx:279-302` lets props override its English label).
   - Remove the Home entry and `navItems` (`:22-25`) and the `House` icon (AC-38). Keep `closeMobileSidebar` on every link.
5. **Account area, final** (`src/features/auth/components/account-area.tsx`, AC-32, AC-33, AC-66): signed in → a `DropdownMenu` whose trigger shows the email's first letter (`aria-hidden`) and the email (truncated), with the accessible name from `nav.account_menu` with the email; items "Profile" (`Link` to `/profile`) and "Log out" (`nav.log_out`, `nav.logging_out` while pending). Radix gives Enter, Space and Arrow Down to open, Escape to close and focus back to the trigger. Add a compact variant for the phone header: guest → "Log in" only; signed in → the same menu trigger as an icon-size button; pending → skeleton; error → Retry.
6. **Phone header:** new `src/components/phone-header.tsx`: one row, shown below 768 px only (`md:hidden`): sidebar toggle (`SidebarTrigger` with the accessible name `nav.toggle_sidebar`), `BrandLink` (truncates at 320 px), compact account area (AC-32, AC-33, AC-35). Controls 44 px tall where the row allows (`size-11`, AC-64). Sticky at the top only when the viewport is at least 500 px tall; below that it scrolls away (AC-37).
7. **Layout** (`src/routes/_app.tsx:31-48`):
   - First child: new `src/components/skip-link.tsx`, a link to `#main` that is visually hidden until focused. On activation it prevents the default jump (no `#main` in the URL) and focuses the main element (AC-62).
   - Replace `SidebarInset` (`:36`) with a plain wrapper `div` with the same layout classes (`sidebar.tsx:309` without the `inset` variant parts) plus `min-w-0`, so no long content causes side scroll (AC-67). Inside: `PhoneHeader` (a `header` element, not inside `main`, so it is the banner below 768 px, AC-63), then a `main` element with id `main` and `tabIndex` -1 that holds the `Outlet`.
   - Remove the old header (`:37-40`) and the `LanguageSwitcher` import (`:1`).
   - Focus return (AC-66): when the phone panel goes from open to closed, focus the phone header's sidebar toggle (read `openMobile` from `useSidebar`; keep a ref to the toggle). Needed because of the Radix fact above.
   - Keep `getStoredSidebarOpen` (`:25-29`) and the `sidebar_state` cookie (AC-38).
8. **CSS** (`src/index.css`, after `@layer base` at `:161-171`): below 768 px and at least 500 px tall, `scroll-padding-top` equal to the phone header height (56 px), so the header never hides the focused element (AC-65).
9. **Target sizes (AC-64):** at least 24 px everywhere (the smallest today is `Button size="sm"`, 28 px, `src/components/ui/button.tsx:27`). In the phone panel, game entries, archive link, language buttons, theme toggle and account controls are 44 px tall (`max-md:` classes on our components, not in `ui/`).
10. **Catalogue keys** (both files): `nav.games` (EN "Games", RU "Игры"; no word "navigation", AC-63), `nav.skip_to_content` (EN "Skip to content", RU "Перейти к содержимому"), `nav.toggle_sidebar` (EN "Show or hide the sidebar", RU "Показать или скрыть боковую панель"), `nav.sidebar_title` (EN "Site menu", RU "Меню сайта"), `nav.sidebar_description` (EN "Games, archive, language, theme and account.", RU "Игры, архив, язык, тема и аккаунт."), `nav.account_menu` (EN "Account: {{email}}", RU "Аккаунт: {{email}}"). Remove `nav.home`.
11. **Tests:** router tests stay green. Component tests only if Open point 3 is accepted: on `/`, `/games/game-guesser` and `/games/game-guesser/2026-10-01` exactly one game entry has `aria-current="page"`, and none on the archive page, where the archive link has it (AC-30); the skip link is the first focusable element and moves focus to `main` (AC-62); the account area shows skeleton, Retry, "Log in" plus "Sign up", or the menu button with the email in its name (AC-21, AC-24, AC-32, AC-33); the menu opens with Enter and closes with Escape with focus back on the trigger (AC-66). Without Open point 3, these are manual checks.
12. **Final docs check:** `CLAUDE.md` describes the current shell: public `_app` layout, `_account` guard, auth pages with their own layout, game routes and registry, sidebar and phone header, skip link, the one vendored edit, tests (AC-60). Every path it names exists (command in "Verification"). The AC-57 search gives no output. Optionally run `shvab:engineering-insights` to start `my-list-fe/LEARNINGS.md` with the non-obvious findings of this phase (unknown paths fall to the root without the splat route; Radix focus return without a trigger; mounted queries and `clear()`).

Acceptance F4: AC-27a, AC-28 to AC-38, AC-57 and AC-60 final, AC-61 to AC-67; the AC-69 search gives only the known sites; the owner's manual checklist passes.

## Skills for implementer

Project skills are in `my-list-fe/.claude/skills/`. If the implementer runs from the platform folder, read the `SKILL.md` files directly.

| Files | Load | Why |
|---|---|---|
| Every code change | `shvab:karpathy-guidelines` | Small, surgical diffs; state assumptions |
| `src/routes/**`, `src/router.ts`, `src/lib/query-client.ts`, `src/features/auth/session.ts`, `session-guard.ts`, `redirect.ts`, `mutations.ts` | `docs`, `shvab:react-best-practices` | **Gap:** no skill covers TanStack Router 1.170.32 or TanStack Query 5.102. Check route options, `notFound`, `redirect`, `staticData` and query methods in the installed source or the docs of that version |
| `src/components/*.tsx` (not `ui/`), `src/features/auth/components/*.tsx`, `src/features/games/**/*.tsx` | `react-component-api`, `react-state-patterns`, `shvab:react-best-practices` | Props and composition, `asChild` with shadcn/Radix, derived state (session state is derived, never copied), accessibility |
| `src/lib/page-title.ts` (hook), `src/hooks/use-theme.ts`, `src/routes/_app.tsx` (focus return), `src/features/games/use-current-game.ts`, the scroll-into-view effect | `react-hooks-and-effects` | Effects that sync with the DOM and browser APIs, dependencies, cleanup |
| `src/features/games/game-screen.tsx`, `game-error-boundary.tsx`, `registry.ts` | `react-rendering-and-perf` | Error boundaries, `lazy`, `Suspense`, keys that reset a subtree |
| `src/components/ui/dropdown-menu.tsx` (CLI), `src/components/ui/sidebar.tsx` (one edit) | `react-component-api` (shadcn/Radix part), `docs` (shadcn CLI) | Vendored files |
| `src/**/*.test.ts`, `src/test/*` | `shvab:react-testing-library` (its Vitest, mocking and async parts; all of it if Open point 3 is accepted) | Fake timers, global stubs, async router loads |
| `src/i18n/locales/*.json`, `index.html`, `public/favicon.svg`, `src/index.css` | none | **Gap:** no skill. Follow `CLAUDE.md:71-72` for catalogues |
| `CLAUDE.md`, `README.md`, `docs/specs/password-reset-update.md`, `CONTRACTS.md:30-31` | `shvab:no-ai-slop` | The owner wants plain, short sentences |

Not assigned: `shvab:zod`. Phase 0 adds or changes no Zod schema; `validateSearch` uses the pure `resolveRedirect`. Do not load `dynamic-category-schema`: F1 deletes it.

## Verification

Run in `/home/alexandr/Developer/MyList project/my-list-fe`. After any route file is added, moved or deleted, run `npx vite build` before `npm run build`.

**Gate for every PR** (what CI runs; all fast):
- `npm run lint`
- `npm run format:check`
- `npm run build` (type check with `tsc -b`, then the production build)
- the scoped tests named for the PR below; `npm test` once at the end of F2 and F4 (shared auth and layout code). CI runs `npm test` on every PR anyway.
- After F0 is on `main`, every PR also passes the api-types check: `API_SPEC=https://raw.githubusercontent.com/oleksandr-shvab/my-list-be/main/openapi/openapi.json npm run api:generate && git status --porcelain -- src/api/generated` must print nothing.

**Per PR:**
- **F0:** the api-types check above (prints nothing after the commit); `git diff main --stat` shows `src/api/generated` (15 files), `package.json` and `package-lock.json` only; `npm ci` succeeds.
- **F1:** `npx vitest run src/i18n/catalogues.test.ts src/lib/page-title.test.ts`. AC-5: `npm run build && grep -rIni 'mylist' dist index.html public src/i18n/locales` prints nothing. AC-57 (frontend files and root `CLAUDE.md`): `grep -rIn -E 'MyList|item-list|item_list|field_schema|custom_attributes|dynamic-category-schema' CLAUDE.md README.md .claude ../CLAUDE.md` prints nothing. `grep -n lists src/routeTree.gen.ts` prints nothing.
- **F2:** `npx vitest run src/features/auth src/test src/i18n`, then `npm test`. AC-69: `grep -rn -E 'localStorage|sessionStorage|document\.cookie|indexedDB' src --include=*.ts --include=*.tsx | grep -v '\.test\.'` shows only `src/hooks/use-theme.ts`, `src/i18n/language.ts`, `src/lib/version-skew.ts`, `src/components/ui/sidebar.tsx` and `src/routes/_app.tsx`.
- **F3:** `npx vitest run src/lib/utc-date.test.ts src/features/games src/test src/i18n/catalogues.test.ts`; after `npm run build`, `ls dist/assets | grep -i placeholder-screen` shows one file (AC-53).
- **F4:** `npm test`; the AC-57 search of F1; the AC-69 search of F2; paths named in `CLAUDE.md` exist: `grep -oE '(src|public|docs|\.github|\.claude)/[A-Za-z0-9_./$-]+' CLAUDE.md | sort -u | while read -r p; do [ -e "$p" ] || echo "missing: $p"; done` prints nothing (glob patterns, if any, are reviewed by hand). AC-61 review aid: `grep -rnE '>[^<{}]*[A-Za-z]{2,}[^<{}]*<' src/components src/features src/routes --include=*.tsx | grep -v '/ui/'` and check every hit is not user-visible text.

**Manual checklist for the owner** (after F4; the spec's "Definition of done"). Start the backend (see `my-list-be/CLAUDE.md`) and `npm run dev`; open `http://localhost:5173`.
1. Signed out, `/`: sidebar, "Game Guesser", today's UTC date, "coming soon". No login page. Tab title "Game Guesser | Daily Game Challenge".
2. Switch to RU: page and URL stay, tab title and texts change, no reload. No "MyList" anywhere, in both languages.
3. `/lists`, `/games/nope`, `/games/game-guesser/2099-01-01`: "not found" texts inside the layout, with a link to today's puzzle.
4. `/profile` signed out → login page; log in → back on `/profile`. "Log in" and "Sign up" in the sidebar carry the current page.
5. On `/`, open the account menu, "Log out": stays on `/`, the account area shows "Log in". Log out from `/profile`: goes to `/`.
6. DevTools, device toolbar at 360, 768 and 1280 px (and 320 px): the layout fits; in the console `document.documentElement.scrollWidth <= innerWidth` is `true`. Tab order on desktop: skip link, brand, game, archive, EN, RU, theme, account, sidebar toggle. On a phone: skip link, sidebar button, brand, "Log in"; in the open panel the desktop order; Escape closes the panel and focus is back on the sidebar button.
7. Slow and failed `/auth/me`: DevTools "Network request blocking" for `*/auth/me`, reload: the game shows, the account area shows "Retry", `/profile` shows the error screen with a reference. Throttle to "Slow 3G": the game shows before the account area fills in, and the account area keeps its size.
8. Session ended: sign in in two tabs; log out in tab B; in tab A on `/profile` submit the password form: login page with "Your session has ended", then back to `/profile` after login. The public-page case (AC-26b) is covered by the router test; Phase 0 has no API call on public pages to trigger it by hand.
9. Signed in, open a reset link (copy it from the backend log after "Forgot password" while signed out in another browser): the reset form shows with the token; after success you see the signed-out state and the login page.
10. Storage blocked: `chrome://settings/content/siteData`, add `http://localhost:5173` to "Not allowed to save data", reload: the app renders, theme and language switch, a reload forgets them.

**Left for Playwright (M1-50, later):** AC-36 with a test registry of 8 entries; AC-37 scrolling and landscape; AC-64 measured target sizes; AC-65 focus not covered; AC-67 at 320, 360, 768, 1280 px; keyboard order and menu keys (AC-27a, AC-66) if Open point 3 is not accepted; axe checks; AC-29 "no full reload".

## Risks

- **Frontend CI red window after backend B2.** Every frontend PR fails `api-types` until F0 is on `main`. Mitigation: F0 prepared early, merged first after B2; the owner merges B2 only when F0 is ready (backend hand-off H2).
- **Stale route tree.** `tsc -b` fails after a route file change. Mitigation: `npx vite build` first; commit `src/routeTree.gen.ts`.
- **Node router tests and import-time browser code.** `use-theme.ts:6,9,39`, `sonner`, `axios` and the router read browser globals at import. Mitigation: the stubs file imported first; F2's storage guard reduces what must be stubbed.
- **Removing the auth store touches 11 files** (list in step F2.2). Mitigation: all in F2, router tests written first, review pass after F2.
- **Mounted queries after `clear()`.** A mounted `useQuery` keeps reading a removed query. Mitigation: `setQueryData(me, null)`, never `clear()` for sign-out.
- **Open redirect.** A prefix check is not enough (`/\evil.com`, tab characters). Mitigation: URL resolution and origin comparison, the spec table as a unit test, review pass after F2.
- **Phone panel focus.** Radix does not return focus without a `Dialog.Trigger`. Mitigation: the focus-return effect in F4 step 7, manual check 6.
- **Vendored file edit** may be lost when the shadcn CLI updates `sidebar.tsx`. Mitigation: one marked block, listed in `CLAUDE.md` (Open point 4).
- **Icon-collapse mode** hides overflow in the vendored sidebar (`sidebar.tsx:373`). Mitigation: our `className` on `SidebarContent`; Playwright with 8 entries later.
- **Russian texts** are mine and not reviewed. Mitigation: decision D6 reviewer before launch; they are easy to change in one file.
- **Backend reset edge case** (backend plan, Open point 6): if a signed-in user resets another account's password, the frontend shows signed out although the cookie still works; a reload signs them in again. Accepted for Phase 0.

## Rollback

- Each PR is one squash commit on `main`. Roll back with a revert PR (`git revert <sha>`), newest first.
- F0: revert only together with backend B2 (backend first), or `api-types` turns red again (backend plan, "Rollback").
- F2: a revert brings back the login-required layout and the stale-cache bug. No stored data changes: Phase 0 adds no browser storage (AC-69), so users need nothing.
- F3, F4: revert in reverse order (F4 uses F3's registry and F2's account area).
- Platform repo: revert the local `CONTRACTS.md:30-31` commit if F2 is reverted.

## Open points

1. **Package name `daily-game-challenge-fe`:** confirmed by the owner on 2026-10-28 (F0 step 2).
2. **Session state (R-1), decided 2026-10-28: yes.** Replace the Zustand auth store with the `/auth/me` query as the only source. Recommendation: yes; it removes the stale-cache bug by design and matches `CLAUDE.md:58`. The alternative (keep the store and sync it in five places) also meets the ACs but keeps the bug's cause.
3. **DOM component tests in Phase 0, decided 2026-10-28: yes.** Add `jsdom`, `@testing-library/react`, `@testing-library/user-event` (three dev dependencies) in F3 for a few tests of the error boundary, current-entry marking, the account area and the menu keys. Recommendation: yes; otherwise these ACs have only manual checks until M1-50 in Phase 5. Without it, the plan still works: those items move to the manual checklist.
4. **One edit in the vendored `src/components/ui/sidebar.tsx`** (F4 step 2), so the phone panel's screen-reader title is translated (AC-61). Recommendation: allow it as one marked block and list it in `CLAUDE.md`. Without it, the panel title stays the English "Sidebar" in both languages.
5. **Game name:** "Game Guesser" in Latin letters in both catalogues until the public names are chosen (decisions 32 and 53). Recommendation: yes. A Russian label could suggest a Russian game, and the game stays English.
6. **AC-69 wording (spec already updated, 2026-10-28):** the app already stores a `sessionStorage` key `chunk-reload-attempted` (`src/lib/version-skew.ts:1`), set only after a failed chunk load. It is not new, but AC-69's list does not name it. Recommendation: add it to the spec's list; no code change.

## Traceability

"OP 3" means Open point 3: the component test exists only if the owner accepts it; otherwise the manual check covers it.

| AC | What | PR, step | Checked by |
|---|---|---|---|
| AC-1 | Brand from `app.name`, both languages | F1.1, F1.4 | catalogues test; manual 2 |
| AC-2 | Static title | F1.2 | AC-5 search; view source |
| AC-3 | Tab title per page | F1.7, F3.5 | `page-title.test.ts`; router test; manual 1 |
| AC-4 | Title follows language | F1.7 | `page-title.test.ts`; manual 2 |
| AC-5 | No "MyList" shipped; new favicon | F1.1-F1.3 | F1 `grep` of `dist`; catalogues test |
| AC-6 | Latin brand, Russian tagline | F1.1 | review of `ru.json` |
| AC-7 | Client regenerated from new title | F0.1 | api-types check |
| AC-8 | Frontend package name | F0.2 | `npm ci`; diff |
| AC-9 | No Lists page, entry, cards, texts | F1.1, F1.5; Home entry F4.4 | catalogues test; route tree `grep` |
| AC-10 | `/lists` in-layout not found, never login | F1.6, F2.4 | router test (guest and signed in) |
| AC-11 | Parity and type check pass | F1.1, F1.8 | catalogues test; `npm run build` |
| AC-12 | Public pages, no redirect | F2.4, F3.4 | router tests |
| AC-13 | Guest on `/profile` → `/login?redirect=` | F2.4 | router test |
| AC-14 | After login go to validated target | F2.5, F2.8 | `redirect.test.ts`; manual 4 |
| AC-15 | Same origin only, resolved path | F2.5 | `redirect.test.ts` (spec table) |
| AC-16 | Auth pages as target → `/` | F2.5 | `redirect.test.ts` |
| AC-17 | Bad value ignored silently | F2.5 | `redirect.test.ts`; router test |
| AC-18 | Signed in on auth pages → `/` | F2.6 | router test |
| AC-19a | Signed-in reset keeps token | F2.6 | router test; manual 9 |
| AC-19b | Reset success → signed out, `/login` | F2.8 | router test; manual 9 |
| AC-20 | Logout clears state; stay or `/` | F2.2, F2.8 | router test; manual 5 |
| AC-21 | Public page before `/auth/me`; placeholder | F2.3, F2.9 | router test; manual 7; component test (OP 3) |
| AC-22 | Account and auth pages wait | F2.4, F2.6 | router test |
| AC-23 | 401 → guest, no error | F2.2 | router test |
| AC-24 | Other failure → public works, Retry, error screen with id | F2.2, F2.4, F2.9 | router test; manual 7 |
| AC-25 | 401 mid-session → signed out, stays so | F2.2, F2.7 | router test (stale-cache case) |
| AC-26a | On account page → login with redirect, message | F2.7 | router test; manual 8 |
| AC-26b | On public page → stay | F2.7 | router test |
| AC-27a | Sidebar order, skip link | F4.4, F4.7 | manual 6; component test (OP 3); Playwright |
| AC-27b | Auth pages own layout, brand link | F1.4 | manual |
| AC-28 | Entries from registry, in order | F3.2, F4.4 | registry test; manual 1 |
| AC-29 | Entry opens `/games/{slug}`, no reload | F4.4 | manual; Playwright |
| AC-30 | Exactly one current entry | F4.3, F4.4 | component test (OP 3); manual |
| AC-31 | Archive link and "coming soon" page | F3.4, F4.4 | router test; manual |
| AC-32 | Guest: Log in, Sign up; phone header Log in; redirect | F2.9, F4.5, F4.6 | manual 4, 6; component test (OP 3) |
| AC-33 | Signed in: menu with email, Profile, Log out | F4.5, F4.6 | manual 5; component test (OP 3) |
| AC-34 | Language and theme for everyone, no reload | F4.4 (placement); existing behaviour | manual 2 |
| AC-35 | Sidebar beside content ≥ 768; phone header and panel | F4.6, F4.7 | manual 6 |
| AC-36 | Entry list scrolls inside, current in view | F4.4 | Playwright (8 entries) |
| AC-37 | Sidebar fixed; header sticky unless < 500 px tall | F4.6 | manual 6; Playwright |
| AC-38 | Lists and Home entries gone; cookie stays | F1.5, F4.4, F4.7 | review; manual |
| AC-39 | `/` default game today | F3.4 | router test |
| AC-40 | `/games/{slug}` today | F3.4 | router test |
| AC-41a/b | Date page; today same as `/games/{slug}` | F3.4 | router test |
| AC-42 | Same puzzle on `/` and default slug | F3.4 | router test |
| AC-43 | Unknown or wrong-case slug | F3.4 | router test |
| AC-44 | Bad date | F3.1, F3.4 | `utc-date.test.ts`; router test |
| AC-45 | Future date | F3.1, F3.4 | `utc-date.test.ts`; router test |
| AC-46 | Today in UTC | F3.1 | `utc-date.test.ts` (fixed clocks) |
| AC-47 | Placeholder: name, UTC date, coming soon | F3.2 | manual 1; component test (OP 3) |
| AC-48 | Not-found and game errors inside layout | F1.6, F3.3, F3.4 | router test (`_app` success) |
| AC-49 | Entry fields exactly | F3.2 | type; review |
| AC-50 | Exactly one default | F3.2 | registry test |
| AC-51 | Slug format, unique | F3.2 | registry test |
| AC-52 | Screen gets slug, date, is-today only | F3.2 | type |
| AC-53 | Game code loads when opened | F3.2 | registry test (lazy); build chunk check |
| AC-54 | Game crash → in-layout error, Try again | F3.3 | component test (OP 3), else manual (temporary throw, not committed) |
| AC-55a | Language switch keeps screen and state | F3.3 | component test (OP 3); manual 2 |
| AC-55b | Progress not keyed by language | F3.8 (`CLAUDE.md` rule) | review in Phase 2 |
| AC-56 | One entry `game-guesser`, default, placeholder | F3.2 | registry test |
| AC-57 | No leftovers (frontend files, root `CLAUDE.md`) | F1.10, F4.12 | F1 `grep` |
| AC-58 | Skill deleted | F1.10 | F1 `grep` |
| AC-59 | README | F1.10 | review |
| AC-60 | `CLAUDE.md` describes the shell; no missing files | F1.10, F2.13, F3.8, F4.12 | F4 path check |
| AC-61 | All texts from catalogues | every PR; F4.2 (OP 4) | F4 `grep` review aid; catalogues test |
| AC-62 | Skip link first, visible on focus, moves focus | F4.7 | manual 6; component test (OP 3) |
| AC-63 | One main, labelled Games nav, banner on phones | F4.4, F4.7 | manual; Playwright with axe |
| AC-64 | Targets ≥ 24 px, 44 px on touch | F4.6, F4.9 | manual; Playwright |
| AC-65 | Header never hides focus | F4.8 | manual; Playwright |
| AC-66 | Menu and panel keyboard, focus return | F4.5, F4.7 | manual 6; component test (OP 3) |
| AC-67 | No side scroll at 320 to 1280 px | F4.7 | manual 6; Playwright |
| AC-68 | Storage blocked still works | F2.10 | manual 10 |
| AC-69 | Nothing new stored | F2, F4 | AC-69 `grep` |
| AC-70 | No new account-existence leak | F2.7, F2.11 | review after F2 |
