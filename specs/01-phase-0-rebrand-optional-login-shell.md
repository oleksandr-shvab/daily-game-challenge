# Spec: Phase 0, the Daily Game Challenge shell   |   Spec ID: SPEC-01   |   Status: draft

Covers Milestone 1, Phase 0, tasks M1-01 to M1-07 (`MILESTONE-1.md` section 4). Written 2026-10-27.
Touches both app repos and the platform docs, so it lives in the root `specs/` folder.

## In short

1. The app is renamed from "MyList" to "Daily Game Challenge" everywhere a person can see it.
2. Login becomes optional. Guests see the whole site; only `/profile` needs an account.
3. A top bar replaces the sidebar: games, archive link, language, theme, and login or account menu.
4. `/`, `/games/{slug}` and `/games/{slug}/{date}` show one game screen (a placeholder in Phase 0), chosen through a small game registry.
5. The Lists feature and all MyList leftovers in docs, skills and config are removed.

## [NEEDS CLARIFICATION: open questions for the owner]

The owner has not answered these. Each has a recommended default, and the acceptance criteria below are written for that default.
If you choose differently, the listed criteria change. Q1 to Q11 come from the research report (its last section); Q12 to Q16 were found while writing this spec.

| # | Question | Recommended default | Why | Criteria affected |
|---|---|---|---|---|
| Q1 | D1 layout: top bar or the existing sidebar? | Top bar | Decision 4 says "nav bar"; 1 to 8 games fit a bar; on phones a sidebar hides the games behind a button (research section 5) | AC-27 to AC-38 |
| Q2 | What does `/lists` show after removal? | The normal "not found" screen | Cheapest; no user ever had lists data | AC-10 |
| Q3 | A signed-in user opens a password reset link. Keep the token? | Yes: show the reset form | Today the token is lost silently (research section 2, verified in code) | AC-19 |
| Q4 | What does `/games/{slug}/{future date}` show? `/games/{slug}/{today}`? | Future: not found. Today: same screen as `/games/{slug}`, no redirect, shared progress | Decision 5 (no redirect); M1-16 (past days only) | AC-41, AC-45 |
| Q5 | Source of the nav's game list in Phase 0? | A static frontend registry. `GET /v1/games` joins in Phase 1 | M1-10 is Phase 1; Phase 0 must not wait for it | AC-28, AC-49 |
| Q6 | May the public page start before `/auth/me` answers? What does a guest see if `/auth/me` fails on the network? | Yes, start at once. On a network failure the page still works; the account area offers "Retry" | Decision 3; speed of the first screen; a guest should never see an error page because of the account check | AC-21 to AC-24 |
| Q7 | Rename the frontend package name `my-list-fe` and the database name `item_list`? | Keep both | Decision 26 keeps repo names; both are invisible to players; renaming the DB needs every developer to rebuild the local volume | AC-8 |
| Q8 | Brand in Latin letters in Russian? Russian tagline? | Latin "Daily Game Challenge" in both languages. Tagline EN "Daily puzzle games", RU "Ежедневные игры-загадки" | Brands usually stay Latin in Russian UI (research section 7) | AC-1, AC-6 |
| Q9 | Show "Sign up" in the phone header? | No. Phones show "Log in" only; the login page links to sign-up | Space at 360 px | AC-32 |
| Q10 | Set the OpenAPI title now? | Yes: "Daily Game Challenge API". Small backend-first boundary change | Today it says "FastAPI"; it shows in the generated client | AC-7 |
| Q11 | Nudge to sign up after the first win | Not in Phase 0. Belongs to M1-36 | No game exists yet | none |
| Q12 | Where does the archive link go in Phase 0 (the archive screen is M1-35)? | `/games/{slug}/archive`, showing a short "coming soon" text inside the layout | M1-03 asks for the link now; the URL is reserved early | AC-31 |
| Q13 | URL slug of the first game | `game-guesser` | Neutral, not the reference site's brand. Cheap to change before launch, costly after (shared links) | AC-56 |
| Q14 | Where does logout go? | Stay on the page if it is public; from `/profile` go to `/` | Logging out should not throw a player out of a puzzle | AC-20 |
| Q15 | Do the login and sign-up pages show the full top bar? | No. They keep their own centered layout, with the brand as a link to `/` | Fewer distractions in forms; matches today | AC-27 |
| Q16 | Favicon: there is no logo yet | A simple temporary letter mark; the Vite logo is removed | M1-01 asks for a new favicon; a real logo is a design task | AC-5 |

