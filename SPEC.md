# Spec: Daily Game Challenge

Status: draft 22. This is the general site spec. It covers the shell, accounts, progress, archive and how games plug in. Each game (starting with the game guesser) and each larger feature gets its own smaller spec later (backend in `my-list-be/specs/`, frontend in `my-list-fe/docs/specs/`, and specs that cross both repos in the platform folder's `specs/`).

Legend: **[decided]** was stated by the project owner. **[proposed]** is a suggestion, not yet agreed. **[open]** needs a decision.

## 1. Context

The project began as MyList, a site for lists of everything. That direction is dropped. The product is now **Daily Game Challenge**: one site with several daily games, each finishable in a few minutes, with one new puzzle per game per day. Most are guessing games; one is a playable challenge, a real Game Boy game run in the browser (3.10), and one is a timed search for a hidden character in a crowded picture (3.11), and one is a geometry puzzle where each wrong guess adds a clue (3.12). The reference is guessthe.game.

Existing code: authentication (register, login, logout, `/auth/me`, password reset and update) and a main page. No list, category, item or image code needs to be kept.

## 2. Decisions

1. **[decided]** Project name: Daily Game Challenge.
2. **[decided]** First game: the game guesser (identify a video game from screenshots).
3. **[decided]** Authentication is optional. Accounts unlock extras: remembering completed daily challenges across devices, a leaderboard, and possibly more.
4. **[decided]** The nav bar lists the available daily games. The selected game renders on the main screen.
5. **[decided]** Games play on the same screen with no redirect.
6. **[decided]** Daily games are finishable in a short time (Wordle-like, game guess, logo guess, car guess and similar).
7. **[decided]** The user can open the list of previous days' puzzles and play them.
8. **[decided]** Games can have different mechanics. The site must not assume one shared mechanic (see 3.3).
9. **[decided]** Scoring differs per game and is decided in each game's spec. At the high level the score is the number of tries used to guess. The playable challenge is the exception: its score is the in-game result (decision 39).
10. **[decided]** The day boundary is UTC.
11. **[decided]** Puzzles are created with a script, with low use of AI where it helps. No admin UI to start with.
12. **[decided]** No monetization for now (no ads, no payments).
13. **[decided]** Start by copying guessthe.game's core features with our own games and style, then add custom features.
14. **[decided]** Archive results count toward stats only, not toward streaks or the leaderboard.
15. **[decided]** Streak grace: a streak survives up to 3 days without activity and is discarded after that. See 3.5 for how I read this.
16. **[decided]** Guests are stateless on the server: the client keeps progress and sends earlier guesses with each request. Accounts store progress on the server (see section 6).
17. **[superseded by 27 to 29]** English only to start.
18. **[decided]** The spelling is "Challenge".
19. **[decided]** Puzzle data is handled by scripts wherever possible. AI is used only as a fallback if a script cannot solve a data problem.
20. **[decided]** The archive is a screen that lists all previous days' puzzles for a game, and the player picks one to play (see 3.4).
21. **[decided]** The site is responsive and designed to look good on laptops, tablets and phones (see 3.6).
22. **[decided]** A React Native mobile app is a future step, after the main parts of the web site work (see 3.6).
23. **[decided]** The site has a legal footer and the pages behind it (see 3.7).
24. **[decided]** Reference details I did not inspect (the share result format, the sign-up flow, whether the reference has a leaderboard) are skipped for now. The leaderboard stays in our spec as our own feature.
25. **[decided]** The next game after the game guesser is a Wordle-style word game (the owner wrote "Wordly"). Section 4 describes how Wordle works. Its final name and look are our own (see 8, risk 2).
26. **[decided]** The streak rule in 3.5 is confirmed. The repo folder names stay as they are for now.
27. **[decided]** The site supports two interface languages: English and Russian (see 3.8).
28. **[decided]** The word game has its own puzzle-language option, separate from the site language: for example the site in English and the word game in Russian.
29. **[decided]** The word game has a word-length option from 4 to 7 letters, 5 by default.
30. **[decided]** Streaks in the word game count only for the default variant (5 letters). The other lengths are extra play for players who want more, without streaks (see 3.8; the streak is shared by both languages, decision 52).
31. **[decided]** Word game answers are nouns. Word lists come from a dictionary and are not reviewed by hand; the script filters them automatically (section 7).
32. **[decided]** The game guesser stays English only.
33. **[decided]** Hard mode and high contrast are in the word game from the first version.
34. **[decided]** A movie-guessing game (identify a movie from screenshots) is added to the games, modeled on guessthemovie.name (section 4).
35. **[decided]** The movie game uses the same hint ladder as the reference: ratings (Metacritic and IMDb), genre, release year, notable actor, director. Where the ratings come from is checked against the terms in section 7; if they cannot be used, the ladder drops to the hints that can.
36. **[decided]** The movie search list shows the release year, so same-title movies and remakes can be told apart.
37. **[decided]** Community stats per puzzle (share of players per step, top wrong guesses) come after the games and the archive work.
38. **[decided]** The cover mode, the "poorly described" text mode and quests are not in the first version.
39. **[decided]** A playable challenge is added: the player opens the page and has to finish one level, last longer, or get a higher score in a retro game, with a different challenge each day. Its score is the in-game result, not the number of tries (see 3.10).
40. **[decided]** To start, the site handles the ROMs itself: it hosts them and runs them in its own player. Players do not bring ROMs. Reading of "run them own" (confirmed, decision 55): the emulator and the ROMs are self-hosted on our own origin, with no third-party CDN, and the game runs in the player's browser. If it meant running the games on our server and streaming them to the player, say so. I did not research streaming; it needs a server process per player, which running in the browser does not.
41. **[decided]** A hidden-character game ("find it") is added. One large picture is full of small characters and the player has to find one given character. There are no clues, only a timer. The player first sees a placeholder and what to find; on Start the placeholder is removed and the picture appears; the player clicks the place where the target is. Hidden Folks and Hidden Through Time are references for the main game logic only, not to copy (3.11).
42. **[decided]** Hidden-character game, art: the scenes are made by a script from openly licensed parts (section 7). The characters are original or generic figures, not famous ones (risk 19). Hand-drawn art and public-domain paintings are not in the first version.
43. **[decided]** Hidden-character game, score: the timer counts up from 0 when the picture is shown, and the faster the player finds the target, the higher the score. The result is the time, and the board ranks the lowest time first (3.11).
44. **[decided]** Hidden-character game, time limit: none. A give-up button reveals the answer, and an unranked relaxed mode hides the timer (3.11).
45. **[decided]** "Waldo" is the working title of the hidden-character game, used only in the spec and in our notes. The public name (nav bar, page title, URL slug, share text) is chosen before launch and must avoid "Waldo", "Wally" and other marks of the Where's Waldo franchise (risk 19).
46. **[decided]** A geometry game is added: the player finds an angle in a figure, such as a triangle, by reasoning. It follows the game guesser's flow: with each step the player gets an additional clue, such as other angles, formulas or extra elements that help the calculation. The idea is the owner's own; no existing game with this design was found (section 4).
47. **[decided]** The geometry game is not only about angles: the unknown can also be the length of a side, a radius, or the length of another part of the figure. This makes the puzzles more varied and more interesting (3.12).
48. **[decided]** Geometry game, kind of target: it is random each day (an angle, a side, a radius or another length). It is not a weekday plan and not a setting the player picks.
49. **[decided]** Geometry game, answers: whole numbers only at first (3.12).
50. **[decided]** Geometry game, first version: angle puzzles of the early and middle tiers, length puzzles from the Pythagorean theorem and similar triangles, and the radius of the circle through a right triangle. Other circle rules, the Sunday special and other exercise types come later (3.12).
51. **[decided]** Streaks and boards, for all games unless a game's own spec says otherwise: finishing the daily puzzle, win or lose, counts as activity for the streak (3.5); a leaderboard covers one game and one day, for logged-in players only (3.1). The geometry game has no board (decision 58).
52. **[decided]** Word game: there is one streak across both languages (finishing the 5-letter puzzle in English or in Russian keeps it alive; this replaces my reading of decision 30); the Russian letters ё and е are one letter; the word lists come from SCOWL or ENABLE for English and OpenCorpora for Russian, after their licenses are checked at the source (3.8).
53. **[decided]** Names and order: the word game, the hidden-character game (working title "Waldo", decision 45), the geometry game and the playable challenge keep their working titles until before launch; public names are chosen then and checked for trademark clashes. The games come in this order: the game guesser, the word game, the movie game, the geometry game, the hidden-character game, the playable challenge.
54. **[decided]** Playable challenge, play and results: one attempt per day; replays are recorded from the first release and only verified results are ranked; the board is daily only and ties go to the earlier result; every challenge has a time cap of about 2 to 3 minutes set when it is prepared, and pausing is allowed because game time does not run while paused (3.10).
55. **[decided]** Playable challenge, content: ROMs are open-licensed homebrew, or homebrew with the author's written permission, each license or permission recorded and approved by the owner before the ROM enters the vetted list; each challenge is prepared once by a person (game, level, objective, start state, result rule) and the script schedules the prepared challenges in rotation; the ROMs and the emulator are self-hosted on our own origin and run in the player's browser, which confirms the reading of decision 40.
56. **[decided]** Hidden-character game: the result is the time only, with no penalty for wrong clicks and no points figure (a pause between clicks and a cap of about 60 clicks stop blind clicking); the daily board is global for logged-in players, accepting that solver programs cannot be blocked (risk 20); the target card is a picture with a short caption, and extra unranked targets come later; the minimum phone is about 3 GB of RAM at 4096-pixel scenes (3.11).
57. **[decided]** The module contract gets the timed-search step, `begin_attempt` and `submit_click` (3.3).
58. **[decided]** Geometry game: a wrong guess says only right or wrong; figures are drawn not to scale on purpose; there are 4 steps (the figure and 3 clues) with three clue types, pointing, intermediate result and last step (teaching and extra-element clues return later, the extra element with the Sunday special); the end screen shows the full derivation step by step, and a collection of the rules a player has used can come later; there is no board, only personal stats and the guess distribution; other exercise types (areas, "which figure is impossible", "which rule applies") come later as variants (3.12).
59. **[decided]** Production practice (ARCHITECTURE.md): trunk-based branching with pull requests; two app repos plus a third platform repo for the specs, `CONTRACTS.md`, the integration Compose file, end-to-end tests, deploy workflows, ADRs and runbooks; both app repos stay public, so puzzle answers and unreleased puzzle data are never committed and the generator's seed includes a secret kept outside the repo; releases deploy through GitHub Actions over SSH with Compose; API routes live under `/v1` from day one.
60. **[decided]** Backend and tooling choices: passwords use argon2id; background jobs use arq behind a thin interface; errors are tracked with the Sentry free cloud plan; there is no bot protection for now (rate limits only; ALTCHA is the option if abuse appears); the frontend uses react-i18next for translations.
61. **[decided]** API errors use an RFC 9457-compatible body with `code`, `params`, `request_id` and a field `errors` list; the frontend translates by `code` (ARCHITECTURE.md section 5).
62. **[decided]** Hosting is not chosen yet: the owner wants the free or cheapest option and decides when ready; the design stays portable (Docker Compose, Caddy, S3-compatible storage), and research on free and cheapest hosting waits until then. Puzzle files go to S3-compatible object storage (Hetzner Object Storage, no CDN at first; until the S3 client is needed they can sit on the server's disk), and Postgres runs on the server with nightly encrypted dumps.
63. **[decided]** The first technical tasks start now (ARCHITECTURE.md section 15, tasks 1 to 4): CI and lint fixes, the password and logging fixes with auth tests, putting the specs under git and removing the stale MyList sections from `CONTRACTS.md`, and the error contract with health endpoints and production settings checks.
64. **[decided]** Layout (2026-10-28): the existing sidebar stays and becomes the site's "nav bar" (decision 4): brand, games, archive link, and at the bottom language, theme and the login or account menu. On phones a slim header with a sidebar button, the brand and "Log in" opens the sidebar as a panel. The sidebar keeps its remembered open or closed state.
65. **[decided]** Phase 0 shell answers (2026-10-28), details and acceptance criteria in `specs/01-phase-0-rebrand-optional-login-shell.md`: `/lists` is removed (unknown paths show the in-layout not-found screen); a signed-in user keeps the reset token; the game list is a static frontend registry until `GET /v1/games` (Phase 1); the public page does not wait for `/auth/me`; the brand stays Latin in Russian with a Russian tagline; the OpenAPI title becomes "Daily Game Challenge API"; the first game's slug is `game-guesser`; logout stays on a public page; auth pages keep their own layout; the favicon is a temporary letter mark.
66. **[decided]** Old names (2026-10-28): the frontend and backend package names and the database names are renamed now (proposed names in the Phase 0 spec, AC-8: `daily-game-challenge-fe`, `daily-game-challenge-be`, `daily_game_challenge`, `daily_game_challenge_test`). Repo folder and GitHub repository names stay (decision 26).
67. **[decided]** Phase 1 backend answers (2026-11-02), details and acceptance criteria in `specs/02-phase-1-backend-core-games.md`: a play is daily if its first guess reaches the server on the puzzle's UTC date; the guest merge replays every guess and trusts the client's "played as daily" flag (merged rows marked `origin = merge`, the account's row wins); the 3-day grace means day 1 and day 5 give a streak of 2 and today is not missed until it is over; step 6 is a muted looping video clip (H.264 MP4, optional WebM, with a WebP poster frame), not an image; four puzzle statuses with no `published`, visibility computed from the date, `GET /v1/games/{slug}/puzzles/{date}` with a `/today` alias; guests resume through `POST .../resume`; every puzzle response is `private, no-store` and every clue file is a signed link; guest stats are computed in the browser against shared test tables; a guess is correct by title or normalized name, and a duplicate guess is a 422 that uses no guess; an expired session on game routes is treated as a guest; Phase 1 keeps the visibility function and an `is_test` flag as roles hooks; the CSRF Origin check (M1-41) moves into Phase 1, with no custom header, and the API's own origin is allowed in `local` and `test`; `GET /v1/clock`; one global title table with a `kind` and the year shown in search; the puzzle number is derived from the game's launch date; search needs 2 to 100 characters and is never padded to 200.
68. **[decided]** Phase 3 content answers (2026-11-12), details and acceptance criteria in `specs/04-phase-3-content.md`: before using IGDB screenshots the owner emails partner@igdb.com, because the IGDB FAQ and the Twitch agreement disagree on storing changed images, and work stays in `local` until IGDB says yes or the owner accepts the risk in writing; the step-6 clip is built from 2 or more unused screenshots (about 12 s of pan and cross-fade), not from trailers; the step-2 hint becomes a new `critic_score` kind labelled "Critic score", shown with at least 4 critic scores (IGDB has no Metacritic); a puzzle's date is optional until it is scheduled, which allows a pool of approved spares; answers are main games, remakes, remasters and expanded games released at least a year ago, with 7 or more screenshots of at least 1280x720 and 50 or more ratings; the franchise comes from IGDB's main franchise, else its first series; an answer never repeats and no two answers of one series fall within 14 days; the search list holds main games, remakes, remasters, expanded games and standalone expansions with at least 1 rating, plus every candidate; a rejected draft is deleted and an exclusion records "rebuild" or "never"; review happens in a tiny local page; credits are a Sources section on the end screen linking each game's igdb.com page, with no API change; the footer line "Game data and images: IGDB.com" lands with M1-46; the scripts run on the owner's workstation with the target environment named on each run; the buffer check exits 2 when tomorrow is missing or broken, 1 when under 7 days, and a separate code when it cannot check.
69. **[decided]** Phase 3 plan answers (2026-11-12), details in `plans/04-phase-3-backend.md` and `plans/04-phase-3-frontend.md`: a new task M1-24c promotes approved puzzles (rows and files) from local review to the target, refusing a non-local target until IGDB clears images; a rejected draft is always deleted and "rebuild" lives on the exclusion row (SPEC-04 AC-51 wins over AC-50, which is corrected); the step-6 clip is encoded with PyAV, falling back to `imageio-ffmpeg`, and the owner is asked before ffmpeg is added to CI; real puzzles live in a separate local content database, because `seed_dev.py` wipes the game's puzzles; the planned names (`answer_exclusions`, `build_slot`, `generator_version`, `approved_at`, `source_image_ids`, `PUZZLE_SEED_SALT`, `IGDB_IMAGES_CLEARED_BY`) stay; the planner's defaults are accepted: "ratings" means IGDB `total_rating_count`, the buffer check exits 3 on usage errors and crashes, critic scores round half up, the clip starts at 12 s, 24 fps with 1 s fades and no WebM, the review page accepts only its own requests, the title import refuses to change a referenced title's name, franchise or kind, an expired Sources thumbnail falls back to "Clue N", the link text drops "www.", and the `metacritic_score` label is dropped.
70. **[decided]** File size unit (2026-11-13): in the clue file limits (SPEC-02 AC-74b, `CONTRACTS.md`), 1 MB means 1,048,576 bytes, as the code and tests already use; M1-22b writes this into `CONTRACTS.md`.
71. **[decided]** Rebuild rule (2026-11-13, SPEC-04 AC-52): a draft rejected as "rebuild" is rebuilt avoiding every screenshot of every rejected draft of that slot (the union of its rebuild rows' image ids), not only the stills, so a bad clip screenshot cannot return. If fewer than 7 eligible screenshots remain, the builder reports the slot as not rebuildable, and one builder command (M1-22d) turns its rebuild rows into a "never" exclusion, freeing the slot. `--counts` shows how many candidates have the 14 or more screenshots one rebuild needs.
72. **[decided]** Promote and launch-date answers (2026-11-19, M1-24c): AC-59 stays strict, so no tool unschedules today's or past puzzles, even for a disabled game. A disabled game can still move its launch date; puzzles dated before the new date stay scheduled and hidden, and their answers stay used. A promote re-run may put back files the target's own rows name and the store lost (rows are never changed); a lost file that the source no longer has makes the run exit 1.
73. **[decided]** Image source for now (2026-11-20): the site is a learning project with no production launch decided, so it uses the IGDB screenshots the builder already fetches (the "gray" route in `reports/Free game data and screenshot sources.md` and `reports/Simple free game image sourcing.md`), without waiting for IGDB's answer. Safeguards: no Nintendo or Pokémon games; no ads or paywall; a visible removal contact and a credit per game; IGDB attribution kept. `IGDB_IMAGES_CLEARED_BY` names this decision when images must leave `local`. Before any real public launch or monetization, this is revisited: the reports recommend self-captured screenshots sorted by each publisher's fan-content policy.

## 3. Product requirements

### 3.1 Core (MVP)

- A nav bar with one entry per daily game. Selecting a game shows it on the main screen with no page redirect.
- One puzzle per game per day, the same for every player, switching at 00:00 UTC.
- A "new game in hh:mm:ss" countdown.
- Play without an account. Progress for the current day survives a reload.
- A screen listing all past days per game, from which the player picks one to play. See 3.4.
- Logged-in players have progress stored on the server and available on any device.
- A leaderboard, visible to everyone, with entries only from logged-in players. One board per game and per day (decision 51); each game's score is decided in its own spec.
- **[proposed]** Per-game stats: played, win rate, current streak, max streak, guess distribution. Streak rules are in 3.5.
- **[proposed]** A spoiler-free shareable result.
- **[decided]** Responsive layout for laptops, tablets and phones (3.6). A legal footer with its pages (3.7).
- **[proposed]** Dark mode, keyboard and screen-reader support, colorblind-safe feedback colors.

### 3.2 Guest vs account **[proposed]**

| Capability | Guest | Account |
|---|---|---|
| Play today's puzzles | yes | yes |
| Play archive | yes | yes |
| Progress kept on this device | yes (browser storage) | yes |
| Progress across devices | no | yes |
| Stats and streaks | this device only | server, all devices |
| Leaderboard entry | no | yes |
| Merge of guest progress on first register or login | n/a | yes, so signing up never loses a streak |

The reference site charges for the account-style extras (sync across devices, export and import of stats, no ads). Here those are free account features.

### 3.3 Games are modules, not one mechanic **[decided]**

The reference's sister sites show how different the games are. The game guesser reveals screenshots one by one and compares franchise and platform after each wrong guess. A Wordle-like game takes letters and colors them by position. They share almost nothing at the guess level, so the site must not hard-code one mechanic.

The shared site owns:
- the nav bar, layout, auth, countdown, archive list, stats container and share button;
- identifying a puzzle by `(game, variant, date)`, where a variant is a game's option set (the word game's language and length, see 3.8; most games have a single variant);
- storing progress per `(user or guest, game, variant, date)`.

Each game module owns:
- what a puzzle contains and what the player sees;
- what a guess is and what feedback it gets;
- how a puzzle is won, failed and scored;
- its own input component, result view and share text.

**[proposed]** The module contract, kept thin on purpose:
- Backend: `get_puzzle(date, progress)` returns the public view of a puzzle for a given progress state (never the answer until the game ends); `submit_guess(puzzle, progress, guess)` returns feedback and the new progress state.
- Frontend: a registry mapping the game's slug to its component, loaded when the game is opened.
- Where several games do share a mechanic, they reuse a component. That is an optimization found while building games, not a design constraint.
- **Clue ladder [proposed shared mechanic].** The game guesser and the movie game work the same way: a fixed number of steps, each step reveals more (an image, a video or a text), possibly with a metadata hint, and each wrong guess or skip moves to the next step. The guess is a title picked from a search list. The two games differ only in what each step shows and which hints appear. One clue-ladder module, configured per game with its step list, covers both and the "poorly described" text variants (section 4). The geometry game (3.12) is a third user of it: each step adds an element to a drawn figure, and the guess is a number, not a title, so the module's guess input and the content of a step must be configurable.
- **Playable challenge [proposed].** The contract above is built around guesses, and a playable challenge has none: the player plays, then submits a run (the recorded buttons and the claimed result), and the backend replays it to decide the outcome (3.10). So it keeps `get_puzzle` (the day's challenge: ROM, start state, objective, time cap) and replaces `submit_guess` with `submit_run(puzzle, progress, run)`. Its frontend component owns the emulator, the controls and the result view.
- **Timed search [decided, decision 57].** The hidden-character game (3.11) has clicks, not guesses, and a clock the server measures. So it adds an attempt step: `begin_attempt(puzzle)` starts the clock and returns what the player may see, and `submit_click(attempt, click)` returns miss, decoy or hit. Like the playable challenge it keeps `get_puzzle` and replaces `submit_guess`.

### 3.4 Archive

**[decided]** Previous days are playable, from a screen that lists all previous days' puzzles for a game. The player selects one and plays it on the same screen, with no redirect to another site. Archive results count toward stats only (played, win rate, guess distribution), never toward streaks or the leaderboard. So the archive cannot be used to repair a streak or climb the board.

**[proposed]** Details for the archive list, to settle in its own spec:
- Each entry shows the date and puzzle number, and the player's state for it (not played, in progress, won with N guesses, lost). The answer is never shown in the list.
- Today's puzzle is not in the list; it is the main view.
- Each puzzle has its own URL, so a past puzzle can be shared by link.
- No login is needed. For a logged-in player the states come from the server; for a guest, from browser storage.
- The list can be long (the reference is at puzzle #1626), so it needs paging or grouping by month.

How the reference does it (verified in the browser): the same screen with previous and next arrows, a date shown for archive puzzles, a URL per puzzle (`/p/1622`), and no login needed. It has a "Play Previous Days" button on the end screen too. We replace the arrows with a list, as decided.

### 3.5 Streaks

**[decided]** A streak survives up to 3 days without activity and is discarded after that.

My reading, to confirm: the streak is per game. It counts consecutive days on which the player completed that game's daily puzzle (today's, not the archive). Up to 3 skipped days in a row do not break it and do not add to it. A fourth skipped day in a row resets the streak to zero. Max streak is kept. Days are UTC days, per decision 10.

**[decided]** (decision 51) Finishing the daily puzzle, win or lose, counts as activity for the streak, for all games unless a game's own spec says otherwise. A win-only streak can be a separate stat if a game wants one.

### 3.6 Responsive design and a future mobile app

**[decided]** The web site is flexible and looks good on laptops, tablets and phones. Gameplay (images, input, clues, feedback) must work at every size without horizontal scrolling and with touch controls. The nav bar adapts to narrow screens.

**[decided]** A React Native app is planned for later, after the main web parts work. Nothing in this spec asks for it now. Consequences to keep in mind so the door stays open:
- All game logic that decides outcomes lives in the backend API (see section 6), so a second client reuses it.
- The frontend keeps game logic out of UI components, so some of it can be shared later.
- Auth today is a session cookie. A native client may need a different transport (for example a token), so check this when the app starts. It is not a requirement now.

### 3.7 Legal footer and pages **[decided]**

The reference's footer is the model (inspected 2026-10-26). Ours needs:
- **Rights notice.** All screenshots, titles, logos and artwork belong to their owners and are used to identify the game; the site is not affiliated with or endorsed by any publisher, studio or developer. It is the project's main answer to the image-rights risk in section 8. It is not legal protection by itself, and it does not cover hosting a playable ROM (3.10, risk 11).
- **Contact email** for rights holders to request removal, and for puzzle problems.
- **Privacy policy page.** It must state what we store: email, password hash, progress and sessions on the server, and guest progress in the browser's storage. If we add analytics or ads later, the policy is updated first.
- **Source credit per puzzle.** After a game ends, the player can see the original images and where each came from. The puzzle script stores a source URL for each image. The reference does this with a "Screenshot Sources" page (`/ogi/{puzzle number}`) and a "View Source Image" label on the clues.
- **[proposed]** A short terms-of-use page. The reference has none visible, but we take accounts.
- Not needed now: a cookie consent banner (no analytics, ads or tracking; the login session cookie is strictly necessary), an affiliate disclosure and retailer links (no monetization).

The reference's footer also has an affiliate disclosure (it earns commissions from retailer links), a music disclaimer for its audio site, and a Privacy Manager button for its ad-consent tool. Its privacy policy names Google Analytics, the Meta Pixel and its ad provider, and covers access, correction, deletion and opt-out rights. It has no section on children and none on browser storage. We should cover both.

This is general information, not legal advice. Get it checked before launch.

### 3.8 Languages and game variants **[decided, details proposed]**

**Site language [decided].** The interface (nav bar, buttons, dialogs, help text, legal pages, error messages) is available in English and Russian. The user picks it with a switcher. **[proposed]** The first visit uses the browser's language if it is English or Russian, otherwise English. The choice is saved in the browser for guests and on the account for logged-in players.

**Game content language [decided].** A game's puzzle language is a separate setting from the site language. Only the word game has this option for now. Example: the site in English and the word game in Russian.

**Word game options [decided]:** puzzle language (English or Russian) and word length (4, 5, 6 or 7 letters, 5 by default).

What that means (proposed, to confirm in the word game's own spec):
- **One daily puzzle per combination.** A language and a length make a variant: 2 languages × 4 lengths = 8 variants, so 8 words per day. Each variant has its own puzzle, progress, stats, guess distribution, archive and share text. A player who switches variants plays a different puzzle, not the same word translated.
- **One streak for the whole word game [decided, decision 52].** Streaks count only for the default length, 5 letters, and the streak is shared by both languages: finishing the 5-letter puzzle in English or in Russian counts for the day. The other lengths (4, 6, 7) are extra play with no streak.
- **Stats and leaderboard for extra variants [proposed].** Extra variants count toward stats (played, win %, guess distribution), like the archive in decision 14, but never toward streaks or the leaderboard.
- **Leaderboard** is per default variant, for the same reason.
- **The option is part of the screen,** a selector near the board, remembered per player. Changing it in the middle of a puzzle does not lose the progress of the other variant.
- **Russian specifics.** A Cyrillic on-screen keyboard and physical key support. The letters ё and е are one letter [decided, decision 52]: the Russian clones I found do the same and remove the duplicates that creates, so there is one letter in the grid.
- **Word data.** English and Russian each need an answer list and a guess list for each length from 4 to 7. See "Word sources" below.
- **Other games.** The game guesser and the angle game have no language option now. The game guesser stays English only (decision 32).

**How the interface is translated [proposed].** Texts live in translation files, one per language. The backend returns error codes, not text, so the frontend shows the message in the selected language. Dates and numbers follow the language. Legal pages (3.7) need a Russian version too. A standard frontend i18n library fits React; the choice is made in the shell's spec.

**Word sources (licenses not yet confirmed).** What my search found:
- English: SCOWL, a collection of word lists with a permissive license that requires keeping its copyright notice; ENABLE, a long-standing list used for word games, described in Debian's notes as public domain. Both can be filtered by length. Check each license text before use.
- Russian: OpenCorpora, an open Russian dictionary (about 395 thousand words and forms, according to one clone's author). Its own license is not confirmed by my search; check opencorpora.org. One Russian clone kept only 5-letter nouns, replaced ё with е, and removed duplicates.
- Clones use nouns as answers; allowed guesses are usually a wider list than the answers. This is how the NYT version works too (section 4). Choice **[decided]** (decision 52): SCOWL or ENABLE for English and OpenCorpora for Russian, after their licenses are checked at the source.

### 3.9 Settings, rank and archive screen details seen in the reference **[proposed]**

These come from Guess The Angle and apply to the whole site. All are candidates, not agreed requirements.

- **Archive screen:** one row per past puzzle with the player's guess results shown as colored boxes (unplayed, skipped, incorrect, correct), a status text, "Back to current game", "Play random game" and "Share all games". It extends decision 20. The reference lists every puzzle on one page; with a few hundred puzzles that works, with thousands it needs paging.
- **Settings page:** sharing options (include rank, include site link, link to the puzzle), gameplay options (such as a harder mode), an email notification when a new daily puzzle is available (accounts only), and stats export and import.
- **Rank:** a title earned by wins, with "N more wins to rank up". It is a cheap retention feature that does not punish a missed day the way a streak does.
- **Results endpoint:** a public way to fetch a user's result for a puzzle. Not needed now; it would need care for privacy.
- **Hard mode** as an optional per-game setting: a harder variant of the same puzzle, chosen by the player.

### 3.10 Playable challenge (Game Boy) **[decided direction, details proposed]**

The owner's idea (decisions 39 and 40): the player opens the page and has to finish one level, last longer, or get a higher score in a Game Boy game, and the challenge is different each day. The site hosts the ROMs and runs them in its own emulator. The findings behind the proposals below are in section 4 ("Playable game family").

Terms used here. A **run** is one attempt at the day's challenge. A **replay** is the record of the buttons the player pressed, each with the emulator's tick count (4,194,304 ticks per second of game time). A **start state** is a saved emulator state at the beginning of the challenge, such as the first moment of a level; every player starts from the same one. A **result rule** says how the result is read from the game's memory: an address for the score, a flag for "level complete", a flag for "game over". **Verification** is the backend running a replay again to get the result itself.

What the player does **[proposed]**:
1. Sees today's challenge: the game's title, author and license, the objective, and a Play button.
2. Plays from the start state, with the keyboard, a gamepad, or on-screen buttons on a touch screen (decision 21). Sound starts after the first tap or key press, because browsers block it before that.
3. The run ends when the result rule says so (level complete or game over) or at the challenge's time cap, which keeps it short (decision 6).
4. Sees the result and, once verified, the rank among today's verified results. The run is stored for the stats.

Objectives. The three types are **[decided]**; how each is measured is **[proposed]**:

| Objective | Result | The run ends at | Better is |
|---|---|---|---|
| Finish one level | time to finish | level complete, or the cap (not finished) | lower |
| Last longer | time survived | game over, or the cap | higher |
| Get a higher score | the score read from memory | game over, or the cap | higher |

Time is game time (ticks), not the clock, so a slow phone or a pause does not change a result.

Integrity and fairness **[proposed]**:
- A result sent by the browser cannot be trusted, because anyone can change what the page sends. So the browser sends the replay, and the backend runs it again from the same start state on the same emulator code and reads the result with the result rule. Only results the backend got itself are ranked. The evidence and the open gaps are in section 4.
- Challenge mode has no rewind, fast-forward, save states or cheat codes. The emulator's own demo has the first three; we leave them out.
- A start state and a replay only work on the emulator build that made them. Each challenge records its build, and the archive keeps every build a challenge used (a build is about 100 KB), so old days stay playable and verifiable.
- Release order **[decided]** (decision 54): record and store replays from day one; rank only verified results.
- Attempts and board **[decided]** (decision 54): one attempt per day; a daily board only, with ties going to the earlier result; a time cap of about 2 to 3 minutes set per challenge; pausing is allowed, because game time does not run while paused.
- Content **[decided]** (decision 55): open-licensed homebrew or homebrew with the author's written permission, each recorded and approved by the owner; challenges are prepared once by a person and scheduled in rotation by the script.

How the shared parts apply:
- Archive (3.4, decision 14): past challenges are playable from the list; their results count toward stats only, never toward streaks or the leaderboard.
- Streaks (3.5) **[proposed]**: a day counts when the player ends a run (finish, game over or cap) on that day's challenge.
- Guests (decision 16) **[proposed]**: a guest can play and keep their best result in the browser, and the backend can verify a run without storing it. Guests are not on the leaderboard (3.1).
- Day boundary (decision 10): the challenge switches at 00:00 UTC. **[open]** A run started before midnight and ended after it belongs to the day it started.
- Languages (3.8): the page around the game is translated; the game's own text is whatever the ROM has.
- Legal (3.7): the rights notice there covers screenshots used to identify a game, not a playable ROM. Each hosted ROM needs a documented right to distribute (risk 11) and a credits entry with title, author, license text and source link.

### 3.11 Hidden-character game (find it) **[decided direction, details proposed]**

The owner's idea (decision 41): one large picture full of small characters, one character to find, no clues, a timer. Working title: Waldo, for internal use only (decision 45). The research behind the proposals below is in section 4 ("Find-it game family"); how the scenes are made is in section 7.

Terms used here. The **scene** is the big picture. The **target** is the character to find, and the **target card** is a small picture of it shown to the player. A **decoy** is a similar character that is not the target. An **attempt** is one go at the day's puzzle. A **miss** is a click that is not on the target.

What the player does:
1. **[decided]** Opens the page and sees a placeholder instead of the picture, plus what to find.
2. **[decided]** Presses Start. The placeholder is removed, the scene appears and the timer runs.
3. **[decided]** Looks around and clicks or taps the place where the target is. **[proposed]** The scene is larger than a phone screen at full detail, so the player can pan and zoom (pinch, wheel, buttons, keyboard).
4. **[proposed]** A correct click ends the attempt and the result is the time. A wrong click shows a short mark and a short pause; it does not add time (see Score).
5. **[proposed]** Sees the result, the rank among today's results, and a share text without spoilers.

Rules **[proposed]**:

| Topic | Proposal |
|---|---|
| Score | **[decided]** The timer counts up from 0:00 when the picture is shown, and the faster the player finds the target, the higher the score. The result is the time, measured by the server; the board ranks the lowest time first. **[decided]** (decision 56) No time penalty for wrong clicks and no points figure. A pause between clicks and a cap of about 60 clicks stop blind clicking: by my arithmetic, 60 clicks with a 40-pixel hit radius cover at most about 3% of a 4096x2730 scene (60 x pi x 40^2 is about 0.3 million of 11.2 million pixels). If playtests show spamming, a penalty can be added later (the research suggested 5 seconds per miss). |
| Wrong clicks | The answer is only miss, decoy ("not this one") or hit. Never a distance or a hot/cold hint, because a few distance answers would pin down the target. A pause of about 400 ms between clicks and a cap on clicks per attempt (about 60). No lives: fat-finger taps on a phone make strikes feel unfair. |
| Time limit | **[decided]** None. A give-up button reveals the answer, and an unranked relaxed mode hides the timer, for players who find a clock stressful. |
| Target card | **[decided]** (decision 56) A picture plus a short caption in the site language. A picture works in any language; a name alone is ambiguous ("a man in a hat"). After Start the card shrinks to a button that reopens it. |
| Attempts | For accounts the first attempt counts (the NYT Mini records the first solve only). Archive attempts count toward stats only (decision 14). |
| Streak | A day counts when the attempt ends, found or given up (3.5 default). |
| Leaderboard | Logged-in players only, per day. Order: final time, then fewer misses, then earlier finish. Postgres ordering is enough at this size. Guests play and keep their best time in the browser, unranked. |
| Share text | No coordinates. For example: the game's name, the puzzle number, "found in 0:47, 1 miss" and a link. |
| Difficulty | Set by generator settings (target size, how hidden the target is, crowd density, look-alike decoys) and checked with computed metrics. A weekday curve (easier early in the week, harder at the weekend) and a median solve time of about 20 to 60 seconds are my proposals; replace them with real medians after launch. |
| Accessibility | Zoom buttons and a keyboard route in addition to pinch (section 4). Honest limit: a blind player cannot play a visual search. |

The clock **[proposed]**: the server owns it. The server creates the attempt when the player presses Start and issues short-lived picture addresses. The page reports "picture painted" and the clock counts from that report, but no later than 15 seconds after the attempt was created, so a player cannot delay the report to study the picture. The final time shown is the server's. An attempt survives a reload and runs on wall-clock time, with no pause. The page's stopwatch is only for display.

Guests **[proposed]**: the server signs a token that carries the start time and the miss count, and returns a new one after each click, so decision 16 holds (no server state for guests). A guest could reuse an old token to hide misses; that only matters for ranking, and guests are not ranked.

Fit with the module contract (3.3) **[proposed]**:

| Module concept | This game |
|---|---|
| Puzzle | One scene, the target card and caption, the target's shape and the decoys' shapes (kept on the server), the rules (hit area, click limits), the credits |
| Guess | A click: its position in the picture as numbers from 0 to 1 |
| Feedback | miss, decoy or hit, the miss count so far, and on a hit the final time |
| Win rule | Hit the target (giving up counts as played, not won) |
| Score | Final time in milliseconds, lower is better |

First version **[proposed]**: scenes made by the script from openly licensed parts (section 7), at least 60 before launch; each scene as a 4096-pixel WebP plus a 1024-pixel first picture; the attempt flow; the viewer with buttons and keyboard; a board for accounts and none for guests; share text, archive and a time histogram. Later: tiles with a deep-zoom viewer, a friends board, extra targets in the same scene, hand-drawn scenes, a hint system, the React Native app. Spikes first: section 10, step 6. Minimum phone: about 3 GB of RAM (decision 56).

### 3.12 Geometry game (find the unknown) **[decided direction, details proposed]**

The owner's idea (decision 46): a geometry exercise, such as finding an angle in a triangle, played like the game guesser. With each step the player gets an additional clue: other angles, formulas, or additional elements that help the calculation. It is the owner's own idea, so there is no reference site to copy. Decision 47 widens it: the unknown can also be the length of a side, a radius or another part of the figure. What exists, and what the research suggests, is in section 4 ("Geometry exercises") and the generator plan is in section 7. It keeps the working title "the geometry game" until a public name is chosen (decision 53).

Terms used here. The **figure** is the drawing: points, lines, circles and marks. The **givens** are the facts shown at the start (angles and lengths with values, equal sides, parallel lines, right angles). The **target** is the unknown marked x: an angle, or a length such as a side, a radius or another segment. A **clue** is something added to the figure or the text after a wrong guess or a skip. A **rule** is a standard fact that leads from known angles to a new one (the angles of a triangle add up to 180 degrees, base angles of an isosceles triangle are equal, and so on). A **derivation** is the chain of rule steps from the givens to the target.

What the player does:
1. **[decided]** Sees a figure with some values given (angles, or lengths) and one unknown marked x, and enters the value of x: degrees for an angle, plain units for a length.
2. **[decided]** A wrong guess, or Skip, adds the next clue: another angle, a formula, or an extra element that helps the calculation.
3. **[proposed]** The game ends on the right answer or when the last clue has been used and guessed on. The result is the number of guesses used (decision 9).
4. **[proposed]** The end screen shows the whole derivation step by step, with the rule named at each step, and a share text without spoilers.

Design proposals **[proposed]**:

| Topic | Proposal |
|---|---|
| Target kinds | **[decided]** The unknown is not only an angle (decision 47): it can be a side length, a radius, or another length such as a chord, a tangent or a part of a divided side. The kind of the day is drawn at random (decision 48), not planned by weekday and not picked by the player. "Random" means the generator draws it with a seed when it makes the puzzle; once the puzzle is scheduled it is fixed, so everyone gets the same puzzle on a given day. **[proposed]** A small rule keeps the variety the owner wants: the same kind not more than twice in a row. Angle puzzles use sums of angles, equal angles and parallel lines. Length puzzles use the Pythagorean theorem, similar triangles and proportional sides (a line parallel to a side), the angle bisector theorem, and chords, tangents and radii. One figure family can serve both kinds (a triangle with lines through its vertices). |
| Solvable from the start | The figure at step 1 already has enough givens to find x by reasoning. Clues shorten the way; they do not supply missing data. If the first figure left x open, the first guesses would be blind guesses (among about 179 values for an angle, and among many more for a length). |
| Guess | A whole number: degrees for an angle, plain units for a length (the figure shows numbers without a unit name). Every answer is a whole number, because the generator builds figures from whole-number parameters: whole degrees for angles, and for lengths Pythagorean triples and whole-number scale factors. Answers such as 5 times the square root of 2, or 36/25, are left out of the first version (decision 49) because they need a different input; they can come later. |
| Feedback | **[decided]** (decision 58) Right or wrong, nothing more. No higher/lower and no warm/cold: with those a player could find x by trial (about 8 guesses by halving), and the point of this game is the reasoning. The angle-estimation game (section 4) is the opposite on purpose. |
| Figure scale | **[decided]** (decision 58) Drawn "not to scale" on purpose: point positions vary within limits and the page says so, so the answer cannot be read off with a protractor, a ruler or by eye. Labeled lengths are not drawn in proportion either. |
| Number of steps | **[decided]** (decision 58) 4: the figure and 3 clues. A skip costs a guess, like a wrong answer. |
| Clue types | **[decided]** (decision 58) Three types, in this order: (1) **Pointing:** highlight the triangle, the circle or the pair of lines to look at, or mark equal sides. (2) **Intermediate result:** an angle or a length the player would have had to find on the way. (3) **Last step:** the formula for x with its values marked, for example "x = 180 - a - b" or "r = AB / 2". Later, as the game grows: **teaching** clues (name the rule or show the formula, for example "a squared + b squared = c squared") and **extra-element** clues (a line or point added to the figure, needed for the Sunday special). |
| Every clue must help | At generation time a clue is kept only if it shortens the derivation (intermediate result, last step) or points at something the derivation uses (pointing). A clue that does neither is rejected. |
| Difficulty | By weekday: the weekday sets the tier and the kind is drawn at random (decision 48), so the generator builds a puzzle of that tier from the drawn kind's rules. Early in the week: angles in a triangle, on a line and vertical angles, and a side from the Pythagorean theorem. In the middle: parallel lines, isosceles triangles, similar triangles and proportional sides. Later: circle rules (inscribed angles, chords, tangents, the radius of the circle through a right triangle). A Sunday special where the last clue is an extra line (a famous hard problem). Measured by the length of the shortest derivation and the number of different rules it needs; an angle puzzle and a length puzzle with the same step count are not equally hard, so the ratings are tuned per kind by playtest. |
| Notes | The player can tap an angle on the figure and write a value, like pencil notes. No effect on the result. |
| Accessibility | The figure is generated from a list of facts, so the same list gives a text description for screen readers ("Triangle ABC. Angle A is 40 degrees. AB equals AC. ..."). The game does not depend on seeing the picture, unlike the hidden-character game. Colors never carry the only meaning. |
| Languages | The figure and numbers are language-free. Only clue texts and rule names need translating (English and Russian). |
| Streak, archive, stats | The shared rules (3.4, 3.5). A day counts when the attempt ends. Stats count the guesses used. |

Worked example (checked by hand, and with a numeric construction that gives 30.0 degrees): triangle ABC with AB = AC and angle A = 40 degrees; D lies on AC with BD = BC; find x = angle ABD. The derivation has 5 steps: (1) angle ABC = angle ACB = 70 degrees (isosceles, angle sum); (2) angle BCD = angle ACB = 70 degrees (D is on AC); (3) angle BDC = angle BCD = 70 degrees (isosceles, BD = BC); (4) angle CBD = 180 - 70 - 70 = 40 degrees (angle sum); (5) x = 70 - 40 = 30 degrees.

| Step | What the player sees | Steps left |
|---|---|---|
| 1 | The figure with A = 40 degrees, AB = AC and BD = BC marked, x marked | 5 |
| 2 | Pointing: triangle ABC highlighted | 5 |
| 3 | Intermediate result: angle ABC = 70 degrees | 4 |
| 4 | Last step: "angle BDC = angle BCD = 70 degrees (BD = BC), so angle CBD = 180 - 70 - 70, and x = angle ABC - angle CBD" | 1 |

Worked example 2, a radius (arithmetic checked): triangle ABC with a right angle at C, AC = 6 and BC = 8, and a circle through A, B and C; find x = the radius. The derivation has 3 steps: (1) AB squared = 6 squared + 8 squared = 100, so AB = 10 (Pythagorean theorem); (2) the right angle at C lies on the circle, so AB is a diameter (angle in a semicircle); (3) x = 10 / 2 = 5.

| Step | What the player sees | Steps left |
|---|---|---|
| 1 | The figure with the right angle, AC = 6, BC = 8, the circle, and x on the radius | 3 |
| 2 | Pointing: triangle ABC and its right angle highlighted | 3 |
| 3 | Intermediate result: AB = 10 | 2 |
| 4 | Last step: "A right angle on a circle sits on a diameter, so AB is a diameter and x = AB / 2" | 1 |

Worked example 3, another segment (arithmetic checked): in triangle ABC, D lies on AB and E on AC with DE parallel to BC; AD = 4, DB = 2 and DE = 6; find x = BC. Triangles ADE and ABC are similar and AB = AD + DB = 6, so BC = DE × AB / AD = 6 × 6 / 4 = 9.

Fit with the module contract (3.3) **[proposed]**:

| Module concept | This game |
|---|---|
| Puzzle | The figure (points, lines, marks, givens), the target (an angle or a length), the ordered clue list, and, kept on the server until the end, the answer and the derivation |
| Guess | A whole number (degrees or units) |
| Feedback | Right or wrong, and the next clue |
| Win rule | The right number within the 4 steps |
| Score | The number of guesses used (decision 9) |

First version **[decided]** (decision 50): angle puzzles of the early and middle tiers (triangles, straight lines, parallel lines, isosceles triangles), and length puzzles from the Pythagorean theorem and similar triangles, plus the radius of the circle through a right triangle (it needs one circle rule). Other circle rules, the Sunday special and other exercise types (areas, "which figure is impossible") come later. **[proposed]** At least 60 puzzles generated and checked before launch. A generator spike comes first (section 10, step 7).

### 3.13 Roles and admin tools **[proposed]**

The owner's idea (2026-10-30): signed-in users get a role. An admin gets extra tools for testing: play a puzzle, reset their own progress and play it again, and open the next days' puzzles before players get them. More admin tools may come later. This section is research and proposals; nothing here is decided or built. Open questions 2 to 5 (section 9) need answers before a feature spec.

Decision 11 ("No admin UI to start with") still holds under this proposal: puzzles are still made, reviewed and scheduled by scripts. What changes is that a few controls appear on the normal game screen for an admin. It is not an admin panel.

**What exists today (checked in the code, 2026-10-30).** The `users` table has `id`, `email`, `hashed_password`, `is_active`, `created_at`, `updated_at`, and no role. `get_current_user` (`my-list-be/app/api/deps.py`) reads the session from Redis and then loads the user from Postgres on every request, so a role stored on the user is read fresh each time and a change applies at the next request. `GET /auth/me` returns `UserRead` (id, email, is_active, created_at). The frontend keeps the signed-in state only in the `/auth/me` query and drops every other cached query on logout (`signOutLocally`), so puzzle data an admin loaded does not stay in the tab after logout. There is no puzzle or progress code yet (M1-10, M1-13).

Terms used here. A **role** is a name stored on the account (`player`, `admin`). A **permission** is one thing an account may do, such as `puzzle.preview_upcoming`; the code maps each role to its permissions. An **upcoming** puzzle is a scheduled puzzle whose date is after today (UTC). A **test play** is progress that never counts toward streaks, boards or community stats.

**Role model.**

| Option | For | Against |
|---|---|---|
| **A `role` text column with a CHECK constraint, permissions mapped in code (recommended)** | One column and one migration. Checks name permissions, not roles, so adding a role (a reviewer, a tester) changes one map in code, reviewed in a pull request | Changing what a role may do needs a deploy, which is fine with one owner |
| An `is_admin` boolean | Smallest | A second role needs another column, and flags can contradict each other |
| Role and permission tables | Permissions change without a deploy | Needs a UI or scripts to manage them; nothing here needs that |
| A Postgres native `enum` for the role | The database knows the values | Postgres can add an enum value but not remove one, and a value added inside a transaction cannot be used before the commit; Alembic's autogenerate does not see value changes, so each change is a hand-written migration. A text column with a CHECK avoids all three |
| FastAPI `Security` scopes | Built in | Built around OAuth2 tokens and the docs' Authorize dialog; with a session cookie it is an ordinary dependency anyway |

Details of the recommended model:
- `users.role` is `VARCHAR(20) NOT NULL DEFAULT 'player'` with `CHECK (role IN ('player', 'admin'))`. Existing accounts become players through the default.
- One permission map in code: `player` has none, `admin` has all. The first permissions are `puzzle.preview_upcoming` and `progress.reset_own`; candidates for later are in the table further down.
- One dependency, `require_permission(...)`, built on `CurrentUser`: 401 for a guest, 403 with the new code `forbidden` for a player. Every admin route uses it and no route checks a role by hand. This follows the OWASP authorization guidance: deny by default and check every request on the server.
- Rules about a particular object stay in the service, not in the role: "only your own progress", "an upcoming puzzle, not a draft". OWASP prefers attribute checks to role-only checks; here the role grants a capability and the service checks the object.
- The API never sets a role. Registration always creates a player, and a `role` field in a register body is ignored (a test proves it; OWASP API3:2023 covers this mass-assignment case). An account becomes an admin through a script, `uv run python scripts/set_role.py --email <email> --role admin` (in production through `docker compose exec`). Removing the role also revokes that account's sessions.
- `/auth/me` returns `role` and `permissions`. The frontend shows admin controls by permission, never by role name. Hiding controls only makes the UI clearer; the server check is what protects the data.

**Release of upcoming puzzles and admin preview.** ARCHITECTURE.md section 9 already proposes how a puzzle reaches players, which answers "make it available on time": the day's puzzle is a query on the current UTC date. A scheduled puzzle becomes visible at 00:00 UTC because its date becomes today; no job flips a flag at midnight, so a failed job cannot hold a puzzle back. The 23:30 UTC job only warms caches and alerts when tomorrow's puzzle is missing. The stored status `published` in that flow is then redundant (published means scheduled with a date of today or earlier); I propose dropping it.

Who may open a puzzle is decided in one function in the puzzle service. Every puzzle route uses it: today's puzzle, a puzzle by date, the archive, clue images and guesses.

| Puzzle | Guest or player | Admin |
|---|---|---|
| Scheduled, dated today or earlier | yes | yes |
| Scheduled, dated in the future | 404, the same as a missing puzzle (ARCHITECTURE.md section 5: a future puzzle must not be revealed) | yes, within the preview window (open question 3) |
| Draft, in review, or approved but not scheduled | 404 | 404 to start with (open question 3) |

- Admins play upcoming puzzles through the same routes and the same code as players (`GET /v1/games/{slug}/puzzles/{date}` and the guess route). That is what makes the test worth something: there is no separate admin copy of a game that could behave differently.
- A list for admins, `GET /v1/admin/games/{slug}/puzzles?from=&to=`, gives each date, variant, status and whether the admin has played it. For an admin the archive screen shows these days at the top, marked "upcoming, opens in N days".
- Preview means play, not reveal: the answer stays hidden from admins too until their game ends. An answer key for reviewing is a later permission.
- Caching is the main leak risk. ARCHITECTURE.md sections 7 and 9 propose a public, cached step-1 view and a Redis warm-up keyed by date. Rules: a response about an upcoming puzzle carries `Cache-Control: private, no-store`; the public cache and the warm-up are only ever filled for dates up to today; an upcoming puzzle's images go out only as short-lived signed URLs, and the long-cache public URL starts on the puzzle's date; image keys are random, never date-based (already in ARCHITECTURE.md section 10). A test asks the public routes for tomorrow as a guest and as a player and expects a 404 with nothing cached.
- On an upcoming puzzle the countdown reads "opens for players in hh:mm:ss".

Preview window and buffer are two numbers. The owner wrote "prepare challenges 3 days ahead". ARCHITECTURE.md section 9 and MILESTONE-1 plan a larger buffer: an alert when fewer than 7 days are scheduled, and 30 puzzles scheduled before launch. The buffer is how far ahead puzzles exist; the preview window is how far ahead an admin may open them. I propose keeping the 7-day buffer alert; the window is open question 3.

**Test plays and reset.**
- A **test play** flag sits on the progress row and is set when the row is written. Proposed (open question 4): every play by an admin account is a test play, because an admin can see upcoming puzzles and ranking them would be unfair. The owner plays for real with a separate player account.
- Test plays never count toward streaks, the leaderboard or community stats; they are never added to those counters at all. They do appear in the admin's own stats screen, marked as test, so that screen can be tested too.
- The flag is stored, not derived from the current role, so removing someone's role later does not move their old test plays onto the boards.
- `DELETE /v1/admin/games/{slug}/puzzles/{date}/progress?variant=` deletes the caller's own progress for one puzzle and returns 204, also when there was none (repeating it changes nothing). It needs `progress.reset_own`. Nobody can reset another account's progress.
- Game-specific rows (guesses, the hidden-character game's attempts and clicks, the playable challenge's runs) reference the progress row with `ON DELETE CASCADE`, so no game can forget its part of a reset. The module contract (3.3) gains nothing for most games; a game that keeps state outside those tables (for example in Redis) adds a `reset(puzzle, user)` hook.
- After a reset the user's stats for that game are recomputed by one function, `recompute_stats(user, game)`, which the guest merge (M1-15) and data fixes can use as well. Test plays never reached the counters or the boards, so nothing else needs undoing.
- A reset lifts per-game limits on purpose: the playable challenge's one attempt a day (decision 54) and the hidden-character game's "first attempt counts" (3.11) start over for an admin's test play. Test runs still go through replay verification, so the verifier gets tested too.
- Reset of all of an admin's progress for a game is easy to add later; it is not proposed now.
- To test as a guest, an admin opens a private browser window; no "view as guest" feature is needed.

**Security.** An admin can see tomorrow's answers by playing, which makes an admin account the most valuable account on the site.
- A second factor for admin accounts (open question 5). The OWASP MFA cheat sheet says to require MFA for administrative users and to prefer phishing-resistant authenticators (passkeys), with TOTP as the baseline. Proposal: TOTP with recovery codes, set up from the profile page; until it is set up, admin permissions are refused with 403 `second_factor_required`. Passkeys later.
- A step-up "admin mode" (re-enter the password to unlock admin tools for a few hours, as in GitLab's admin mode, whose design used 6 hours, or GitHub's sudo mode) is not proposed now: it guards against a stolen session, and a second factor covers most of that.
- The CSRF Origin check (M1-41) ships before any data-changing admin route reaches production.
- Every admin action is logged with user id, action, game, date and request id (ids, not emails, ARCHITECTURE.md section 9), and goes into the planned audit-log table (ARCHITECTURE.md section 7) once it exists.
- Tests for every admin route: guest 401, player 403 (404 on the shared puzzle routes), admin 200; and a test with an injected clock at 23:59:59 and 00:00:00 UTC for the day an upcoming puzzle opens.
- Both repos are public, so the permission map and the route names are public. That is fine: the protection is the server check, not secrecy.

**Frontend.**
- A `useCan(permission)` hook reads `permissions` from the existing session query, with no second copy of the state.
- An admin bar on the game screen, shown only with a permission: "test play, not counted", the reset button with a confirmation dialog (it then refetches that puzzle), and a day switcher that can go forward into the preview window.
- Upcoming days at the top of the archive list for admins. Anyone else who opens a future URL sees the normal not-found screen.
- The admin components are their own lazy chunk. They hold no secrets (answers never reach the browser before the game ends); the split only keeps the main bundle small.
- New texts and the error codes `forbidden` and `second_factor_required` in English and Russian.

**Contract changes** (`CONTRACTS.md`, in the same pass as the code): `role` and `permissions` in `/auth/me`; the error codes `forbidden` (403) and later `second_factor_required` (403); future puzzles are a 404 for anyone but an admin; the `/v1/admin/...` routes; upcoming-puzzle responses are `private, no-store`.

**Later admin tools** (candidates, not proposed now):

| Tool | Permission | Use | Note |
|---|---|---|---|
| Games in development visible only to admins | `game.preview_unreleased` | Try the next game in production before it appears in the nav | Cheap and worth it once a second game is near; `GET /v1/games` lists it for admins only |
| Open drafts and approve or reject them in the app | `puzzle.review` | Replaces the CLI review queue (M1-24) | Changes decision 11; the CLI comes first |
| Answer key on a puzzle | `puzzle.reveal_answer` | Faster review without playing | Makes an admin session worth more to an attacker |
| Withdraw a puzzle and put a spare in its place | `puzzle.withdraw` | The "bad puzzle today" runbook | A script first |
| Remove a board entry, deactivate an account | `leaderboard.moderate`, `user.manage` | Cheating and abuse | Once there are players |
| Pretend today is another date | none in production | Test the day change and streaks | Belongs in tests with an injected clock, at most a setting in local and staging; never in production |
| Narrower roles: `reviewer` (preview and review), `tester` (reset only) | | A helper who should not see everything | The permission map makes this a code change |

**Where it fits in Milestone 1** (estimates in working days):

| Step | Repo | Est. | Depends on |
|---|---|---|---|
| Role column and migration, permission map, `require_permission`, `set_role` script, `role` and `permissions` in `/auth/me`, tests | BE | 0.5 | nothing, can start now |
| Regenerated client, `useCan`, the new error codes | FE | 0.2 | the step above |
| Visibility rule, preview of upcoming puzzles, admin puzzle list, caching rules | BE | 0.7 | M1-10, M1-18 |
| Test-play flag, reset route, cascades, stats recompute | BE | 0.5 | M1-13, M1-14 |
| Admin bar, reset, day switcher, upcoming days in the archive | FE | 0.8 | the two steps above, M1-30, M1-35 |
| TOTP for admin accounts | BE, FE | 1.5 | before launch, if open question 5 says so |

That is about 2.7 days without the second factor and about 4.2 days with it.

## 4. Reference: guessthe.game

Verified by playing it in the browser on 2026-10-23 (as a guest) and 2026-10-26 (network and script inspection).

**Game guesser (guessthe.game)**
- Daily puzzle with a number ("Game #1623"). Six screenshots, all from the same game, numbered 1 to 6. Only the first is shown; each wrong guess or Skip reveals the next. Six guesses in total.
- The first screenshot of the archive puzzle I opened was heavily degraded (noisy), so early clues can be very hard to read.
- Guess input is a search box with autocomplete over a long list of games (it showed "200 Results" for "Mario"). Guesses are chosen from the list, then Submit.
- Wrong guesses are listed below the input with a red mark. The second screenshot of today's puzzle also carried a hint overlay (Metacritic score).
- Rules from the help dialog: hints are the Metacritic score and the original platform; a guess is colored green (correct), red (incorrect) or yellow (correct franchise, wrong game).
- Stats dialog: per-mode tabs ("Guess The Game", "Guess The Game Cover"), played, won, win %, current streak, max streak, win distribution (1 to 6), best decade chart and a genre radar chart. Some detail is member-only.
- Header icons: favorites, stats, info, help, settings. Footer: social links and email for puzzle issues.
- Membership box: no ads, export and import stats, exclusive content, sync across devices, direct messages, exclusive requests.
- Heavy ads on the sides and bottom.
- Footer disclaimer: all images and titles belong to their owners and are used under fair use; the site is not affiliated with publishers; a contact email for rights holders to request removal. This is what the reference relies on for rights. It is not legal protection by itself.

**Game guesser: clue ladder (puzzle #1500, played to the end)**

| Step | What the player sees |
|---|---|
| 1 | A small pixelated crop of one screenshot, no text |
| 2 | A full screenshot, plus the Metacritic score |
| 3 | A new screenshot, plus the original platform |
| 4 | A new screenshot, plus the genre |
| 5 | A new screenshot, plus the original release year |
| 6 | A gameplay video (about 12 seconds, looping, autoplay), plus the developer |

- Each wrong guess or Skip costs one guess and reveals the next step. A skipped step is listed as "Skipped!". The numbered tabs are locked until their step is reached.
- A wrong guess from the right franchise gets a franchise-match flag (the yellow color from the rules).
- The end screen shows win or lose, the answer, a share button, the guess list, a game description, retailer links and buttons to other modes and the archive. One of these modes is "Guess The Cover".

**Game guesser: images and data**
- Each puzzle is 5 images and 1 video as static files, `gtg_images/{puzzle number}/1.webp … 5.webp` and `video/6.webm`, on a separate image host. Image sizes grow with the step (about 490×267 up to 1158×636 in puzzle 1500), so the files are prepared ahead of time, not cropped in the browser.
- Each puzzle also has a metadata record: description, franchise, release year, Metacritic score, genre, platform, developer, a Backloggd link, a cover.

**Game guesser: search list**
- Each keystroke calls a server endpoint with the query and puzzle type, and gets back exactly 200 results, each with title, franchise and type. The matching is fuzzy: "zlda" finds Zelda games, "half life" matches "Half-Life 2", and a nonsense query still returns 200 loose matches. Exact and prefix matches rank first. A "Loading" state shows while the request is in flight.
- The list has near-duplicate titles (for example a Zelda title with and without a colon).

**Game guesser: what we do differently**
- The reference checks guesses in the browser. In my test on the guesser's archive puzzle #1500 submitting sent no request, while the movie game sent one POST per guess to record results (see the movie section), so the sites may differ. The page loads all six images when it opens, so the reveal is only cosmetic. Its script bundle also contains the metadata for puzzles up to #1644 while today is #1626, so about 18 days of future answers ship to every player. We check guesses on the server and send only the clues the player has earned (section 6).

**Reference gaps**
- I did not inspect the share result format, the sign-up flow, the settings menu, favorites, the "Quest" mode, the "Poorly Described Game" mode or the mobile layout. Per decision 24 these are skipped for now. I also did not confirm the reference has a leaderboard; a third-party listing says so.

**Sister sites**
- Twelve sites on separate domains: Audio, Book, Movie, Logo, House, Angle, Phrase, Grid, Secret Word, plus casual games (Kinda Hard Golf, Squishy Billiards, Lawndle). Navigation between them is a link box that leaves the site.
- Guess The Logo uses the same template (header, puzzle number, input, Submit and Skip, countdown, archive arrows, stats) with a different reveal: a cropped part of the logo. It showed "5 guesses remaining" on first load, so it may allow 5 guesses, or my browser had earlier progress (unverified).
- I could not open the other sister sites because the browser tool did not allow those domains. Audio, Book, Movie, House, Phrase, Grid, Secret Word and Lawndle are not inspected. Guess The Angle was inspected in depth (below).
- All the sister sites run one shared JavaScript bundle (about 13 MB, version 2.5.1). It carries a list of puzzle types (game, cover, angle, logo, grid and others) and picks the behavior by type. So the reference is one client with many game types, not twelve separate apps.

**Sister game: Guess The Angle (inspected 2026-10-26, puzzle #625 and archive puzzle #1)**

*What the player does*
- The page draws two arrows from one point: a white arrow pointing right and a red arrow. An arc between them marks the angle. The player types the angle in degrees. There are 4 guesses.
- The red arrow is animated on every page load: it sweeps up from 0° in steps of about 5.4° and stops at the true angle (14° to 168° took about 19 seconds in my test). So the picture shows the answer when the sweep ends; the game is about reading the angle, not about hidden information.
- Feedback per guess: a row with an arrow (⬆️ too low, ⬇️ too high) and the number. The help says 🟩 correct and 🟥 incorrect.
- A win needs the exact angle. Lost game: "Oh no! Better luck next time", the true angle, and "N% from the exact angle" for the closest guess (136° against 168° showed 19.05%). Win: "Good Job!", the angle and "0.00% from the exact angle".
- The help says the answer is always an even number. That is new: puzzle #1's answer was 175 and the input placeholder was "Enter a number" there, while today's says "Enter an even number".

*Input rules (as observed)*
- The input is a text field that keeps only digits: "-5" became 5 and "12.5" became 125.
- Empty submit does nothing and costs no guess. Any other number is accepted and costs a guess, including 400 (no upper limit).
- Odd numbers are accepted even when the help says the answer is even; they just cost a guess.

*Puzzle data and animation*
- The picture is an SVG drawn in the browser. The red line's end point is computed from the angle, so the exact angle is in the page. A group rotation exists for "hard mode" (below).
- No request is made when a guess is submitted; checking is in the browser, like the game guesser.

*Settings page (`/setting`)*
- Member login by email, a notification toggle ("send email when a new daily game is available", members only).
- Sharing options: show rank, show franchises, include site link, link to the corresponding puzzle.
- Gameplay options: a red Skip button, and **hard mode: the figure rotates while loading**, so the white arrow is no longer the horizontal baseline.
- Stats backup: import, and export to clipboard (members). A UUID identifies the user. A public endpoint returns a user's result for a puzzle by UUID and puzzle number, so users can build their own dashboards.
- Version number.

*Stats and rank*
- Stats dialog: played, won, win %, current streak, max streak, win distribution over 1 to 4 guesses, and a **rank** ("You are an Angle Amateur", "5 more wins to rank up") with a "copy to clipboard" share.
- The site also has "detective" rank names in its code (New Inspector, Seasoned Sleuth, Elite Detective).

*Archive screen (`/previous-games`)*
- A "Back To Current Game" button and a legend: unplayed ❓, skipped (grey), incorrect (red), correct (green).
- One row for every puzzle from #1 to today's #625 on one page, with no paging. Each row: a "Play Day #N" button, one colored box per guess slot (4), and a status ("Unplayed! 🚨", "Failed 😕"). Below the list: "Share All Games" and "Play Random Game".
- Choosing a row opens the puzzle at `/p/{n}` on the same game screen, with previous and next arrows. The end screen of every game also has a "Play Previous Days" button.

*What it shows for us*
- A second game family: **numeric estimation with higher/lower feedback**. The guess is one number, the feedback is a direction, the puzzle is a drawing. It shares almost nothing with the game guesser, which confirms the module approach in 3.3 and decision 8.
- The shared parts it uses: puzzle number and date, countdown, guess counter, stats and rank, archive list, share, settings.
- Because the player can read the answer off the drawing, hiding the answer from the client is not possible for this kind of game; see risk 7.

**Sister game: Guess The Movie.Name (inspected 2026-10-26, puzzle #754 and archive puzzle #700)**

*Rules and flow*
- Same site template and rules as the game guesser: identify the movie from screenshots, 6 guesses, 6 screenshots all from the same movie. A wrong guess or Skip reveals the next screenshot. Feedback per guess is only green (correct) or red (incorrect). There is no franchise-match color in the help text for this game.
- The guess is chosen from a search list. Remakes and same-title movies cannot be told apart: the list shows titles without a year, so for example "The Thing" is one entry.
- End screen: a message that depends on how it went ("Nice, that was close!" after a win on guess 6, "Oh no! Better luck next time" after a loss), the answer, share, a "show guesses" link, a plot summary, retailer links, and buttons for "Embark on a Quest", "Play Previous Days", "Play Guess The Cover", "See Puzzle Stats" and "Guess The Poorly Described Movie".

*Clue ladder (puzzle #754; the screenshot of each step is a full still)*

| Step | Screenshot plus |
|---|---|
| 1 | A dark still with black bars and no text overlay |
| 2 | Metacritic score and IMDb rating |
| 3 | Genre |
| 4 | Original release year |
| 5 | Notable actor |
| 6 | Director |

- The stills are 6 images of 1920×1036 pixels at `/gtm_games/{puzzle number}/{step}.webp` on the same host, all loaded at once when the page opens. Unlike the game guesser, the first step is not a tiny pixelated crop; it is a full image of an unhelpful moment.

*Poorly Described Movie mode (`/gtmpd/{n}`, puzzle #28 at the time)*
- The same ladder with text instead of images: step 1 is a deliberately bad, funny plot description ("A disgruntled department store employee gets unwillingly relocated to the 14th century..."), step 2 is a second description plus the ratings hint. Six guesses, same search, same guess rules.
- So one mechanic, the clue ladder, serves images, video and text. Our spec should not hard-code "image".

*Search list*
- The same endpoint as the game guesser, with the item type set to movie. It returns 200 results with title, franchise and type. Matching is fuzzy and ranks exact and prefix matches first. The list contains shorts, anime and TV specials as well as films (for example "Alien Sniperess").

*Community stats per puzzle (`/stats/{n}`)*
- A donut chart of the share of players that solved it at each step (1 to 6) and the share that failed, plus the top five most common wrong guesses with counts (for puzzle #754: "Alien" 39, then "Fight Club", "Basic Instinct", "Alien: Covenant", "Constantine" at 5 or fewer), a "Play this puzzle" button and a link to other players' scores that goes to a social-media search for the puzzle's hashtag.
- The data comes from an endpoint keyed by puzzle number and game type. It returns the percentage per step, a separate set of percentages for members that includes the incorrect share, the total player count (114 at the time I looked) and the top wrong answers.
- To feed it, the movie game sends one POST per guess to a results endpoint, after getting a CSRF token from the API. This worked on an archive puzzle too. The answer itself is also in the page: the script bundle contains the metadata, including titles and directors, so the check can be done in the browser.

*What it shows for us*
- The movie game is the same family as the game guesser. It needs the clue ladder module with a different step list, plus a movie data source for the hints.
- **Community stats** (the share who solved it at each step, the most common wrong guesses) are a cheap, popular feature and need only the guesses we already receive on the server. Needs a privacy note in the policy (3.7).
- Hints come from external ratings: Metacritic and IMDb scores, genre, year, actor and director. Section 7 lists data sources and their terms.

**Word game family: how Wordle works (inspected 2026-10-26 on the live site, plus the NYT help center and public write-ups)**

*Rules*
- The player has 6 guesses to find a secret 5-letter word. A guess must be a word the game accepts. After each guess every letter tile is colored: green (right letter, right place), yellow (in the word, wrong place), gray (not in the word).
- Repeated letters: only as many copies are colored as the answer contains; extras are gray. Example from the write-ups: answer "reply", guess "curry" colors only the first R yellow and the second R gray.
- One word per day, the same for everyone, released at local midnight on the NYT site. (Our decision 10 is UTC.) The game ends on a solve, on 6 guesses, or when a new puzzle publishes.
- An on-screen and physical keyboard. The on-screen keys take the colors of the best result for each letter (the "E" key turned yellow after my first guess, and C, R, A, N turned dark gray).
- A guess that is not accepted does not use a try: the row stays white. A row with too few letters is not submitted either. I saw the row stay as typed after "zzzzz" and after a 3-letter entry; the message text appears briefly and I did not capture it.
- The NYT's rules on which words are valid: plurals formed by only adding S or ES, and past tenses formed by only adding ED, are not used as answers (GEESE and FRIED are allowed, DATES and HOPED are not). The help does not name the dictionary used to check guesses.

*Hard mode and settings (cog icon)*
- Four options: **Hard Mode** (hints from earlier guesses must be used in later ones), **Dark Theme**, **High Contrast Mode** (replaces green and yellow with orange and blue for color blindness; the shared grid changes too), **Onscreen Keyboard Input Only** (for speech and assistive input).

*Stats, streaks, share*
- Stats: played, win %, current streak, max streak, guess distribution bar chart. Shown on a stats page and on the end screen.
- Streaks need a solve before the day ends; finishing after midnight breaks the streak.
- Share: after the game a button copies an emoji grid of the tile colors. The grid shows no letters, so it has no spoilers. It is the format that made the game spread.

*Accounts and archive (NYT)*
- Progress and stats link to an NYT account; without one, archive progress is not saved.
- The archive goes back to the first puzzle and needs a paid subscription. Archive play changes played, win % and distribution but **not streaks** (the same rule as our decision 14). A solved puzzle cannot be replayed. Progress icons show not started, in progress (one line per guess), solved, and finished with a wrong word.
- Other paid extras: a Wordle Bot that analyses finished games, a daily column about the puzzle, and a "Create your Wordle" feature where a subscriber makes a puzzle with a 4 to 7 letter word, a short display name and an optional hint, and shares it by link (no account needed to solve).

*Data and where the answer lives*
- Each day's puzzle is a small JSON file for that date with fields: id, solution, print date, days since launch, and editor. The solution is plain text, and guesses are checked in the browser (no request when you submit). Anyone can read the answer; the NYT accepts this.
- The word lists, per public write-ups: about 2,300 possible answers (2,309 or 2,315 depending on the source) and about 13,000 accepted guesses. The original author's partner filtered roughly 13,000 words down to about 2,000 familiar ones for the answer list. Since the NYT bought the game (January 2022) an editor picks the day's word, sometimes linking it to a date, and the answer is no longer limited to the original list.
- The NYT removed offensive and some obscure words from both lists in 2022, which broke the shared daily word between the NYT version and older copies. Players complained about it and about answers they found harder. Some also reported lost streaks after the move to NYT accounts.

*What it shows for us*
- A third game family: **letter-by-letter feedback on a typed word**. The guess is a string, the feedback is one color per letter, the puzzle is a word. It needs a dictionary for guess validation and a curated answer list, which are data problems, not code problems.
- It reuses the shared parts: puzzle by day, countdown, stats, streaks, archive, share, settings, dark and high-contrast themes.
- Server-side checking is a clear improvement. The reference ships the answer to every browser; we send feedback per guess.
- The feedback must be computed with the two-pass rule for repeated letters: first mark exact matches, then mark yellows only while copies of that letter remain unmatched in the answer. A naive letter-by-letter check gets duplicates wrong (a known bug in hobby clones).
- The soft spots to design deliberately: the answer list (who curates it, how offensive or obscure words are filtered), the guess dictionary (source and license), and the day boundary (UTC for us, local midnight for the NYT).

**Playable game family: Game Boy challenge (researched 2026-10-26 from the emulators' repositories, docs and source code, and public catalogs)**

*Verdict*
- A Game Boy game runs in the browser as WebAssembly (compiled code that runs at near-native speed). The backend does not run the game while someone plays. It serves the challenge, checks runs and keeps results. No change of stack is needed (section 6).
- The hard parts are three other things, not the player: the right to host a ROM, trusting a score that the browser reports, and finding enough games and result rules for one challenge a day. Risks 11 to 14 cover them.

*Emulator choice (checked 2026-10-26)*

| Emulator | License | First load | Notes |
|---|---|---|---|
| binjgb | MIT | about 100 KB (88 KB wasm, 14 KB JS) | Game Boy and Game Boy Color, no threads. Repository pushed 2026-09-25, prebuilt wasm refreshed 2026-05-13. No npm package. Its README calls Game Boy Color support "hacky-but-passable". |
| Nostalgist.js | MIT; cores: Gambatte GPL-2.0, mGBA MPL-2.0; RetroArch GPL-3.0 | about 1.1 MB per core | Typed JS API (version 0.23.0, pre-1.0). Cores load from jsDelivr by default and can be self-hosted. |
| EmulatorJS | GPL-3.0 | about 1.4 MB | Ready-made player with touch controls and cheats, configured through global `EJS_*` variables. Online play needs a separate Node server. |
| mGBA-wasm | MPL-2.0 | npm package 2.6 MB unpacked | Rich typed API, also plays Game Boy Advance. Needs `Cross-Origin-Opener-Policy` and `Cross-Origin-Embedder-Policy` headers on the whole page. |

Skipped: WasmBoy (GPL-3.0, last push 2023, its README says "not very accurate"), GameBoy-Online (no license, 2019), SameBoy (the most accurate, but I found no web build), Boytacean (Apache-2.0, its README calls it educational).

Accuracy, from gbdev's emulator shootout (updated 2026-06-04): SameBoy 253 of 264 tests, Gambatte-Speedrun 169 of 207, mGBA 150 of 264, binjgb 144 of 207. The page does not say why the totals differ, so only Gambatte-Speedrun against binjgb (169 against 144 of 207) compares directly. The tests stress obscure timing; my reading is that they predict trouble in tricky games, not in ordinary ones. I read these numbers through a page-summary tool, so check the page before relying on them.

My pick: **binjgb**. The deciding reason is on the server (next sections): its C source builds both for the browser and as a native program, so the player and the verifier run the same code. It is also MIT, small, and needs no cross-origin headers. The price: there is no typed API, and the prebuilt `binjgb.js` is a classic script, not an ES module. The official demo code that drives it is 858 lines of plain JavaScript (frame loop, WebGL with a Canvas2D fallback, audio scheduling, keyboard and touch) to port to TypeScript; it is MIT, with a few parts from GB Studio (also MIT; keep that notice). Pin a commit, because the last GitHub release is from 2021.

*Reading the result from the game (from binjgb's exported functions)*
- The browser build exports memory read and write, pointers to work RAM and high RAM, button setters, state and battery-RAM load and save, rewind, and 84 built-in palettes. It exports nothing for the link cable and nothing for cheat codes.
- So "score", "level complete" and "game over" can be read from game memory, once we know the addresses. Each game and each objective needs them found once. 73 of the 77 open-licensed catalog entries link a source repository, which is where addresses can come from; otherwise a debugger can find them. This hand work is the main content cost (risk 14).
- A challenge can also write memory after loading the start state, for example a level number or a random seed, so one game could give many different days. Untested; it depends on the game.

*Determinism and replays (read in binjgb's source; not run, see "Not verified")*
- The browser entry point fixes the random seed that fills power-on RAM (0xcabba6e5). The native tester uses the same default and has a `--seed` option. So both start from the same memory.
- The browser build already records each change of button state with the tick at which the game read it (this is how its rewind works). The C library has a button buffer with playback and read and write to a file.
- The native tester takes `--joypad FILE`, `--frames N` and `--output FILE`. The project's own regression suite runs the tester for a set number of frames, hashes the output image with SHA-1 and compares it with the expected hash. So reaching an identical, hashed result after a fixed number of frames is how the emulator tests itself, and the tester accepts a recorded input file.
- Gaps. The tester does not print memory, so a small runner (or a change to the tester) must read the result rule's addresses. The wasm build does not export the file functions, so the browser keeps its own list of (tick, buttons). Nobody I found has tested a browser run against a native run; the spike in section 10 must show that the same replay ends with the same memory.
- Sizes. A start state is at least 176 KB: the state holds 16 KB video RAM, 32 KB work RAM and a 128 KB external RAM buffer whatever the cartridge. The unused external RAM is filled from the seed, so I expect it not to compress. At that size a year of daily start states is about 60 MB. A replay entry is 16 bytes in memory; at 5 button changes a second, a 2-minute run is about 10 KB (my estimate). None of this was measured.

*Rights and ROMs (general information, not legal advice)*
- Emulators: in Sony v. Connectix (9th Cir., 2000) copying a console's BIOS to build an emulator was held to be fair use.
- ROM hosting: Nintendo won $2.1 million against the ROM site RomUniverse (June 2021) and an order to destroy the files. Nintendo's FAQ says: "The uploading and downloading of pirate copies of Nintendo games is illegal."
- The US archival exception (17 U.S.C. section 117(a)(2)) lets the owner of a copy make a copy "for archival purposes only", to be destroyed if possession stops being rightful. It says nothing on hosting or sharing.
- So the rights notice and takedown email that cover screenshots (3.7) do not cover a ROM. Decision 40 makes us the host, so every ROM needs a documented right.
- **Homebrew Hub** is the community catalog of Game Boy homebrew (API at hh3.gbdev.io; 1,642 entries on 2026-10-26: 918 Game Boy, 451 Game Boy Color, 249 Game Boy Advance, 24 NES). Its database says each game is under its own terms. I pulled 1,151 unique Game Boy and Game Boy Color entries (of the 1,369 the API counts): 1,065 declare no license and 86 declare one. Of those 86: 77 are clearly open (43 MIT, 18 GPL-family, 7 Zlib, 5 CC-BY-SA 4.0, 4 others), 7 are non-commercial, 2 are non-standard. An entry without a license needs the author's permission; the catalog's "playable" flag is not a license.
- Of the 77 open ones, 59 are games and 73 link a source repository. To evaluate (title, license and tags come from the catalog; I have not played or inspected any): Tobu Tobu Girl (MIT, Action), Rex Runner GB (MIT, Platform), El Jamon Volador (GPL-3.0-only, tagged Flappy Bird), Max Pirate (MIT, Action), Snake (WTFPL-2.0), Libbet and the Magic Floor (Zlib, Puzzle), 5 mazes (CC-BY-SA 4.0, Puzzle), 2048gb (Zlib, Puzzle). Each license has its own conditions, for example a source offer for GPL, a notice for MIT, credit for CC-BY-SA; read each text.
- Not researched: writing our own games (GB Studio, GBDK) and asking authors for permission.
- Open-source references to read, not copy: Homebrew Hub's own front-end embeds binjgb and mGBA wasm builds (GPL-3.0); gbajs3 (React and mGBA wasm, BSD-style license) has save sync.

*Platform findings (from docs and the installed code)*
- No threads in binjgb, so no cross-origin isolation. mGBA-wasm requires `Cross-Origin-Opener-Policy: same-origin`, `Cross-Origin-Embedder-Policy: require-corp` and a same-origin script. Under that policy cross-origin images without CORP or CORS headers are blocked (MDN), which would hit images served from an object-storage origin.
- If we add a Content-Security-Policy, WebAssembly needs `'wasm-unsafe-eval'` in `script-src` (MDN).
- Starlette 1.6.0 (installed) supports HTTP Range in `FileResponse`. `.gb` and `.gbc` are unknown to Python's `mimetypes`, so they go out as `application/octet-stream`; `.wasm` is `application/wasm`. In production the ROMs, start states and wasm are best served from object storage or the static host.
- A run upload is bytes or JSON. FastAPI can read a raw body with `await request.body()` and describe it with `openapi_extra` (FastAPI docs, Path Operation Advanced Configuration). `python-multipart` is not installed and not needed.
- Vite 8 supports `?url` imports for the wasm file (docs v8.3.4; installed 8.2.2). Create and destroy the emulator inside an effect so it survives React's double run in development (the frontend has a hooks skill for this).

*Not needed now:* bring-your-own ROM, a ROM library in the browser, and cloud sync of battery saves and save states. They follow from "players do not bring ROMs" (decision 40) and from a daily challenge having no long-term save. They return if a free-play mode is ever added. Link-cable multiplayer is out of scope (binjgb has no link-cable API; EmulatorJS would need its own Node server). The Safari rule that deletes browser storage still matters, for guest progress (risk 18).

*Not verified*
- Browser against native replay equality, the real size of a state and a replay, and verification time. My headless run of the downloaded wasm was blocked by the permission system, and I did not work around it.
- The accuracy numbers (read through a summary tool; totals differ). The catalog sample is 1,151 of about 1,369 entries.
- Whether any candidate game is fun or suitable, and where its addresses are.
- Whether EmulatorJS's GPL reaches a React app, and whether COEP `credentialless` works in Safari.

**Find-it game family: hidden-object games (researched 2026-10-26 by a research agent from primary sources, store pages, library repositories and docs; I viewed the owner's example image myself; nothing was tested on a device)**

*Reference games*
- **Hidden Folks (2017).** Hand-drawn black-and-white miniature scenes. A strip shows the targets, tapping one gives a hint, and finding enough opens the next area. About 300 targets in up to 32 areas (the studio's own pages disagree on the number of areas), about 10 targets per area. The studio's press page says "no time limits, no points". Difficulty comes from hiding folks inside or behind interactive scenery, not only from size. The developers found it hard to show what is tappable; they settled on a small wiggle and warned that making one thing interactive makes players expect everything to be. Two main people worked about two years. Reception: Steam 96% positive of 3,210 English reviews, App Store 4.9 from 13K ratings. The complaints found are thin and mild (repetitive sound effects, a lot of scrolling in big levels).
- **Hidden Through Time (2020).** A list of objectives with short, cryptic text hints; finding enough opens the next level; 26 levels, no time limits, a level editor, zoom. Players like the relaxed feel, the kid-friendliness and the editor. They dislike vague hints, tiny or partly hidden items, and performance. A Switch reviewer found the cursor's hit area too small for tiny items.
- **Where's Waldo / Wally.** Books from 1987 with double-page spreads of hundreds of people. The hero is known by a striped shirt, a bobble hat and glasses; decoys wear red and white stripes. A 2009 digital version has a time limit and a dog that signals when you are close.
- **Older hidden-object games** use item lists, magnifier boosters and timed modes. Wrong-click penalties of about 20 seconds are reported in older games and annoy players in dark, cluttered scenes (from a search summary, unverified).
- **Daily precedent: The Daily Spy** (April 2025): one image a day with 6 hidden shapes; 3, 2 or 1 stars for under 1, 2 or 3 minutes; a hint zooms in but adds 30 seconds; no leaderboard on its page; mostly AI-generated images. A 2018 iOS app, "365: My Daily Hidden", is timed with Game Center boards. The agent found no daily single-target crowd search with a leaderboard; "none exists" is unverified because the search was limited.
- **The owner's example image.** A 1280x720 collage of well-known characters (Batman, the Ninja Turtles, Looney Tunes, the Naruto cast, Toy Story, Tom and Jerry, South Park and others), cut out and packed edge to edge on a dark background. It shows the mood but is not a workable pattern: there is no scene, the figures are large and overlap, and every character belongs to someone else (risk 19).

What this means for the design: the references are untimed, so a timer and one target put us closer to The Daily Spy and the timed Waldo apps. A strip of targets plus an on-demand hint is the genre's norm; we replace the hint with a button that reopens the target card. The classic difficulty levers are a smaller target, a bigger crowd, look-alike decoys and partial hiding. Complaints to design against: tiny hit areas, vague clues, penalties in unreadable scenes, stereotyped characters (one App Store review of Hidden Through Time objected to them). Hand-drawn content is slow.

*Showing a big picture on the web.* Versions and licenses were re-checked on npm on 2026-10-26; sizes, issues and behavior are the agent's readings of bundlephobia, GitHub and docs.

| Option | Notes |
|---|---|
| react-zoom-pan-pinch 4.2.0 (MIT) | Plain DOM with CSS transforms; wheel, pinch, drag. It does not set `touch-action`, does not map clicks to image coordinates, and a click still fires after a pan (open issue). Keyboard is new in 4.2 and off by default. 15.5 KB gzipped. Versions 4.0.4 to 4.2.0 came out between 2026-08-03 and 2026-09-03, so pin the version. |
| @panzoom/panzoom 4.6.2 (MIT) | Pointer events and a `touchAction` option; 3.7 KB gzipped. Open issues about slow zoom on mobile and about large images. |
| @use-gesture/react 10.3.1 (MIT) | Gestures only; you write the transform. 8.9 KB gzipped, no release since 2024-03, open iOS issues. |
| OpenSeadragon 6.1.1 (BSD-3) | Deep zoom with image tiles (DZI, IIIF), built-in keyboard, a canvas click event that tells a quick click from a drag. 87 KB gzipped, 463 open issues including touch bugs. For scenes beyond about 6000 pixels. |
| Leaflet 1.9.4 with a flat image map (BSD-2) | Works, but y points up in map units; last stable release 2023-05. `react-leaflet` 5 is under the Hippocratic 2.1 "ethical source" license, which I would avoid. |
| Canvas (Konva, PixiJS) | You write the pinch. iOS limits a canvas to about 4096x4096 pixels, and a canvas is opaque to assistive technology. Only if the scene is animated. |
| Native scroll and the browser's own pinch | Simple, but a pinch-zoomed page displaces a fixed timer and target card, and zoom limits are hard to control (unverified). |

Recommended for us **[proposed]**: our own `SceneViewer` component around react-zoom-pan-pinch at a pinned version, so the library can be swapped; the server's click check does not depend on the viewer. What would change this: scenes above about 6000 pixels or memory failures on 2 to 3 GB iPhones (OpenSeadragon with tiles), repeated iOS gesture bugs (another library), animated sprites (PixiJS).

Pitfalls to design for (from MDN, WCAG, library source and issue trackers):
- Set `touch-action: none` on the viewer only, not the page. Changes made after a gesture starts do not apply. Add + and - buttons, because MDN warns that it harms low-vision users. `user-scalable=no` is ignored on iOS 10 and later.
- Turn off double-tap zoom, because the first tap would submit a click.
- Use Pointer Events and write our own tap detector: one pointer, moved less than about 8 CSS pixels, held less than about 500 ms. Ignore `click` events. Treat `pointercancel` as an abort, not a tap.
- Wheel listeners must be non-passive. Chrome and Firefox send trackpad pinch as wheel events with `ctrlKey`; Safari sends its own gesture events.
- Coordinates are CSS pixels, so screen density cancels out; it only matters for the source image (about one source pixel per device pixel at maximum zoom). Compute the click position from the picture's `getBoundingClientRect()`, not `offsetX`.
- Decoding is the memory risk: 4096x2730 is about 45 MB of RGBA when decoded. Decode one image at a time (WebKit bug 302801: decoding many large images at once got Safari killed on iOS 26). Set `-webkit-touch-callout: none`, `user-select: none` and `pointer-events: none` on the image.

*Image size and format.* Proposal: cap the long side at 4096 pixels and serve two sizes (a 1024-pixel first picture, then the full one after `decode()`). The agent re-encoded the owner's 1280x720 example in memory: JPEG q85 325 KB, WebP q80 224 KB, WebP q70 183 KB, PNG 1.72 MB, lossless WebP 1.34 MB. That is one dense sample, so measure real scenes; the guess of 2 to 3 MB for an 11-megapixel lossy WebP is an extrapolation. AVIF was not measured. Support (caniuse): WebP 97.1%, AVIF 96.3%. For tiles, libvips `dzsave` writes DeepZoom and IIIF layouts (libvips LGPL-2.1, pyvips MIT). Fingerprinted files: `Cache-Control: public, max-age=31536000, immutable`; give the scene `fetchpriority="high"`.

*Checking a click.* Store the target as a polygon with numbers from 0 to 1 (4 decimals is about 0.4 pixel at 4096 pixels), decide on the server, and never send positions to the browser. Pad the shape: NN/g recommends touch targets of at least 1 cm (a fingertip is 1.6 to 2 cm), WCAG 2.5.8 sets 24 CSS pixels as the minimum. The pad is set in screen pixels and converted with the zoom, with the server capping it so a client cannot claim a tiny zoom to get a huge pad. When several shapes are near the click, the nearest one wins. Keep decoy shapes on the server too.

*Clock and cheating.* The server clock is described in 3.11. What cannot be prevented: the picture and the target card are both on the player's screen, so a program can search for the target. OpenCV `matchTemplate` finds a pixel-identical card trivially (it is not scale or rotation invariant). A 2018 robot that used OpenCV and Google AutoML Vision is reported to have found Waldo in 4.45 seconds (secondary source). How well current multimodal models do on crowded high-resolution scenes is unmeasured. Extensions, devtools and shared screenshots also work, and "it's top left" spoilers cannot be stopped. The NYT Mini has no global leaderboard because cheating cannot be policed. Realistic defenses: draw the card differently from the scene (another scale or pose, redrawn rather than cropped); per-scene color jitter; look-alike decoys; a solver-in-the-loop check at generation time (run template matching and a few models on the generated scene, and regenerate if a naive solver finds the target); click pauses and caps; start limits per IP and account in Redis; plausibility flags (a time under about 2 seconds, or under the 1st percentile once 50 or more results exist, a correct click with no pan or zoom when the target was off screen, lattice-like click patterns), with flagged results kept off the board. Gating the picture behind Start (short-lived addresses) stops casual pre-study from the page source but not a determined player.

*Making the scenes.*
- **Script** (preferred, decision 19): sample positions with blue-noise (Poisson-disk, Bridson 2007; SciPy has `qmc.PoissonDisk`), draw sprites back to front for natural overlap, place the target in a chosen zone and add decoys that share two of its attributes, reject scenes where the target is less than about 60% visible, too close to the edge or too salient, and flatten. The script knows the target's position, so there is no manual annotation. Details are in section 7.
- **Hand-drawn or commissioned art** with an annotation tool (Label Studio Apache-2.0, CVAT MIT, VIA BSD-2, or a one-page canvas tool that records a click). Slow: Hidden Folks took about two years for about 15 areas at launch.
- **Public-domain paintings** (checked on Wikimedia Commons by the agent, tagged public domain): Bruegel's Children's Games 6567x4770 (16.3 MB), Dutch Proverbs 5649x4000, Tower of Babel 30000x21952 (213 MB), Bosch's Garden of Earthly Delights 30000x17078 (234 MB). Crops and details uploaded by third parties may carry CC BY-SA, so take the full original. They need tiles and a manual box, so they suit "special days", not the daily flow.
- **AI-generated images:** the owner prefers scripts, so only a fallback. The same character must look the same on the card and in the scene, which is hard. In the US a purely AI output is not copyrightable (the D.C. Circuit in March 2025; the Supreme Court declined review in March 2026; from search summaries, unverified).
- **Sprite sources and their licenses** (as read by the agent; check each text before use): Kenney (CC0; Toon Characters 1 has only 6 characters in 45 poses, so recolor or combine packs); Open Peeps (CC0; modular hand-drawn people, claimed 584,688 combinations; busts and some full figures); DiceBear (library MIT; 61 styles, of which 42 are CC0, 14 CC BY 4.0, 4 on the artists' own terms and 1 MIT; its JavaScript library renders seeded, repeatable SVGs offline); Openclipart (site says public domain; quality varies); OpenGameArt (CC0 needs no credit, CC BY needs credit, CC BY-SA would force our composited scenes to be shared under the same license, so keep it out).
- **How many puzzles:** a script makes 365 or more a year, limited by variety, not labor. Hand-drawn art gives tens of scenes a year for a small team. Public-domain paintings give hundreds of puzzles from about ten works.

*Rights (general information, not legal advice).* Using well-known characters is the highest-risk option: the US Copyright Office says non-commercial use is not automatically fair use and weighs purpose, nature, amount and effect on the market. Whole copyrighted characters, as in the owner's example, fit poorly, and a "no infringement intended" line has no standing in that analysis. The footer notice in 3.7 is a practice, not protection. Waldo's rights passed through several owners (Entertainment Rights 2007, DreamWorks Animation 2012, NBCUniversal 2016); the current trademark holder is unverified. Do not use "Waldo", "Wally", "Hidden Folks" or "Hidden Through Time" in names, and avoid the striped shirt, bobble hat and glasses combination. The idea of finding one target in a crowd is free; a close copy of specific art is not safe. CC BY needs the creator, a notice, the license link and a note of changes. The US analysis does not carry over to the EU or Russia, so get a lawyer's review before launch.

*Accessibility (WCAG 2.2).* A single-pointer alternative to pinch (2.5.1) and a non-drag way to pan (2.5.7) mean zoom buttons and arrow buttons. Targets of at least 24 CSS pixels (2.5.8). Keyboard: arrows pan, + and - zoom, 0 resets, plus a crosshair mode in which Enter or Space selects at the center (we build the crosshair; the library has no keyboard by default). The scene gets a general `role="img"` label that does not describe the target; the target card gets an alt text. A meaningful non-visual alternative is not realistic: a text map would trivialize the puzzle, so say plainly that it is a visual game. Do not make the target differ from its nearest decoys by hue alone (the generator should simulate color-vision deficiency). Respect `prefers-reduced-motion` (no inertia, no animated zoom to the answer). A count-up stopwatch is not a time limit under WCAG 2.2.1, but offer a hide-timer option anyway. Offer high contrast and resizable UI. Precedent: Hidden Folks has three color modes and mouse, keyboard, controller and touch support.

*Not verified*
- No device testing; every statement about gestures comes from docs, source code and issue trackers. Steam's review interface was not usable, so Hidden Folks' negative reviews were not sampled, and I know of no GDC talk. A retry that would have needed a browser disguise was blocked by the permission system, and the agent did not work around it.
- Compression numbers come from one sample; AVIF was not measured. How well current multimodal models solve these scenes is unmeasured. The Waldo trademark holder, the Waldo-solving robot's results, the AI-copyright outcome and the research papers on search difficulty (Duncan and Humphreys 1989, Rosenholtz 2007, Ionescu 2016) come from search summaries. The sprite licenses were read by the agent from each site's license page and should be re-read before use.

**Geometry exercises: what exists (researched 2026-10-27 by web search and page reads; I found no user reviews, so what players like is not known; the search was limited, so "none exists" is unverified)**

*Games and exercises*
- **Daily angle-estimation games** (AnglesGame, The Angle, Angledle, Angler): guess the size of a shown angle in 4 to 6 tries, with higher/lower arrows and a temperature reading (AnglesGame: whole degrees from 1 to 359; The Angle: 5 to 354). They test the eye, not reasoning, and are the same family as the angle game in this section.
- **Angle-chasing quizzes for classrooms:** Dr. Mike's Angle Quiz shows a diagram per question and asks for the missing angle x (triangles, quadrilaterals, parallel lines, crossing lines, straight lines, angles around a point); it has hints, a timer and a goal of 5 answers a minute, and its page says it needs Java (probably dead in modern browsers; unverified). Transum's Angle Chase is a web exercise with levels. Teachers also sell printable sets. None is daily and none gives clues step by step.
- **Daily math games:** Nerdle (January 2022), Mathler and Primel use Wordle-style color feedback and several difficulty levels. Reviews say Mathler is a bit harder than Wordle, and that several valid answers for one day frustrate players. That is a warning for us: one answer per puzzle (risk 23).
- **Euclidea:** geometric constructions with straightedge and compass; stars for efficient solutions; steep difficulty (about 120 to 156 levels, depending on the source). The main complaint is difficulty, and getting every star needs a purchase. Few ratings, so weak evidence.
- **Langley's adventitious angles (1922):** a triangle with angles 80, 80 and 20 degrees, where one marked angle must be shown to be 30 degrees. It is called the hardest easy geometry problem: angle chasing alone is not enough, and the elementary solutions need an extra construction (Mercer, 1923). Trigonometry gives the number but not the elegant proof. This is the natural model for an "extra element" clue.

*What the research on generating such puzzles says (the most useful part)*
- **Philip Todd (Saltire Software), ADG 2023 slides:** angle problems are linear equations on angle variables (the slides show the matrices), and a generator makes them automatically. I read the slide text. The pipeline: choose an angle pattern, choose a vertex permutation, choose vertices to merge, find a good instance, create a step-by-step solution, estimate the difficulty. A good instance has no angle too close to 0 or 180 degrees and no lines that look concurrent unless they are. The solver works breadth first: find all angles determined by the known ones, and when a new angle is already known, set the two values equal to get a linear equation. Difficulty is a value per step, summed over the steps. The set generator ensures no two problems are isomorphic and sorts them by difficulty.
- **AlphaGeometry (DeepMind, Apache-2.0):** its symbolic engine pairs a deduction database (DD) with algebraic reasoning (AR). I read `ar.py`: directions of lines are variables, a constant angle is a fraction of 180 degrees, equations use exact fractions, new equations are substituted and eliminated incrementally, and the premises used for a result are found by a linear program. The source does not call this Gaussian elimination. Its synthetic training problems were made by building random figures and deducing everything that follows.
- **Newclid** (successor solver): PyPI 3.0.1, needs Python 3.11 or later, license Apache-2.0 per PyPI metadata, repository last pushed 2026-02-24, can write proof steps. I did not install or test it.
- **Tutoring systems** use hint sequences: a pointing hint (highlight what matters), a teaching hint (the fact needed), a bottom-out hint (the step itself), usually 3 to 5 hints (secondary sources, not the original papers). Our clue types follow this pattern: pointing, intermediate result and last step in the first version, with teaching clues later.

*More kinds of target: lengths and radii (decision 47)*
- **Engines.** Newclid's abstract says its solver understands metric concepts, length and angle, better than its parent and can use theorems such as the Pythagorean theorem in proofs; it does not say whether numeric lengths are supported. AlphaGeometry's `ar.py` has a table for lengths that handles equal lengths, constant ratios and equal ratios as relations between logarithms of lengths, so proportion chasing is linear there; sums of lengths and the Pythagorean theorem are not (my reading; I did not run it). Angle chasing is the easy case; lengths need more.
- **Sangaku** (Japanese temple geometry): wooden tablets with figures and problems offered at shrines and temples; about 880 remain, and many ask for the radius of tangent circles. They usually give the answer but rarely the solution. A source of ideas for radius puzzles on special days; some need advanced methods (one analysis uses inversion), so only some suit a daily game.
- **Descartes' circle theorem:** for four mutually tangent circles with curvatures a, b, c and d (curvature = 1 / radius), 2(a² + b² + c² + d²) = (a + b + c + d)². If the first four curvatures are whole numbers, every circle in the packing (an Apollonian gasket) has a whole-number curvature. A good special: three circles given, find the fourth. The radius is 1 / curvature, so the answer is a fraction, which the first version leaves out.

*What it shows for us*
- No daily angle-chasing puzzle with a clue ladder turned up, so this game is new in that form. The pieces exist: a generator blueprint (Todd), an engine design (AlphaGeometry's AR), a hint structure (tutoring) and a famous "extra element" problem (Langley).
- It reuses the clue ladder of the first family, with a number as the guess and generated content.
- It needs no outside art or data, so the rights risks of the other games do not apply.
- Math libraries (versions and licenses checked on npm 2026-10-27): KaTeX 0.19.1 (MIT) and MathJax 4.1.3 (Apache-2.0) typeset formulas; JSXGraph 1.14.2 (MIT or LGPL) and Mafs 0.21.0 (MIT) draw interactive geometry. A figure of lines, arcs and labels is simple enough to draw as our own SVG in React, with KaTeX only if the formula clues need typesetting **[proposed]**.

**What this means for us**
- The reference is one template repeated across sites, with separate progress and stats on each. One app with a nav bar and shared accounts is our improvement, not a copy.
- Wordle-like games (Lawndle on their list) are a different family and are not covered here. Guess The Angle (numeric estimation) is a second family, covered above.
- The playable challenge is a fourth family: real-time play, scored by a result read from the game's memory. It is the only family that needs an emulator and a replay check on the server, and the only one that hosts a whole copyrighted work (a ROM), so it carries the largest rights risk (risk 11).
- The hidden-character game is a fifth family: a click on a big picture, scored by time. It needs a viewer for large images on phones and a server-measured clock, and like the playable challenge it cannot hide its answer from a determined player (risks 7 and 20).
- The geometry game reuses the clue ladder of the first family. Its guess is a number, its content is generated by a script, and its answer can be checked exactly on the server.

## 5. What other sites do (research)

Evidence quality is mixed. I found no organised collection of user reviews, so likes and complaints below come from forum threads and news coverage.

| Site | Features worth noting |
|---|---|
| Gamedle | Several modes per site; colored attribute clues with arrows; one-time clue costing a life; optional sign-in with guest progress on the device; stats; achievements; account merge and delete; stats export; multiplayer rooms without an account. |
| Framed | Movie from stills, a new frame per wrong guess. Criticized for no feedback on near-misses, obscure picks, hard-to-read first frames. |
| Heardle | Song from a short audio clip. Shut down by Spotify in 2023. |
| Globle, Worldle | Geography with distance and direction feedback. |
| NYT Games | Hub with per-game streaks and stats, friends leaderboard, badges. |
| Puzzmo | Hub with optional accounts for streaks, leaderboards and friend groups. |
| Wordle archive sites | Existed because the official game allows only one puzzle a day. |

Recurring patterns:
- **Feedback on near-misses** keeps wrong guesses fair (the reference's yellow franchise match, Gamedle's colors). Lack of it draws complaints (Framed).
- **Readable first clue.** Both guessthe.game (at launch) and Framed drew complaints about unreadable first images.
- **Fair content.** Players dislike obscure answers and near-duplicate entries from one series.
- **Streaks** bring players back but make a missed day hurt. Common mitigations: grace period, freeze, partial reset. This is practitioner opinion, not controlled study.
- **Ads** were the most common complaint in reviews of general word-game apps. Not applicable now (no ads).
- **Optional login with guest play** is the norm.

## 6. Technical feasibility on the current stack

Verdict: **feasible with the stack as it is.** Nothing needs replacing.

| Need | Fit | Notes |
|---|---|---|
| Server-side answer check | Fits FastAPI | The answer reaches the client only after the game ends. Wordle checks client-side, so its answer ships in the page. Server checks also make progressive reveal safe. |
| Puzzle storage | Fits Postgres | A `puzzle` table keyed by game and date, filled ahead of time by a script. The day's puzzle is a query by date. |
| Game modules | Fits | Backend: a registry of game handlers behind shared routes such as `GET /games`, `GET /games/{slug}/puzzles/{date}`, `POST /games/{slug}/puzzles/{date}/guesses`. Frontend: a registry mapping slug to a lazily loaded component. |
| Same-screen play | Fits TanStack Router | Routes like `/`, `/games/$slug`, `/games/$slug/$date` inside one layout. Game switching changes the route, not the page. |
| Optional auth | Fits | Game routes accept an anonymous user; the existing `CurrentUser` dependency gets an optional variant. |
| Guest progress | Decided | **[decided]** Guests are stateless on the server: the client keeps its progress in browser storage and sends the earlier guesses with each request, and the server recomputes the state. Accounts are authoritative: the server stores progress and rejects forged state. A guest can fake history to see a later clue early, which only matters for guests, who have no leaderboard. |
| Guest merge on login | Needs design | One idempotent endpoint that takes local results. |
| Per-game feedback types | Needs care | Feedback payloads differ per game. In OpenAPI, model them as a union per game so Orval generates the types. This replaces `field_schema` as the highest drift risk between frontend and backend. |
| Leaderboard | Fits Redis sorted sets or Postgres | Scoring is decided per game. |
| Images | Partially in place | CONTRACTS describes a presigned S3/MinIO flow, but the S3 client and `arq` are not installed. For script-ingested puzzles a one-off upload from the script is simpler than the browser flow. |
| Autocomplete | Fits | The reference uses a server search that returns 200 fuzzy matches, each with title and franchise. We can do the same with Postgres trigram search over a clean title table, with a franchise field for the franchise hint. The title list holds no answers, so it is safe either way. |
| Clue delivery | Fits | The server returns the clues the player has earned. Images are served per step from object storage, not all at once. |
| Responsive web | Fits | Tailwind and shadcn/ui are already in place. |
| React Native later | Possible | The backend API is client-agnostic. Auth transport for a native client needs a check at that time (see 3.6). |
| Legal pages | Fits | Static routes in the frontend. The source-credit data comes from the puzzle script. |
| Clue-ladder games (game guesser, movie, text variants) | Fits | One module config per game: a list of steps, each with media (image, video or text) and optional hint fields. The server returns only the steps the player has earned and the feedback for each guess. A per-puzzle table of guesses feeds the community stats. |
| Community stats per puzzle | Fits | Aggregates over stored guesses (counts per step, top wrong answers). A job or a cached query per puzzle; Redis can hold the counters. |
| Word game | Fits | A `word` table with a flag for "can be an answer" and "can be a guess", filled by a script from a licensed word list (see risk 9). The server checks a guess against the guess list and returns one color per letter using the two-pass rule. The client may hold the guess list for instant "not in list" feedback; it holds no answers. |
| Two interface languages | Fits | A frontend i18n library with one translation file per language. The backend returns error codes, not texts. The language is saved per guest (browser) and per account. |
| Word game variants | Fits | `puzzle` is keyed by game, variant (language, length) and date. Progress and stats use the same key. One endpoint lists a game's variants so the frontend can build the selector. |
| Estimation games (the angle game) | Fits | A puzzle row holds one integer. The module draws an SVG or canvas figure in React. The server checks the number and returns direction and percent difference. |
| Archive with per-guess boxes | Fits | The list needs, per puzzle, the player's guess results. One endpoint can return them for a whole page of puzzles. |
| Day boundary | Simple | UTC everywhere. The client shows the countdown to the next 00:00 UTC. Check the date on load and on submit and refresh with a message if the day changed. |
| Playable challenge: emulator in the browser | Fits | A WebAssembly emulator runs on the client and the backend does nothing while someone plays. Core: binjgb (section 4). The frontend loads it only on this game's route. |
| Playable challenge: verification of runs | Needs design | The backend replays the recorded buttons from the start state on the same emulator code and reads the result from memory. This needs a native runner built from the emulator's C source, called from a background worker with a time limit. `arq` is named in the backend notes but is not installed. Browser against native equality must be shown first (section 10). |
| Playable challenge: ROMs and start states | Fits | Small files in object storage or on the static host; Starlette already supports Range requests. A ROM is at most 8 MB by the emulator's limit, a start state is at least 176 KB. Each ROM has a license record (3.10). The S3 client is not installed yet; static files work until it is. |
| Playable challenge: runs and leaderboard | Fits | A run row (player, challenge, replay, claimed and verified result, status). The board holds the best verified result per player per challenge, in Postgres or a Redis sorted set. |
| Hidden-character game: scene viewer | Fits (needs real-device testing) | A DOM viewer with a pinned library inside our own `SceneViewer`, our own tap detection, `touch-action: none` on the viewer, double-tap zoom off, zoom buttons and keyboard (section 4). Scenes are at most 4096 pixels as lossy WebP with a small first picture. Deep-zoom tiles with OpenSeadragon are the escape hatch for larger scenes. |
| Hidden-character game: attempts and clock | Needs design | The server creates an attempt, receives "picture painted" and the clicks, and measures the time. Routes under the shared game routes: start an attempt, ready, click, give up, results. Tables: scene, puzzle, attempt, click (every click is stored for plausibility checks and difficulty tuning). Guests use a signed token (3.11). |
| Hidden-character game: click check | Fits | Target and decoy shapes are stored on the server as numbers from 0 to 1 and are never sent to the browser. The check pads the shape and picks the nearest shape. |
| Hidden-character game: images | Partially in place | A private bucket; picture addresses are issued at Start with a short expiry. The S3 client is not installed yet. The script uploads directly (for example with boto3), as for other script-made puzzles. `CONTRACTS.md` needs a section for this flow in the same pass as the code. |
| Hidden-character game: leaderboard | Fits | Postgres `ORDER BY final time, misses, finish time`. Redis sorted sets break ties by member name, which is wrong here, and their scores are only exact up to 2^53. |
| Geometry game: puzzle generator and checker | Needs design (spike) | Python scripts. For angles, an engine over exact fractions with line directions as variables (the AlphaGeometry AR approach) checks that the answer is unique and finds the shortest derivation. Lengths need more rules (Pythagorean theorem, similar triangles); Newclid is the alternative to try, and length puzzles can also be written as chains of deterministic rules (section 7). Details in section 7. |
| Geometry game: figure and clues | Fits | The server sends the figure facts and the clues earned so far; the answer is checked as a whole number on the server. The frontend draws the figure as SVG, with KaTeX if needed. Drawing positions are generated, not to scale. |

Not needed for the MVP: websockets, a different frontend framework, an admin UI. The guessing games need no game engine; the playable challenge does (an emulator in the browser and a native replay runner on the server).

## 7. Puzzle creation **[decided: scripts first, AI only as a fallback]**

**[proposed]** A command-line script that builds a day's puzzles ahead of time:
1. Pull candidate answers and metadata (for the game guesser: title, franchise, year, platform, Metacritic score, genre) from a source API.
2. Apply rule-based filters in code (enough screenshots, minimum rating or popularity, not a recent answer, not the same series as a recent answer).
3. Download screenshots, store them in object storage together with each image's source URL (for the source credit in 3.7), and write the puzzle row for a chosen date.
4. For the game guesser, a human reviews the queue before the date comes (answers recognisable, first clue readable). The word game has no manual review (decision 31); its quality comes from the automatic filters in the script.

AI enters only if a script cannot fix a data problem, for example screenshots that show the title text or missing metadata. Each such case is decided in the game's own spec, not assumed now. Source data for the game guesser is a first-spec question; IGDB is the obvious candidate. Its terms (non-commercial on the free tier, per what I found) fit the no-monetization decision, but need to be checked at the source before relying on them.

**Movie game data sources (terms not fully verified; check each at the source).**
- TMDB (The Movie Database): a free API for non-commercial use with attribution; commercial use needs a license, and a project is commercial if its main purpose is to earn money for the owner. It has titles, genres, release years, cast, crew and stills. It does not say anything specific about stills, and developers report that artwork can still draw rights complaints. Fits the no-monetization decision (12) for now, and the attribution must be shown in the legal pages (3.7).
- IMDb non-commercial datasets: personal and non-commercial use, ratings with vote counts, not Metacritic. A license page exists; read it before use.
- OMDb API: returns IMDb rating and a Metascore field for movies, but coverage is incomplete; the free key is limited to 1,000 requests a day.
- Choosing which ratings to show (Metacritic, IMDb) and how to get them is a question for the movie game's own spec. Showing fewer hints (genre, year, cast, director from TMDB only) avoids the ratings terms.

**Playable challenge data [proposed].** A challenge is prepared ahead of time by a script plus one short manual step, because a person has to play the game once:
1. Pick a ROM from the vetted ROM list. A ROM enters the list only with: the license text or written permission, the source link, the file hash, the credits text, and a note on which objectives it supports.
2. Load the ROM in the pinned emulator build, play to the start of the level, and save the start state. The state belongs to that build.
3. Write the result rule: the memory addresses and conditions for score, level complete and game over, plus the time cap. This is the manual step. Where the game has source code the addresses come from it (73 of the 77 open-licensed catalog entries link a repository).
4. Record one replay (a human run) and check that the browser and the native runner give the same result from it. This is the test that a challenge is valid.
5. Schedule it for a date.

There is no admin UI (decision 11); the vetted ROM list and the challenge rows are files and script input.

**Hidden-character scenes [proposed].** Decision 19 applies: a script composes each scene from parts, so the script knows exactly where the target is and nobody marks it by hand.
1. Vet the parts. Each sprite pack enters a vetted list only with its license text, source link and credit text, like the ROM list. Prefer CC0 and public domain; keep CC BY-SA, non-commercial and GPL parts out of composites. Easiest start: a crowd of Open Peeps figures through DiceBear's offline library (CC0, no credit needed, repeatable from a seed), then Kenney characters recolored. Full-body "Waldo-style" crowds need more art than busts.
2. Place sprites with blue-noise sampling whose radius grows toward the bottom of the picture (fake perspective), draw back to front, and place the target last in a chosen zone with decoys that share two of its attributes.
3. Compute the checks and reject bad scenes: how much of the target is visible (from the alpha masks), target size relative to the picture, crowd density around it, number of near-duplicate decoys, contrast and saliency. Gate the extremes and sort the rest into difficulty tiers; the research found such predictions only rank about 75% of image pairs correctly, so they are rough.
4. Run a solver probe: template matching, and a few multimodal models, on the generated scene. If a naive solver finds the target easily, regenerate. Simulate color-vision deficiency and require that the target differs from its nearest decoys by more than hue.
5. Flatten to one image, redraw the target card (not a crop), cut the two image sizes, write the target and decoy shapes from the masks, store the credit list, upload the files and write the puzzle row.
6. Schedule it for a date.

A person plays the first batch to check the difficulty tiers (and the miss penalty, if one is added); after launch the real median solve times replace the computed ratings.

**Geometry puzzles [proposed].** Decision 19 applies: a script makes them, no AI. The pipeline follows Todd's generator (section 4) with a second, independent check.
1. Draw the target kind at random (an angle, a side, a radius or another length; decision 48, no kind more than twice in a row) and choose a figure family for the day's tier (a triangle with a line through a vertex, a triangle with an equal-sides marking, two parallel lines with a crossing line, a right triangle, a triangle cut by a parallel line, later a circle with points on it).
2. Build the figure from whole-number parameters: whole degrees, so that every angle is a whole number, and for lengths whole-number sides from Pythagorean triples or whole-number scale factors for similar triangles. List the facts that hold in it: equal sides, parallel lines, right angles, points on a circle.
3. Choose the givens and the target. Reject figures with an angle too close to 0 or 180 degrees, angles too small to draw and label, or lines that look concurrent when they are not (Todd's filters).
4. Check with the engine: the target must be determined by the givens and the facts (for angles, a linear system over exact fractions with one solution). If it is open or has more than one value, reject. For lengths see the next paragraph.
5. Find the shortest derivation (breadth first) and a difficulty value: the number of steps and of different rules. Sort the puzzle into a tier; reject too easy (the answer is a given, or one step) and too hard for the tier.
6. Choose the clues so that each one shortens the derivation or points at something it uses (3.12), and order them so that help grows.
7. Second check: build coordinates from the exact parameters and measure the target angle numerically; it must equal the answer. This is independent of the engine and catches bugs in it.
8. Make the drawing: positions varied within limits (not to scale), labels not overlapping, extra elements placed so that they fit.
9. Reject duplicates (two puzzles with the same structure, as Todd's set generator does).
10. Store the figure facts, the clues, the answer and the derivation (with rule names as keys for translation), and schedule it.
A person reads the first batch (about 60) to check that the figures look good and the clues feel helpful; after that the checks are automatic.

Open for the spike: whether our own small engine is enough, or Newclid is needed. Angle sums, equal angles, isosceles and parallel-line rules fit the linear model. Circle rules fit it too if arcs are variables (my reading). Langley-type problems may need congruent triangles or similarity, which the linear angle model does not give, so those either need a stronger engine or are written by hand.

Lengths **[proposed, untested]**: the Pythagorean theorem is quadratic and similar triangles give products, so the linear angle model does not cover them. Two ways to keep the answer unique: (a) write length puzzles as chains of deterministic rules, where each rule gives exactly one value from known ones (Pythagoras in a right triangle, a ratio from a parallel line, a diameter from a right angle on a circle), so the answer is unique by construction and the engine and the numeric construction in step 7 are second checks; (b) a general solver such as Newclid. A trap to exclude either way: the same givens can fit two different figures (for example two sides and an angle that is not between them), which would give two answers.

## 8. Risks

1. **Image rights (highest).** Screenshots, covers, logos and photos belong to others. The reference relies on a fair-use disclaimer and a takedown email; that is a practice, not a guarantee. Mitigations: no monetization (decided), a visible takedown contact, openly licensed sources where possible, legal advice before adding money. General information, not legal advice.
2. **Copying too closely.** The NYT has filed takedown notices against Wordle clones over name, grid and colors. Game mechanics are generally not copyrightable, name and visuals are enforced. Our name and style are our own; do not use "Wordle".
3. **Content supply.** One puzzle per game per day. Content, not code, limits how many games we can run. Plan games around how many puzzles can be made and reviewed. The word game alone needs 8 words a day (2 languages × 4 lengths), picked from dictionaries by the script with no manual review (decision 31).
4. **Fairness.** Obscure answers, series duplicates and unreadable first clues drew complaints on comparable sites.
5. **Answer leaks.** Mitigated by server-side checking.
6. **Streak pain.** Strict streaks punish missed days. Addressed by the 3-day grace in 3.5.
7. **Visual games cannot hide the answer.** In a game like the angle one, the browser must draw the answer (the red arrow's end point is in the page). Server-side checking still protects the result and the leaderboard from forged results, but it cannot stop someone reading the drawing's code. Options for such games: accept it (the game is casual, and the leaderboard is per game), or draw the figure as an image on the server. Decide per game.
8. **An exact-match win rule is hard.** In the angle game a win needs the exact degree in 4 guesses; my own best miss was 19% off. Each game's spec should set what counts as a win and what a close miss gets.
9. **Word lists and the word game's look.** The widely shared Wordle word lists were taken from the original game's code. Their license is unclear, and the NYT has filed takedown notices over Wordle's name, 5x6 grid and tile colors. For our word game: our own name, our own tile design and colors, and a word list from a source with a clear open license (to be chosen when the game is specced). General information, not legal advice.
10. **Word curation without a reviewer.** Players noticed when the NYT changed its lists; offensive words and obscure answers are a real complaint. Since nobody reviews the words by hand (decision 31), the script must filter automatically: nouns only, a minimum word frequency so answers are common, a blocklist for offensive words in both languages, no proper nouns, no abbreviations, and no words that are only a plural by adding S or ES (the NYT rule in section 4). A bad word that gets through can be replaced for a future date by editing the puzzle row. This is the weakest point of the plan, so the word game's spec must define the filters in detail.
11. **ROM rights (highest for the playable challenge).** A playable ROM is a whole copyrighted work. The rights notice and takedown email in 3.7 are meant for screenshots and do not cover it; Nintendo's FAQ and the RomUniverse case treat uploading ROMs as infringement (section 4). Mitigations: host only ROMs with a documented right (an open license or written permission), keep that record per ROM, show credits and a source link, never host commercial titles, and get legal advice before launch. General information, not legal advice.
12. **Forged results.** The browser can send any score. Mitigation: verification by replay (3.10). Until it exists, results are unranked.
13. **Replays that do not reproduce.** If the browser and the server end with different results from the same buttons, honest players lose their result. Mitigations: one pinned emulator build for both, the fixed seed, replays kept as tests, and the spike in section 10 before building.
14. **Content supply for the playable challenge.** Each day needs a rights-cleared game, a start state and a result rule that someone finds by hand. The open-licensed catalog is small (77 clearly open entries, 59 of them games). Mitigations: reuse a game across days with other levels, memory patches or objectives, or write our own games (GB Studio), which removes the rights question and adds work.
15. **Phones.** Touch controls, sound unlock and iOS browser quirks need testing on real devices. The emulator's demo code already has special handling for iPhone canvas scaling.
16. **Marks.** "Game Boy" is a Nintendo mark (to confirm). Using it descriptively in this spec is fine; the module's public name in the nav bar should be our own, like the word game (risk 2).
17. **Emulator accuracy.** The chosen emulator scores lower than the most accurate ones on timing tests (section 4), so each game must be tested in it. A new emulator build cannot reuse old start states and replays, so a change affects new challenges only (3.10).
18. **Guest progress can vanish in Safari.** Safari deletes data a site wrote with script (localStorage, IndexedDB) after 7 days of browser use without the player interacting with the site; cookies set by the server are exempt (MDN). A site added to the Home Screen counts days separately (WebKit blog, 2020). Guest progress and streaks (3.2, decision 16) live in that storage, so a Safari guest who is away for a week can lose them. `navigator.storage.persist()` asks for protection, but the browser decides. Mitigation: offer sign-up after a first win, and accept the loss for guests.
19. **Characters and art rights (highest for the hidden-character game).** The owner's example is made of well-known copyrighted characters. Whole characters are a weak fit for fair use, and the notice in 3.7 does not cover them. Use original art, CC0, public-domain or openly licensed parts only; keep CC BY-SA, non-commercial and GPL parts out of composites; keep a credit list per scene; keep public names clear of "Waldo", "Wally", "Hidden Folks" and "Hidden Through Time" (the working title Waldo stays in the spec and notes, decision 45). General information, not legal advice.
20. **Solvers and spoilers cannot be blocked.** The picture and the target card are on the screen, so a program, an extension or a shared screenshot can find the target (section 4; the same limit as risk 7). Mitigations: the server clock, click pauses and caps, plausibility flags, a solver probe at generation time, an optional miss penalty, and ranking only logged-in players. A friends-only board is the fallback if cheating shows up.
21. **Phones.** Pinch, drag and tap on iOS Safari and Android, memory with large images on 2 to 3 GB phones, and hit areas for fingers. Every gesture library checked has open touch issues, so real-device tests are needed before launch (section 10, step 6).
22. **Content sameness and difficulty drift.** 365 scenes a year from stock parts can look alike, and computed difficulty is rough. Mix themes and styles, tier by metrics, and replace the computed rating with real median times after launch.
23. **Wrong or ambiguous geometry puzzles.** One puzzle with a wrong answer, or two possible answers, breaks trust; Mathler players complained about several valid answers (section 4). Mitigations: the two independent checks in section 7, a unique-answer rule, a person reading the first batch, and a report link per puzzle (the contact email in 3.7). Lengths add a trap of their own: the same givens can fit two different figures (for example two sides and an angle that is not between them), so a length puzzle must be unique by construction (section 7).
24. **Audience and difficulty.** Geometry can feel like school; Mathler is reported harder than Wordle and Euclidea's main complaint is difficulty. Mitigations: an easy start of the week, the clue ladder, the derivation shown at the end, no clock. Nothing is known about how many of our players want this game. Random kinds make the difficulty uneven from day to day, because an angle puzzle and a radius puzzle of the same step count are not equally hard; the generator rates difficulty per kind and a playtest tunes the tiers.
25. **Sameness.** A generator with a few figure families makes look-alike puzzles. Mitigations: many figure families, a duplicate check by structure, and special days.
26. **Solvable by tools.** A calculator, GeoGebra or an AI model can solve these puzzles (not tested), and nothing can stop it, as with risks 7 and 20. The game is built for learning and personal progress; whether it has a board is decided in its own spec.

## 9. Open questions

1. Playable challenge: does a run that started before midnight and ended after it belong to the day it started? **[proposed]** yes (3.10).
2. Roles (3.13): how is the role stored? **[proposed]** A `role` text column with permissions mapped in code. Alternatives: an `is_admin` boolean, or role and permission tables.
3. Roles (3.13): which unreleased puzzles may an admin open? **[proposed]** Every scheduled future day, so the whole buffer can be checked before it goes live. Alternatives: only the next 3 days, or scheduled days plus drafts not yet scheduled.
4. Roles (3.13): do an admin's plays count? **[proposed]** Never: every admin play is a test play, and the owner plays for real with a separate player account. Alternative: count an admin's plays of today's puzzle, and exclude only upcoming puzzles and plays after a reset.
5. Roles (3.13): is a second factor required for admin accounts? **[proposed]** Yes, TOTP before public launch. Alternative: password only for now.

Every other question asked so far is answered and recorded as decisions 51 to 58. New questions are added here.

## 10. Next steps

1. All questions asked so far are answered (decisions 51 to 58). The first feature specs (a) to (g) can start. Specs (h), (i) and (j) wait for their spikes (steps 5, 6 and 7). The games come in the order of decision 53.
2. Write the first feature specs: (a) site shell with the nav bar and same-screen routing, (b) game module contract and puzzle model, (c) progress for guests and accounts, (d) archive list and past-puzzle play, (d2) legal footer and pages, (e) stats and share, (f) the game guesser, including its puzzle-creation script, (g) leaderboard, (h) the playable challenge (after the spike in step 5), (i) the hidden-character game (after the spikes in step 6), (j) the geometry game (after the spike in step 7).
3. Clean up MyList leftovers: both `CLAUDE.md` files, the two `dynamic-category-schema` skills, the MyList name in the UI and in `package.json` and `index.html` is part of Milestone 1, Phase 0 (`specs/01-phase-0-rebrand-optional-login-shell.md`). The stale `CONTRACTS.md` sections are already removed. Repo folder names stay as they are for now.
4. Update `CONTRACTS.md` for each boundary change in the same pass.
5. Spike for the playable challenge, before its feature spec: one open-licensed ROM, a start state, a result rule and a recorded replay. Run the replay in the browser and in a native runner built from the same emulator source, and compare the final memory and the result. It answers risks 12 and 13 and replaces my estimates of state size, replay size and verification time with measurements. It is also the first chance to see whether the chosen ROM plays well on a phone.
6. Spikes for the hidden-character game, before its feature spec: (a) a one-day test of the viewer on an old iPhone, a mid-range Android phone, an iPad and a laptop with a trackpad; (b) size and memory of real 4096-pixel scenes; (c) a solver probe (template matching and a few multimodal models) on 20 generated scenes; (d) a playtest with about 10 people to see whether wrong-click spamming needs a penalty and to set the difficulty tiers.
7. Spike for the geometry game, before its feature spec: a generator prototype for two figure families (a triangle with a line through a vertex, and parallel lines with a crossing line). Measure how many random choices of givens give a unique answer, the spread of derivation lengths, and how the engine compares with Newclid; draw 20 figures and check that they are readable; have a person solve 20 puzzles with the clues and say whether each clue helped; and compare how hard the kinds feel at the same derivation length.

**Milestone 1** (the owner's plan of 2026-10-27): a production-ready site with one game, the game guesser. The task plan, the definition of done, the decisions it needs and the order are in [MILESTONE-1.md](MILESTONE-1.md). It starts with changing the existing app into Daily Game Challenge (name, nav, optional login, no Lists), then builds the game guesser and the production hardening.

## 11. Sources

- Verified directly in the browser on 2026-10-23: guessthe.game and guessthelogo.wtf.
- guessthe.game: [ResetEra launch thread](https://www.resetera.com/threads/guess-the-game-its-framed-but-for-games.608073/), [third-party listing](https://wordletoday.io/guessthe-game)
- Gamedle: [gamedle.wtf](https://www.gamedle.wtf/guess)
- Round-ups: [Den of Geek](https://www.denofgeek.com/games/best-daily-games-wordle-clones-spin-offs), [Mental Floss](https://www.mentalfloss.com/fun/games/wordle-alternatives-puzzles-games), [Sportskeeda](https://www.sportskeeda.com/games/best-wordle-variations)
- Framed: [T3](https://t3.com/news/wordle-for-movie-lovers-is-here-guess-the-film-from-the-screenshot), [What to Watch](https://www.whattowatch.com/news/framed-the-new-game-thats-wordle-but-for-movie-fans)
- Hubs: [Axios on Puzzmo](https://www.axios.com/2023/10/20/puzzmo-hearst-zach-gage-new-york-times), [NYT Games app](https://apps.apple.com/app/id307569751)
- Archives: [Looper](https://www.looper.com/860877/why-you-cant-play-past-puzzles-in-wordle-anymore/), [Tom's Guide](https://tomsguide.com/news/new-york-times-killed-wordle-archive-but-there-are-other-options)
- Streaks: [LogRocket](https://blog.logrocket.com/product-management/streaks-user-retention/), [Yu-kai Chou](https://yukaichou.com/gamification-analysis/streak-design-gamification-motivation-burnout/)
- Legal and licensing: [NYT takedowns](https://www.axios.com/2024/03/15/nyt-wordle-clones-takedown-dmca-copyright), [CNBC](https://www.cnbc.com/2022/02/24/wordle-kind-of-rips-off-lingo-a-copyright-lawyer-says-thats-ok.html), [IGDB commercial use thread](https://discuss.dev.twitch.com/t/commercial-use-of-igdb-api/23567), [Heardle shutdown](https://9to5mac.com/2023/04/14/heardle-spotify-shutting-down/)
- Answer leakage and day boundaries: [DLE games guide](https://aiidelist.com/blog/how-to-build-your-own-dle-games)
- Playable challenge, emulators (read 2026-10-26): [binjgb](https://github.com/binji/binjgb) (README, demo code, exported functions, tester and test scripts), [EmulatorJS](https://github.com/EmulatorJS/EmulatorJS) and [its options docs](https://github.com/EmulatorJS/emulatorjs.org), [Nostalgist.js](https://nostalgist.js.org/apis/launch/), [mGBA-wasm](https://www.npmjs.com/package/@thenick775/mgba-wasm), [gbdev emulator shootout](https://gbdev.io/GBEmulatorShootout/), [gbajs3](https://github.com/thenick775/gbajs3), [Homebrew Hub front-end](https://github.com/gbdev/virens)
- Playable challenge, ROM catalog: [Homebrew Hub API](https://github.com/gbdev/homebrewhub/blob/main/API.md), [its database](https://github.com/gbdev/database)
- Playable challenge, rights: [Sony v. Connectix](https://en.wikipedia.org/wiki/Sony_Computer_Entertainment,_Inc._v._Connectix_Corp.), [RomUniverse ruling](https://www.gamedeveloper.com/business/judge-orders-rom-site-to-permanently-destroy-its-pirated-nintendo-games), [Nintendo FAQ](https://en-americas-support.nintendo.com/app/answers/detail/a_id/55888/~/intellectual-property-&-piracy-faq), [17 U.S.C. section 117](https://www.law.cornell.edu/uscode/text/17/117)
- Playable challenge, platform: [MDN COEP](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Cross-Origin-Embedder-Policy), [MDN CSP script-src](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Content-Security-Policy/script-src), [MDN storage eviction](https://developer.mozilla.org/en-US/docs/Web/API/Storage_API/Storage_quotas_and_eviction_criteria), [WebKit storage post](https://webkit.org/blog/10218/full-third-party-cookie-blocking-and-more/), [FastAPI path operation configuration](https://fastapi.tiangolo.com/advanced/path-operation-advanced-configuration/), [Vite assets](https://vite.dev/guide/assets)
- Find-it game, reference games: [Hidden Folks (Wikipedia)](https://en.wikipedia.org/wiki/Hidden_Folks), [Hidden Folks press page](https://hiddenfolks.com/press), [Hidden Folks on Steam](https://store.steampowered.com/app/435400/Hidden_Folks/), [Kill Screen interview](https://www.killscreen.com/get-lost-found-playful-world-hidden-folks), [Hidden Through Time on Steam](https://store.steampowered.com/app/524910/Hidden_Through_Time/), [Where's Wally (Wikipedia)](https://en.wikipedia.org/wiki/Where%27s_Wally%3F), [The Daily Spy](https://thedailyspy.com), [NYT Mini help](https://thenewyorktimeshelpcenter.helpjuice.com/360025912452-The-Mini-Crossword)
- Find-it game, web viewer: [react-zoom-pan-pinch](https://github.com/BetterTyped/react-zoom-pan-pinch), [@panzoom/panzoom](https://github.com/timmywil/panzoom), [use-gesture](https://use-gesture.netlify.app/docs/gestures/), [OpenSeadragon](https://openseadragon.github.io/), [Leaflet CRS.Simple](https://leafletjs.com/examples/crs-simple/crs-simple.html), [MDN touch-action](https://developer.mozilla.org/en-US/docs/Web/CSS/touch-action), [MDN pointer events](https://developer.mozilla.org/en-US/docs/Web/API/Pointer_events/Pinch_zoom_gestures), [libvips dzsave](https://www.libvips.org/API/current/method.Image.dzsave.html), [web.dev image formats](https://web.dev/articles/choose-the-right-image-format), [WebKit bug 302801](https://bugs.webkit.org/show_bug.cgi?id=302801)
- Find-it game, content and rights: [Bridson's Poisson-disk paper](https://www.cs.ubc.ca/~rbridson/docs/bridson-siggraph07-poissondisk.pdf), [SciPy PoissonDisk](https://docs.scipy.org/doc/scipy/reference/generated/scipy.stats.qmc.PoissonDisk.html), [Open Peeps](https://www.openpeeps.com/), [DiceBear licenses](https://www.dicebear.com/licenses/), [Kenney](https://kenney.nl/support), [Openclipart](https://openclipart.org/about), [OpenGameArt FAQ](https://opengameart.org/content/faq), [US Copyright Office on fair use](https://www.copyright.gov/fair-use/), [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)
- Find-it game, accessibility and cheating: [WCAG 2.5.8 target size](https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html), [WCAG 2.5.1 pointer gestures](https://www.w3.org/WAI/WCAG22/Understanding/pointer-gestures.html), [WCAG 2.2.1 timing](https://www.w3.org/WAI/WCAG22/Understanding/timing-adjustable.html), [Game Accessibility Guidelines](https://gameaccessibilityguidelines.com/full-list/), [NN/g touch target size](https://www.nngroup.com/articles/touch-target-size/), [OWASP game security framework](https://owasp.github.io/www-project-gamesec-framework/OGSF), [OpenCV template matching](https://raw.githubusercontent.com/opencv/opencv/4.x/doc/py_tutorials/py_imgproc/py_template_matching/py_template_matching.markdown)
- Geometry game, what exists: [AnglesGame](https://anglesgame.com/), [The Angle](https://theangle.wtf/), [Angledle](https://angledle.com/), [Dr. Mike's Angle Quiz](https://www.dr-mikes-math-games-for-kids.com/angle-quiz.html), [Transum Angle Chase](https://mathszone.co.uk/category/using-applying/angles-problem-solving/), [Nerdle (Wikipedia)](https://en.wikipedia.org/wiki/Nerdle), [Mathler review](https://www.tomsguide.com/news/what-is-mathler-and-how-to-play), [Euclidea](https://apps.apple.com/app/id927914361), [Langley's Adventitious Angles](https://en.wikipedia.org/wiki/Langley%27s_Adventitious_Angles), [Tatham on Langley](https://www.chiark.greenend.org.uk/~sgtatham/quasiblog/adventitious/)
- Geometry game, generation and engines: [Todd, Theorem discovery amongst cyclic polygons (ADG 2023 slides)](https://www.adg2023.matf.bg.ac.rs/downloads/slides/TheoremDiscoveryTodd.pdf), [Saltire problem generator](https://www.saltire.com/ProblemGenerator), [AlphaGeometry `ar.py`](https://github.com/google-deepmind/alphageometry/blob/main/ar.py), [Newclid paper](https://arxiv.org/abs/2411.11938), [Newclid on PyPI](https://pypi.org/project/newclid), [KaTeX](https://katex.org/), [MathJax](https://www.mathjax.org/), [JSXGraph](https://jsxgraph.org/), [Mafs](https://mafs.dev/)
- Geometry game, hints: [O'Rourke et al. 2014, hint sequences](https://grail.cs.washington.edu/wp-content/uploads/2015/08/orourke2014hsm.pdf), [Razzaq and Heffernan, hints](https://web.cs.wpi.edu/~nth/pubs_and_grants/papers/2010/ITS/Razzaq%20Hints%20Is%20It%20Better%20to%20Give%20or%20Wait.pdf)
- Geometry game, lengths and radii: [Newclid abstract](https://arxiv.org/abs/2411.11938), [Pappus' Sangaku](https://www.cut-the-knot.org/pythagoras/SteinerSangaku.shtml), [Sangaku overview](https://yadda.icm.edu.pl/baztech/element/bwmeta1.element.baztech-3ecada10-b775-4b8c-8212-0e0887ba68ec/c/PJANIC_K.__Sangaku.pdf), [Apollonian gasket](https://en.wikipedia.org/wiki/Apollonian_gasket)

- Roles and admin tools (read 2026-10-30): [OWASP Authorization Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Authorization_Cheat_Sheet.html), [OWASP Multifactor Authentication Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Multifactor_Authentication_Cheat_Sheet.html), [OWASP API Top 10:2023](https://api-security.owasp.org/editions/2023/en/0x11-t10), [PostgreSQL ALTER TYPE](https://www.postgresql.org/docs/16/sql-altertype.html), [Alembic autogenerate](https://alembic.sqlalchemy.org/en/latest/autogenerate.html), [alembic-postgresql-enum](https://pypi.org/p/alembic-postgresql-enum), [FastAPI OAuth2 scopes](https://fastapi.tiangolo.com/advanced/security/oauth2-scopes/), [GitLab admin mode epic](https://gitlab.com/groups/gitlab-org/-/epics/2158), [GitHub sudo mode (Enterprise Server docs)](https://docs.github.com/es/enterprise-server@3.6/authentication/keeping-your-account-and-data-secure/sudo-mode)

## 12. Architecture and operations

The technical decisions for running the site in production (environments, error handling, CI/CD, hosting, security, observability, backups, testing, repo workflow) are in [ARCHITECTURE.md](ARCHITECTURE.md), written from a research report of 2026-10-27. It lists eight defects found in the two repos that should be fixed before any deploy (section 1 there), a proposed target shape (section 2), the decisions the owner must make (section 3) and a prioritised plan with the first 10 tasks (section 15). Decisions the owner takes are recorded in section 2 of this file.
