# Spec: Phase 0, the Daily Game Challenge shell   |   Spec ID: SPEC-01   |   Status: agreed with the owner's answers (2026-10-28)

Covers Milestone 1, Phase 0, tasks M1-01 to M1-07 (`MILESTONE-1.md` section 4). Written 2026-10-27; open questions answered 2026-10-28.
Touches both app repos and the platform docs, so it lives in the root `specs/` folder.

## In short

1. The app is renamed from "MyList" to "Daily Game Challenge" everywhere a person can see it.
2. Login becomes optional. Guests see the whole site; only `/profile` needs an account.
3. The sidebar stays (Q1) but its content changes: brand, games, archive link, and at the bottom language, theme, and login or account menu. Phones get a slim header with a sidebar button, the brand and "Log in".
4. `/`, `/games/{slug}` and `/games/{slug}/{date}` show one game screen (a placeholder in Phase 0), chosen through a small game registry.
5. The Lists feature and all MyList leftovers in docs, skills and config are removed.

## Owner's answers (2026-10-28)

The owner answered all 16 questions in the chat. "Accepted" means the recommended default was chosen. Two answers differ from the default (Q1, Q7); Q2 and Q9 were worded differently, and the acceptance criteria below follow the answers.

| # | Question | Answer | Criteria affected |
|---|---|---|---|
| Q1 | D1 layout: top bar or the existing sidebar? | **Keep the sidebar** (not the default) | AC-27 to AC-38 |
| Q2 | What does `/lists` show after removal? | **The route is removed.** An unknown path shows the normal in-layout "not found" screen, which is the default's result | AC-10 |
| Q3 | A signed-in user opens a password reset link. Keep the token? | Accepted: show the reset form | AC-19 |
| Q4 | `/games/{slug}/{future date}` and `/games/{slug}/{today}` | Accepted: future is not found; today shows the same screen as `/games/{slug}`, no redirect | AC-41, AC-45 |
| Q5 | Source of the game list in Phase 0 | Accepted: static frontend registry; `GET /v1/games` in Phase 1 | AC-28, AC-49 |
| Q6 | Public page and `/auth/me` | Accepted: start at once; "Retry" in the account area on a network failure | AC-21 to AC-24 |
| Q7 | Rename the frontend package name and the database name? | **Rename both now** (not the default). New names are my proposal, see AC-8 | AC-8, AC-57 |
| Q8 | Brand and tagline in Russian | Accepted: Latin brand; tagline EN "Daily puzzle games", RU "Ежедневные игры-загадки" | AC-1, AC-6 |
| Q9 | Where do "Log in" and "Sign up" go for a guest? (reworded because of Q1) | Accepted: bottom of the sidebar; below 768 px the slim header also shows "Log in" | AC-32 |
| Q10 | OpenAPI title | Accepted: "Daily Game Challenge API", now | AC-7 |
| Q11 | Sign-up nudge after the first win | Accepted: not in Phase 0 (M1-36) | none |
| Q12 | Archive link in Phase 0 | Accepted: `/games/{slug}/archive` with "coming soon" | AC-31 |
| Q13 | Slug of the first game | Accepted: `game-guesser` | AC-56 |
| Q14 | Where logout goes | Accepted: stay on a public page; from `/profile` go to `/` | AC-20 |
| Q15 | Auth pages and the layout | Accepted: own centered layout, brand links to `/` | AC-27 |
| Q16 | Favicon | Accepted: temporary letter mark | AC-5 |

## Problem & Motivation

- The running app is still "MyList": it requires login, has a sidebar, a "Lists" page that does nothing, and a home page of cards.
- The product is now Daily Game Challenge (decision 1). A visitor must see today's puzzle on the main screen with no account (decisions 3, 4, 5).
- Phase 0 turns the app into the empty shell of that product, before any game exists. Phase 1 (backend) and Phase 2 (the game) then plug into it.
- Agents and people also read the docs and skills. Today they describe an item/list tracker, which leads to wrong work.

## Goals / Non-goals