## Problem & Motivation

- The running app is still "MyList": it requires login, has a sidebar, a "Lists" page that does nothing, and a home page of cards.
- The product is now Daily Game Challenge (decision 1). A visitor must see today's puzzle on the main screen with no account (decisions 3, 4, 5).
- Phase 0 turns the app into the empty shell of that product, before any game exists. Phase 1 (backend) and Phase 2 (the game) then plug into it.
- Agents and people also read the docs and skills. Today they describe an item/list tracker, which leads to wrong work.

## Goals / Non-goals

**Goals**
- One name, "Daily Game Challenge", in the UI, page titles and docs.
- Guests use every page except account pages. Signed-in players keep profile and password change.
- A top bar that works at 360, 768 and 1280 px and with a keyboard.
- Stable, public URLs for the game screen: `/`, `/games/{slug}`, `/games/{slug}/{date}`, `/games/{slug}/archive`.
- A thin game module contract: a registry from slug to a lazily loaded screen.
- Safe return-after-login (no open redirect).

**Non-goals**
- Any game, puzzle data, guesses, progress, stats, countdown or real archive (Phases 1 and 2).
- Any new backend endpoint. The only backend change is the API title (Q10).
- Saving the language on the account (out of scope for Milestone 1).
- Meta tags and share image (M1-47), legal footer (M1-46), CSRF and rate limits (Phase 4).

## User stories

| ID | As a ... | I want ... | Covered by |
|---|---|---|---|
| US-1 | visitor | to open the site and see today's game screen with no account | AC-12, AC-21, AC-39, AC-47 |
| US-2 | visitor | to switch language and theme without an account | AC-4, AC-34, AC-55, AC-68 |
| US-3 | visitor on a phone | a header that fits and lets me reach every game | AC-35, AC-36, AC-37, AC-64, AC-67 |
| US-4 | visitor with an old bookmark to `/lists` | a clear page, not an error or a login wall | AC-10 |
| US-5 | visitor with a link to a past day | to open that day directly, or a clear message if the link is wrong | AC-41, AC-43 to AC-45 |
| US-6 | player | to log in from the header and come back to the same page | AC-13 to AC-17, AC-32 |
| US-7 | signed-in player | to see that I am signed in, open my profile and log out | AC-20, AC-33 |
| US-8 | signed-in player whose session ended | a clear signed-out state, without losing the page I am on | AC-25, AC-26 |
| US-9 | signed-in player | to use a password reset link from my email | AC-19 |
| US-10 | owner | the product called "Daily Game Challenge" everywhere, in both languages | AC-1 to AC-7 |
| US-11 | developer | to add a game by adding one registry entry, without touching the shell | AC-49 to AC-56 |
| US-12 | developer or agent | docs and skills that describe this product, not MyList | AC-57 to AC-60 |

## Acceptance criteria (EARS)

Each group names its source. "Shell page" means any page inside the new layout (all pages except the four auth pages).
"Account-only page" means `/profile` in Phase 0. "Today" always means the current UTC date (decision 10).

### M1-01 Rename (decision 1; M1-01; research sections 1 and 7)

- **AC-1** The system shall show the product name "Daily Game Challenge" wherever the UI names the product, in both languages, from the single catalogue key `app.name`.
- **AC-2** The static page title, shown before scripts run, shall be "Daily Game Challenge".
- **AC-3** WHEN a page is shown, the system shall set the browser tab title to "{page name} | Daily Game Challenge". The page name is a catalogue text; on a game screen it is the game's name. *Verify: tab title on `/` and `/profile`.*
- **AC-4** WHEN the language changes, the system shall update the tab title to the new language without a reload.
- **AC-5** The shipped frontend (catalogues, HTML page, public files) shall contain no "MyList" text, and the favicon shall not be the Vite template logo (Q16). *Verify: text search of the built output.*
- **AC-6** The Russian catalogue shall keep the brand in Latin letters and shall translate only the tagline (Q8).
- **AC-7** The backend API description shall have the title "Daily Game Challenge API" (Q10), and the frontend's generated client shall be regenerated from it in the same pass. *Verify: backend snapshot check and frontend API-types check both green.*
- **AC-8** The frontend package name `my-list-fe`, the backend package name `my-list-be` and the database name `item_list` shall stay unchanged (Q7, decision 26).

### M1-04 Remove Lists (SPEC section 1; M1-04)

- **AC-9** The system shall have no `/lists` page, no Lists nav entry, no old home-page cards, and no catalogue texts for them, in either language.
- **AC-10** WHEN anyone, signed in or not, opens `/lists`, the system shall show the in-layout "not found" screen with a link to today's puzzle (Q2), not the login page.
- **AC-11** The catalogue parity check (same keys in English and Russian) and the type check shall pass after the removal.

### M1-02 Optional login (decisions 3, 16; M1-02; research sections 2 and 4)

- **AC-12** WHEN a signed-out visitor opens `/`, `/games/{slug}`, `/games/{slug}/{date}` or `/games/{slug}/archive`, the system shall show the page inside the shell with no redirect.
- **AC-13** IF a signed-out visitor opens an account-only page, THEN the system shall send them to `/login` with the requested page in the `redirect` search parameter. *Verify: router test, `/profile` ends at `/login?redirect=%2Fprofile`.*
- **AC-14** WHEN login or sign-up succeeds, the system shall go to the validated `redirect` target, or to `/` if there is none.
- **AC-15** The system shall accept a `redirect` value only when it resolves to the site's own origin, and shall then navigate to the resolved path, query and fragment, never to the raw value. *Verify: unit test with the table in "Untrusted inputs".*
- **AC-16** IF the resolved `redirect` target is `/login`, `/register`, `/forgot-password` or `/reset-password`, THEN the system shall go to `/` instead (no loops).
- **AC-17** IF the `redirect` value is missing, empty or rejected, THEN the system shall ignore it without an error message.
- **AC-18** WHEN a signed-in user opens `/login`, `/register` or `/forgot-password`, the system shall send them to `/` (as today).
- **AC-19a** WHEN a signed-in user opens `/reset-password?token=...`, the system shall show the reset form with the token kept (Q3).
- **AC-19b** WHEN a reset started while signed in succeeds, the system shall show the signed-out state and go to `/login`, because the backend ends all sessions.
- **AC-20** WHEN the user logs out, the system shall clear all signed-in state and cached account data, and shall stay on the current page if it is public, or go to `/` from an account-only page (Q14).
- **AC-21** WHILE `/auth/me` has not answered, the system shall render public pages fully and shall show a same-size placeholder in the header account area (no "Log in" that turns into a menu). *Verify: delay `/auth/me` by 5 s; the game screen is visible before it answers.*
- **AC-22** WHILE `/auth/me` has not answered, the system shall not decide on account-only and auth pages: they wait for the answer, so no wrong redirect happens.
- **AC-23** IF `/auth/me` answers 401, THEN the system shall treat the visitor as a guest and show no error.
- **AC-24** IF `/auth/me` fails for any other reason (network error, 5xx), THEN the system shall still show public pages, shall show a "Retry" control in the account area, and shall show the error screen with the request id on account-only pages (Q6).
- **AC-25** WHEN any API call answers 401 while the UI shows a signed-in user, the system shall switch the header to the signed-out state and drop cached user data; a later navigation shall not bring back the signed-in state without a new successful `/auth/me`. *Verify: router test of the stale-cache case found by the research (section 2).*
- **AC-26a** IF that 401 happens on an account-only page, THEN the system shall send the user to `/login` with the current page as `redirect` and show a "session expired" message.
- **AC-26b** IF that 401 happens on a public page, THEN the system shall keep the user on that page.