**Goals**
- One name, "Daily Game Challenge", in the UI, page titles and docs.
- Guests use every page except account pages. Signed-in players keep profile and password change.
- A sidebar layout that works at 360, 768 and 1280 px and with a keyboard.
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
| US-3 | visitor on a phone | a layout that fits and lets me reach every game | AC-35, AC-36, AC-37, AC-64, AC-67 |
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
- **AC-8** The frontend package name shall become `daily-game-challenge-fe`, the backend package name `daily-game-challenge-be`, and the database names `daily_game_challenge` (development and CI) and `daily_game_challenge_test` (tests) (Q7). The names appear in `package.json`, `pyproject.toml` with both lockfiles, `.env.example`, `docker-compose.yml`, `app/core/config.py` and both CI files. Repo folder names, the GitHub repository names and the path `../my-list-be/openapi/openapi.json` stay (decision 26). *Verify: both CI workflows green; the text search of AC-57 finds no `item_list`.*
- **AC-8b** The backend README and `CLAUDE.md` shall tell a developer with an existing local database that the old `item_list` volume is unused and how to create the new one (drop the old container volume and start the compose file again; local data is not migrated, it is test data only).

### M1-04 Remove Lists (SPEC section 1; M1-04)

- **AC-9** The system shall have no `/lists` page, no Lists nav entry, no old home-page cards, and no catalogue texts for them, in either language.
- **AC-10** The system shall have no `/lists` route (Q2). WHEN anyone, signed in or not, opens `/lists`, the system shall show the same in-layout "not found" screen as for any unknown path, with a link to today's puzzle, not the login page.
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

The sidebar stays (Q1). The existing sidebar component is reused; the content changes.

- **AC-27a** Every shell page shall have the sidebar layout. The page shall start with a skip link. The sidebar shall hold, in this visual and keyboard order: the brand (a link to `/`), the game entries, the archive link, and at the bottom the language switcher, the theme toggle and the account area.
- **AC-27b** The four auth pages shall keep their own layout without the sidebar and shall show the brand as a link to `/` (Q15).
- **AC-28** The game entries shall come from the frontend game registry, in registry order (Q5). Phase 0 shows exactly one entry.
- **AC-29** WHEN the player selects a game entry, the system shall show `/games/{slug}` for today inside the same layout, without a full page reload.
- **AC-30** The system shall mark exactly one game entry as the current page: the game being shown, on `/` (default game), `/games/{slug}` and `/games/{slug}/{date}`.
- **AC-31** The archive link shall go to `/games/{slug}/archive` for the game being shown; in Phase 0 that page shows a short "coming soon" text inside the layout (Q12).
- **AC-32** WHILE signed out, the account area at the bottom of the sidebar shall show "Log in" and "Sign up". Below 768 px the slim header shall also show "Log in" (Q9). Every such control carries the current page as `redirect`.
- **AC-33** WHILE signed in, the account area shall show a menu button whose accessible name includes the account's email; the menu shall offer "Profile" and "Log out". Below 768 px the slim header shall show the same menu button instead of "Log in".
- **AC-34** The language switcher and the theme toggle shall work for guests and signed-in users; a switch shall keep the URL and shall not reload the page.
- **AC-35** At widths of 768 px and more the sidebar shall be open beside the content. Below 768 px a slim header of one row shall show the sidebar button, the brand and the account control, and the sidebar shall open as a panel over the page.
- **AC-36** WHERE the game entries do not fit the sidebar's height, the entry list shall scroll inside itself, never the page, and shall keep the current entry in view. *Verify: Playwright with a test registry of 8 entries (M1-50).*
- **AC-37** The sidebar shall stay in place while the page scrolls, and the slim header shall stay at the top; WHILE the viewport is less than 500 CSS px tall, the slim header shall scroll away with the page.
- **AC-38** The sidebar's Lists entry and old home entry shall be removed. The sidebar component and its remembered open or closed state (the existing `sidebar_state` cookie) shall stay.

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

- **AC-57** A text search shall find no "MyList", "item-list", "item_list", "field_schema", "custom_attributes" or "dynamic-category-schema" in: the root `CLAUDE.md` and `CONTRACTS.md`, both repo `CLAUDE.md` files, both repos' skills, both READMEs, and the backend's `specs/password-update.md`. Allowed: history text in `SPEC.md`, `ARCHITECTURE.md`, `MILESTONE-1.md`, repo folder names and the `my-list-be` path in the frontend's Orval config and CI.
- **AC-58** Both `dynamic-category-schema` skills shall be deleted; other skills shall stay, with their references to it removed.
- **AC-59** Each repo README shall say in a few lines what the repo is (part of Daily Game Challenge) and how to install, run and test it.
- **AC-60** The frontend `CLAUDE.md` shall describe the current shell (optional login, sidebar layout, game registry) and shall not name files that do not exist.