### M1-03 New nav (decisions 4, 5, 21, 27; M1-03; research sections 3 and 5)

- **AC-27a** Every shell page shall have a top bar (Q1) with, in this visual and keyboard order: a skip link, the brand (a link to `/`), the game entries, the archive link, the language switcher, the theme toggle and the account area.
- **AC-27b** The four auth pages shall keep their own layout and shall show the brand as a link to `/` (Q15).
- **AC-28** The game entries shall come from the frontend game registry, in registry order (Q5). Phase 0 shows exactly one entry.
- **AC-29** WHEN the player selects a game entry, the system shall show `/games/{slug}` for today inside the same layout, without a full page reload.
- **AC-30** The system shall mark exactly one game entry as the current page: the game being shown, on `/` (default game), `/games/{slug}` and `/games/{slug}/{date}`.
- **AC-31** The archive link shall go to `/games/{slug}/archive` for the game being shown; in Phase 0 that page shows a short "coming soon" text inside the layout (Q12).
- **AC-32** WHILE signed out, the account area shall show "Log in", and "Sign up" at widths of 768 px and more; below 768 px it shall show "Log in" only (Q9). Both carry the current page as `redirect`.
- **AC-33** WHILE signed in, the account area shall show a menu button whose accessible name includes the account's email; the menu shall offer "Profile" and "Log out".
- **AC-34** The language switcher and the theme toggle shall work for guests and signed-in users; a switch shall keep the URL and shall not reload the page.
- **AC-35** At widths of 768 px and more the header shall be one row. Below 768 px it shall be two rows: brand, language, theme and account on the first; games and archive link on the second.
- **AC-36** WHERE the game entries do not fit their row, the row shall scroll sideways inside itself (never the page), shall keep the current entry in view, and an "All games" control shall open the full list in a panel. *Verify: Playwright with a test registry of 8 entries (M1-50).*
- **AC-37** The header shall stay at the top while the page scrolls; WHILE the viewport is less than 500 CSS px tall, the header shall scroll away with the page.
- **AC-38** The sidebar and its remembered open or closed state shall be removed (Q1).

### M1-06 The home page becomes the game screen (decisions 4, 5, 7, 10, 20; M1-06; research section 4)

- **AC-39** WHEN anyone opens `/`, the system shall show the default game's screen for today, with no redirect.
- **AC-40** WHEN anyone opens `/games/{slug}`, the system shall show that game's screen for today.
- **AC-41a** WHEN anyone opens `/games/{slug}/{date}`, the system shall show that game's screen for that date.
- **AC-41b** WHEN that date is today, the system shall show the same puzzle (same game and date) as `/games/{slug}`, with no redirect (Q4).
- **AC-42** The system shall show the same puzzle on `/` and on `/games/{default slug}`.
- **AC-43** IF the slug is not in the registry, THEN the system shall show the in-layout "not found" screen with the text "Unknown game" and a link to today's puzzle. Slugs are case-sensitive.
- **AC-44** IF the date is not a real calendar day written as `YYYY-MM-DD` (for example `2026-02-30`, `2026-1-5`, `today`), THEN the system shall show the in-layout "not found" screen with the text "No puzzle for this date".
- **AC-45** IF the date is later than today, THEN the system shall show the same "No puzzle for this date" screen (Q4). From Phase 1 the backend's answer decides.
- **AC-46** The system shall compute "today" in UTC, never in the device's time zone. *Verify: unit test with a fixed clock at 23:30 in UTC-5 and at 01:00 in UTC+3.*
- **AC-47** In Phase 0 the game screen shall show the game's name, the puzzle date (in the current language, as a UTC day) and a "coming soon" text.
- **AC-48** All "not found" and per-game error states shall render inside the layout, with the header usable.

### M1-07 Game module contract (decision 8, SPEC section 3.3; M1-07; ARCHITECTURE section 5)

This is the shape of the boundary between the shell and a game module, not how either side is built.

| Crosses the boundary | Direction | Meaning |
|---|---|---|
| `slug` | registry to shell | Stable URL id of the game |
| name key | registry to shell | Catalogue key of the game's name, present in both languages |
| order | registry to shell | Position in the nav (decision 53 order) |
| default flag | registry to shell | Which game `/` shows |
| screen | registry to shell | The game's screen, loaded only when opened |
| `slug`, `date` (`YYYY-MM-DD`, UTC), "is today" | shell to screen | Which puzzle to show; variants stay inside the module (SPEC 3.8) |

- **AC-49** Each registry entry shall carry exactly the items in the table above (slug, name key, order, default flag, screen).
- **AC-50** The registry shall have exactly one default game; a registry check shall fail with zero or two or more defaults.
- **AC-51** Every slug shall match `^[a-z0-9]+(-[a-z0-9]+)*$` and be unique; a registry check shall fail otherwise.
- **AC-52** The shell shall give the screen only the slug, the date and the "is today" flag.
- **AC-53** The system shall download a game's code only when that game's screen is opened.
- **AC-54** IF a game screen fails while rendering, THEN the system shall show an in-layout error for that game with a "Try again" control, and the header shall keep working (ARCHITECTURE section 5).
- **AC-55a** WHEN the language changes while a game screen is open, the system shall keep that screen and its state.
- **AC-55b** A game module shall not key its progress by language.
- **AC-56** The registry shall hold one entry in Phase 0: the game guesser, slug `game-guesser` (Q13), default game, with the placeholder screen. Phase 2 replaces only its screen.

### M1-05 Leftovers in docs, skills and config (SPEC section 10 step 3; M1-05; research section 1)

- **AC-57** A text search shall find no "MyList", "item-list", "field_schema", "custom_attributes" or "dynamic-category-schema" in: the root `CLAUDE.md` and `CONTRACTS.md`, both repo `CLAUDE.md` files, both repos' skills, both READMEs, and the backend's `specs/password-update.md`. Allowed: history text in `SPEC.md`, `ARCHITECTURE.md`, `MILESTONE-1.md`, and repo folder names.
- **AC-58** Both `dynamic-category-schema` skills shall be deleted; other skills shall stay, with their references to it removed.
- **AC-59** Each repo README shall say in a few lines what the repo is (part of Daily Game Challenge) and how to install, run and test it.
- **AC-60** The frontend `CLAUDE.md` shall describe the current shell (optional login, top bar, game registry) and shall not name files that do not exist.

### Cross-cutting (decisions 21, 27; SPEC 3.1, 3.6; research sections 5, 8, 9)

- **AC-61** Every user-visible text in the shell shall come from the catalogues, present in English and Russian; no text is written directly in a component.
- **AC-62** The skip link shall be the first focusable element, shall become visible on focus, and shall move focus to the main content.
- **AC-63** Each shell page shall have one banner (the header), one main area, and a games navigation region labelled from the catalogue ("Games"; the label does not contain the word "navigation").
- **AC-64** Every header control shall be at least 24 by 24 CSS px; touch controls shall aim for 44 px height where the row allows.
- **AC-65** The sticky header shall never fully cover the element that has keyboard focus.
- **AC-66** The account menu shall open with Enter, Space or Arrow Down, and Escape shall close it and return focus to its button. The "All games" panel shall keep focus inside while open and close on Escape.
- **AC-67** At widths of 320, 360, 768 and 1280 CSS px, no shell page shall scroll sideways at page level.
- **AC-68** IF browser storage is blocked, THEN the app shall still render, and theme and language shall work for the open tab without being remembered.
- **AC-69** Phase 0 shall store nothing new in the browser beyond the existing `language` and `theme` keys and the session cookie.
- **AC-70** No new screen or message shall reveal whether an email has an account, beyond what the backend already reveals (409 on sign-up).

## Edge cases