### Cross-cutting (decisions 21, 27; SPEC 3.1, 3.6; research sections 5, 8, 9)

- **AC-61** Every user-visible text in the shell shall come from the catalogues, present in English and Russian; no text is written directly in a component.
- **AC-62** The skip link shall be the first focusable element, shall become visible on focus, and shall move focus to the main content.
- **AC-63** Each shell page shall have one main area and a games navigation region labelled from the catalogue ("Games"; the label does not contain the word "navigation"). Below 768 px the slim header shall be the banner.
- **AC-64** Every sidebar and header control shall be at least 24 by 24 CSS px; touch controls shall aim for 44 px height where the row allows.
- **AC-65** The slim header shall never fully cover the element that has keyboard focus.
- **AC-66** The account menu shall open with Enter, Space or Arrow Down, and Escape shall close it and return focus to its button. The phone sidebar panel shall keep focus inside while open, close on Escape and return focus to the sidebar button.
- **AC-67** At widths of 320, 360, 768 and 1280 CSS px, no shell page shall scroll sideways at page level.
- **AC-68** IF browser storage is blocked, THEN the app shall still render, and theme and language shall work for the open tab without being remembered.
- **AC-69** Phase 0 shall store nothing new in the browser beyond the existing `language` and `theme` keys, the `sidebar_state` cookie and the session cookie.
- **AC-70** No new screen or message shall reveal whether an email has an account, beyond what the backend already reveals (409 on sign-up).

## Edge cases

| Case | Expected | AC |
|---|---|---|
| Bookmarked `/lists` | Route removed; in-layout "not found", link to today's puzzle | AC-10 |
| Old session cookie the backend no longer knows | `/auth/me` gives 401, visitor is a guest, no error | AC-23 |
| `/auth/me` slow | Page shows at once; account area shows a placeholder | AC-21 |
| `/auth/me` network failure | Public page works; "Retry" in account area | AC-24 |
| 401 in the middle of a session | Signed-out header; stays signed out on next navigation | AC-25, AC-26 |
| Storage blocked (private mode) | App renders; choices last for the tab only | AC-68 |
| Reset link `?token=` while signed in | Reset form shown, token kept | AC-19 |
| `redirect` pointing elsewhere | Ignored, go to `/` | AC-15 to AC-17 |
| 360 px phone, or 320 px | Slim header, sidebar as a panel, no page-level side scroll | AC-35, AC-67 |
| Phone in landscape | Header scrolls away (less than 500 px tall) | AC-37 |
| 8 games later | The entry list scrolls inside the sidebar | AC-36 |
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
- Renaming repo folders or the GitHub repositories (decision 26). Package and database names are renamed in AC-8.
- Saving language on the account; a third language; right-to-left support.

## Definition of done for Phase 0

**The owner can check in a browser (signed out, then signed in):**
1. `/` shows the sidebar and the "coming soon" game screen with today's UTC date. No login page.
2. The tab title and header say "Daily Game Challenge" in English and in Russian. No "MyList" anywhere.
3. `/lists` shows "not found" inside the layout. `/games/game-guesser/2099-01-01` and `/games/nope` show their "not found" texts.
4. `/profile` while signed out goes to login; after login it comes back to `/profile`.
5. Log out on `/` stays on `/`. The account area shows "Log in".
6. At 360, 768 and 1280 px (browser dev tools) the layout fits, nothing scrolls sideways, and Tab moves through skip link, brand, game, archive, language, theme, account (on a phone: the sidebar button first, then the same order inside the panel).
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

1. **Questions Q1 to Q16 are answered** (2026-10-28). Q1 and Q7 changed the plan: the sidebar stays, and the rename (AC-8) touches both repos and both CI files.
2. **M1-07** (this spec) agreed before M1-02, M1-03 and M1-06.
3. **M1-01 + M1-04 in one frontend PR.** They change the same catalogue files and the same nav code. The package and database rename (AC-8) is a separate pair of small PRs (backend first: compose, CI, config, lockfile; then the frontend `package.json`), so a rename mistake does not block the product work.
4. **Q10 (API title):** backend PR first (title and snapshot), then the frontend regeneration and `CONTRACTS.md`, in the same pass.
5. **M1-02** next. Until M1-06 lands, `/` needs a neutral placeholder with no "lists" text (research section 9).
6. **M1-03 and M1-06** after M1-02. With the static registry (Q5) they no longer wait for M1-10 or M1-30.
7. **M1-05** any time; it touches only docs, skills and config in all three repos.