| Case | Expected | AC |
|---|---|---|
| Bookmarked `/lists` | In-layout "not found", link to today's puzzle | AC-10 |
| Old session cookie the backend no longer knows | `/auth/me` gives 401, visitor is a guest, no error | AC-23 |
| `/auth/me` slow | Page shows at once; account area shows a placeholder | AC-21 |
| `/auth/me` network failure | Public page works; "Retry" in account area | AC-24 |
| 401 in the middle of a session | Signed-out header; stays signed out on next navigation | AC-25, AC-26 |
| Storage blocked (private mode) | App renders; choices last for the tab only | AC-68 |
| Reset link `?token=` while signed in | Reset form shown, token kept | AC-19 |
| `redirect` pointing elsewhere | Ignored, go to `/` | AC-15 to AC-17 |
| 360 px phone, or 320 px | Two-row header, no page-level side scroll | AC-35, AC-67 |
| Phone in landscape | Header scrolls away (less than 500 px tall) | AC-37 |
| 8 games later | Row scrolls inside itself; "All games" panel | AC-36 |
| Unknown slug, wrong case slug | "Unknown game" | AC-43 |
| Invalid or future date | "No puzzle for this date" | AC-44, AC-45 |
| Device in UTC-5 at 23:30 local | "Today" is the next UTC day | AC-46 |
| Language switch mid-game | Same URL, screen and state kept | AC-34, AC-55 |
| Game screen crashes | Error inside the layout; header works | AC-54 |
| Phase 1: backend lists a game the frontend has no screen for, or the reverse | Show only games known to both; never crash. To confirm in the Phase 1 spec | none yet |
| Page open across 00:00 UTC | Phase 0 keeps the date it loaded with; rollover is M1-32 | none |

## Non-functional

- **Performance:** a public page never waits for `/auth/me` before showing its content (AC-21). A game's code loads only when opened (AC-53).
- **Accessibility:** landmarks, skip link, current-page marking, target sizes, focus not covered, keyboard order (AC-27, AC-30, AC-62 to AC-66). Target is WCAG 2.2 AA.
- **Responsive:** checked at 360, 768 and 1280 px, plus 320 px for reflow (AC-35 to AC-37, AC-67).
- **Security:** the route guard is a convenience; the backend still answers 401 on account endpoints. Redirect rules in AC-15 to AC-17. No new existence leak (AC-70).
- **Privacy:** nothing new stored (AC-69). The reset token shall not appear in the tab title, in a `redirect` value or in any error report.

## Inputs (provenance)

| Input | Tag |
|---|---|
| Signed-in state | [existing: `GET /v1/auth/me`, called on page load] |
| Language choice | [existing: browser storage key `language`, else browser language] |
| Theme choice | [existing: browser storage key `theme`, else OS setting] |
| Game list, default game, slug | [new: static frontend registry; no network cost] |
| "Today" | [derived: device clock read in UTC; the backend clock replaces it in Phase 1 (M1-17)] |
| `redirect`, `slug`, `date` | [derived: from the URL the visitor opened] |
| Reset `token` | [existing: reset email link, `CONTRACTS.md` "Password reset"] |
| API title in the generated client | [existing: backend API description, changed by Q10] |

**Where the requirements come from:** owner decisions 1, 3, 4, 5, 7, 8, 10, 16, 20, 21, 26, 27 (`SPEC.md` section 2); the plan `MILESTONE-1.md` (M1-01 to M1-07, D1); SPEC 3.3 (module contract), 3.6 (responsive), 3.8 (languages); `ARCHITECTURE.md` section 5 (error boundary per game); the Phase 0 research report (sections cited per group). Each AC group above names its own source.

## Untrusted inputs

All of these come from the URL, which anyone can craft. They are data, never instructions. Each is checked where the route reads it; a bad value gives a defined screen, never a crash.

| Input | Rule | Bad value gives |
|---|---|---|
| `redirect` search parameter | Resolve against the site origin; accept only the same origin; use the resolved path, query and fragment; reject auth pages | `/` (AC-15 to AC-17) |
| `slug` path segment | Must be a registry slug, exact match | "Unknown game" (AC-43) |
| `date` path segment | `YYYY-MM-DD`, a real day, not after today UTC | "No puzzle for this date" (AC-44, AC-45) |
| `token` search parameter | Passed only to the reset request; never shown, logged or copied into other URLs | Existing "invalid link" state |

Required test table for `redirect` (base `http://localhost:5173`; research section 4 checked how browsers resolve them):

| Value | Result |
|---|---|
| `/games/game-guesser/2026-10-01?a=1` | accepted, same path |
| `/profile` | accepted |
| `//evil.com` | rejected |
| `/\evil.com` | rejected |
| `/` followed by a tab, then `/evil.com` | rejected |
| `https://evil.com` | rejected |
| `javascript:alert(1)` | rejected |
| `/%2F/evil.com` | accepted, stays on our site (path `/%2F/evil.com`, which is "not found") |
| `/login?redirect=/profile` | replaced by `/` |
| empty, missing | `/` |

## Out of scope

- The game guesser and every other game; puzzle data and endpoints (Phases 1 and 2).
- The real archive screen (M1-35), countdown (M1-37), stats, share, sign-up nudge (M1-36), guest merge (M1-15, M1-36).
- `GET /v1/games` (M1-10). The nav switches to it in Phase 1.
- Meta description, Open Graph, share image (M1-47); legal footer (M1-46); web manifest.
- Renaming repo folders, package names or the database (decision 26, Q7).
- Saving language on the account; a third language; right-to-left support.

## Definition of done for Phase 0

**The owner can check in a browser (signed out, then signed in):**
1. `/` shows the top bar and the "coming soon" game screen with today's UTC date. No login page.
2. The tab title and header say "Daily Game Challenge" in English and in Russian. No "MyList" anywhere.
3. `/lists` shows "not found" inside the layout. `/games/game-guesser/2099-01-01` and `/games/nope` show their "not found" texts.
4. `/profile` while signed out goes to login; after login it comes back to `/profile`.
5. Log out on `/` stays on `/`. The header shows "Log in".
6. At 360, 768 and 1280 px (browser dev tools) the header fits, nothing scrolls sideways, and Tab moves through skip link, brand, game, archive, language, theme, account.
7. Language switch keeps the page and URL; the tab title changes language.

**CI must show (both repos green):**
- Frontend: lint, format, type check, build, unit tests, router tests, catalogue parity, API-types check.
- Backend: tests and the API snapshot check, with the new title (Q10).
- The text search of AC-5 and AC-57 finds nothing.

## Test strategy (what and at which level)

| What | Level |
|---|---|
| `redirect` validation, full table above | Pure unit test |
| Date parsing and "today in UTC" with a fixed clock | Pure unit test |
| Registry checks: one default, slug format, unique slugs, both catalogues have each name key | Pure unit test |
| Catalogue parity, no `lists` or old `home` keys | Existing unit test |
| Guards: guest `/` stays; guest `/profile` goes to `/login?redirect=%2Fprofile`; signed-in `/login` goes to `/`; signed-in reset link keeps the token; `/lists` and bad slug or date are "not found" | Router test in Node with the real route tree and a fake `/auth/me` (research section 8 showed this works) |
| 401 mid-session stays signed out after navigation | Router test in Node |
| Public page renders before a slow `/auth/me` | Router or component test |
| Nav rendering, current-page marking, menu keyboard, focus | Component test if a DOM test setup is added; otherwise Playwright in M1-50 |
| 320 to 1280 px layout, target sizes, axe checks | Playwright, M1-50; manual checklist above until then |
| Backend API title | Existing backend snapshot test |

## Task dependencies and order

1. **Q1 (D1) and the other open questions first.** M1-02 and M1-03 depend on Q1.
2. **M1-07** (this spec) agreed before M1-02, M1-03 and M1-06.
3. **M1-01 + M1-04 in one frontend PR.** They change the same catalogue files and the same nav code.
4. **Q10 (API title):** backend PR first (title and snapshot), then the frontend regeneration and `CONTRACTS.md`, in the same pass.
5. **M1-02** next. Until M1-06 lands, `/` needs a neutral placeholder with no "lists" text (research section 9).
6. **M1-03 and M1-06** after M1-02. With the static registry (Q5) they no longer wait for M1-10 or M1-30.
7. **M1-05** any time; it touches only docs, skills and config in all three repos.
