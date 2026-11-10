# Spec: Phase 2, the game in the browser   |   Spec ID: SPEC-03   |   Status: agreed with the owner's answers (2026-11-09)

Covers Milestone 1, Phase 2, tasks M1-30 to M1-37 (`MILESTONE-1.md` section 4). Frontend only: it consumes the API seam of SPEC-02 as documented in `CONTRACTS.md` ("Games", "Clock", "Errors") and adds no endpoint.
It lives in the root `specs/` folder next to SPEC-01 and SPEC-02 because it builds on the seam they fix, and because Q2 and Q11 below may turn into boundary changes.
Main inputs: SPEC-02 with the owner's answers (Q1 to Q20, and the 2026-11-06 change to Q2), SPEC-01 (shell, sidebar, i18n, auth state), `SPEC.md` (decisions 7, 14, 15, 16, 20, 27, 32, 51; sections 3.1 to 3.5, 4; risk 18), `CONTRACTS.md`, `ARCHITECTURE.md` sections 5, 8 and 9, the frontend `CLAUDE.md`, the generated client and the Phase 1 frontend plan's hand-off notes. Written 2026-11-06.

## In short

1. The placeholder game screen becomes the game guesser: six steps, an image per step (a muted looping clip at step 6), hints, a title search, Submit and Skip, the guess list and "N guesses left".
2. Guests keep their games in this browser and resend earlier guesses with each request. A reload keeps the game. A page open across 00:00 UTC keeps its puzzle and says the day changed.
3. When a game ends: win or lose, the answer, the guesses, a spoiler-free share text, stats, "Play previous days" and a countdown to 00:00 UTC.
4. Stats come from the server for an account and are computed in the browser for a guest, with the same S1 to S19 and T1 to T4 rows as the backend.
5. The archive lists past days with the player's state and opens any of them at `/games/{slug}/{date}`.
6. A guest who wins is invited to sign up. On login or sign-up the browser's games move into the account, with their `daily_proof`, and are then removed from the browser.
7. Every state the player can hit (loading, empty, offline, expired session, duplicate guess, rate limit, CSRF refusal) has a defined screen or message in English and Russian. The game works with a keyboard, a touch screen and a screen reader.

## Owner's answers (2026-11-09)

The owner answered all 12 questions on 2026-11-09 and accepted the recommended default for each, so the criteria below stand as written. Full text, options and reasoning are in the last section.

| # | Question | Answer | Criteria affected |
|---|---|---|---|
| Q1 | Share text: what it contains and in which language | Accepted: interface language; site and game name with `#number`, one square per guess used, score `N/6` or `X/6`, link to the puzzle's own page | AC-68, AC-69 |
| Q2 | Archive state boxes: the server gives an account only `state` and `guesses_used`, not each guess's result | Accepted: same boxes for guests and accounts, built from state and count only; no backend change | AC-84, AC-85 |
| Q3 | Sign-up nudge: when, where, how often | Accepted: inline card on the end screen after a guest's win, until "Not now" is pressed once; never a pop-up | AC-93, AC-94 |
| Q4 | A page open across 00:00 UTC | Accepted: keep the open puzzle, show a message with "Play today's puzzle"; never switch on its own | AC-47 to AC-49 |
| Q5 | Step-6 clip when the system asks for reduced motion | Accepted: do not start it on its own; show the still frame with a play button | AC-23 |
| Q6 | What the player sees after a merge | Accepted: one short message with the number stored; nothing about rejected or unproven entries | AC-97 |
| Q7 | How long guest games stay in the browser | Accepted: kept until merged; no pruning in Milestone 1 | AC-37 |
| Q8 | Stored guest progress the server calls invalid | Accepted: drop that one puzzle's record, say so, start the puzzle again | AC-42 |
| Q9 | Where the countdown shows | Accepted: end screen of today's puzzle only | AC-103 |
| Q10 | Hint kinds are free strings in the API; `CONTRACTS.md` does not list them | Accepted: add the five kinds to `CONTRACTS.md`; unknown kinds get a generic label | AC-11 |
| Q11 | A `Retry-After` value on 429 | Accepted: show the message and re-enable Submit at once; no countdown | AC-57 |
| Q12 | A "How to play" dialog | Accepted: not in Phase 2 | none |

## Problem & Motivation

- Phase 0 left a "coming soon" placeholder where the game goes. Phase 1 built the backend: views, guesses, resume, stats, archive, merge, clock and signed clue media (SPEC-02). Nothing in the browser uses them yet.
- The Milestone definition of done (items 3 and 4) needs a guest to play today's and past puzzles, see the end screen, stats and a share text, keep progress across a reload, and keep it on sign-up.
- Guests are stateless on the server (decision 16), so the browser owns guest progress: what it stores, what it resends, and how it hands it to an account. A mistake here loses a player's streak, which is the main thing that brings players back (SPEC section 5).
- Safari can delete script-written storage after 7 days without a visit (risk 18). The planned answer is a sign-up offer after a first win, plus the merge.
- Several states come from the seam itself and are easy to miss: an expired session mid-game (`signed_in: false`), a link to a clue that expired, a guess sent just after midnight, a refused origin. Each needs a defined outcome in the browser.

## Goals / Non-goals

**Goals**
- A playable game guesser on `/`, `/games/{slug}` and `/games/{slug}/{date}`, against the real backend, for guests and accounts alike.
- A clue-ladder screen that reads step and guess counts from the view, so the movie game can reuse it later (SPEC 3.3).
- A title search with suggestions that works by keyboard, touch and screen reader.
- Guest progress in the browser: restored on reload, resent as `previous`, safe across tabs and across midnight.
- End screen, share text, stats dialog, archive screen, sign-up nudge, guest merge with `daily_proof`, and the countdown.
- Defined behavior for every error code the game routes can return, and for offline use.
- English and Russian texts for everything new.

**Non-goals**
- Any new endpoint or change to a response shape. A real gap is raised as a question (Q2, Q10), not designed here.
- The source-credits page (M1-23, Phase 3). The view's `source_url` is not shown in Phase 2.
- Rate limits themselves (M1-42); Phase 2 only handles a 429 if one comes.
- Leaderboards, community stats, rank, settings page, hard mode, stats export (SPEC 3.9).
- Offline play or a service worker (ARCHITECTURE 8: answers are checked on the server).
- Variants other than the game guesser's `default`. There is no variant selector.
- A "How to play" dialog (Q12), retailer links and game descriptions on the end screen.
- Link previews per puzzle (M1-47 is one static card).

## User stories

| ID | As a ... | I want ... | Covered by |
|---|---|---|---|
| US-1 | visitor | to open the site and play today's puzzle at once, with no account | AC-1 to AC-4, AC-7 to AC-17 |
| US-2 | player | to see each clue, its hint and the clip at step 6, on a phone or a laptop | AC-9 to AC-11, AC-19 to AC-25 |
| US-3 | player | to find a game by typing part of its name, with typos, and pick it | AC-26 to AC-36 |
| US-4 | guest | to reload or come back later and find my game as I left it | AC-37 to AC-46 |
| US-5 | player with the page open at midnight | to finish my puzzle and be told a new one is out | AC-47 to AC-49 |
| US-6 | signed-in player whose session ends mid-game | to keep the game I see and carry on as a guest | AC-50 to AC-54 |
| US-7 | player | clear messages when something goes wrong, without losing my picked title | AC-55 to AC-62 |
| US-8 | player who finished | to see the result and the answer and share it without spoiling it | AC-63 to AC-71 |
| US-9 | player | my stats and streak, the same numbers the server would give | AC-72 to AC-79 |
| US-10 | player | to browse past days with my state for each and play any of them | AC-80 to AC-89 |
| US-11 | guest who just won | to be offered an account, and to keep every game when I sign up or log in | AC-90 to AC-100 |
| US-12 | player | to know how long until the next puzzle | AC-101 to AC-105 |
| US-13 | keyboard, touch or screen-reader user | to play the whole game my way | AC-12, AC-21, AC-32 to AC-34, AC-78, AC-89, AC-104, AC-106 to AC-111 |
| US-14 | Russian-speaking player | the interface in Russian, with correct plurals | AC-106, string table |

## Acceptance criteria (EARS)

Each group names its source. "Screen" is the game screen of SPEC-01 AC-39 to AC-41. "View" is the puzzle view of SPEC-02 AC-25. "Guest record" is the browser's stored copy of one guest game (AC-37). "Today" is the server's UTC date; the device clock never decides it (SPEC-02 AC-69). "Clock offset" is the difference between `GET /v1/clock`'s `now` and the device clock, for display only.

### M1-30 Game screen and the clue ladder (decisions 5, 8; SPEC 3.3, 4; SPEC-01 AC-39 to AC-56; SPEC-02 AC-3, AC-7, AC-8, AC-15, AC-17, AC-25, AC-26)

- **AC-1** WHEN the game guesser's screen opens, the system shall show the playable puzzle for the shell's slug and date inside the same layout, with no redirect, in place of the Phase 0 placeholder. The registry entry keeps its five items; only its screen changes (SPEC-01 AC-56).
- **AC-2** WHEN the screen opens on `/` or `/games/{slug}`, the system shall ask for today's view and shall treat the `date` in the response as the puzzle's date. *Verify: device clock set to the next UTC day; the screen shows the server's today.*
- **AC-3** WHEN the screen opens on `/games/{slug}/{date}`, the system shall check in the browser only that the date is a real `YYYY-MM-DD` day. Whether it has a visible puzzle (future, before launch, missing) is decided by the backend's answer. This replaces Phase 0's temporary first-puzzle-date bound (SPEC-01 AC-45).
- **AC-4** IF the view answers 404 `puzzle_not_found`, THEN the system shall show the in-layout "No puzzle for this date" screen with a link to today's puzzle. IF it answers 404 `game_not_found`, THEN it shall show "Unknown game".
- **AC-5** The screen shall choose what to draw by the view's `type`. IF the type is one the frontend does not know, THEN the screen shall show the in-layout game error with "Try again", and the sidebar shall keep working.
- **AC-6** WHILE the view is loading, the screen shall show a placeholder of the same size as the game, and the sidebar shall stay usable.
- **AC-7** The screen header shall show the game's name, the puzzle number as `#N` and the puzzle date as a UTC day in the current language. The browser tab title shall stay the game's name (SPEC-01 AC-3), never anything from the puzzle.
- **AC-8** The clue ladder shall take the number of steps and guesses from the view (`max_guesses`), not from a number fixed in the screen. *Verify: a fake view with `max_guesses` 5 shows five step tabs and "5 guesses left".*
- **AC-9** The ladder shall show one tab per step. A step in the view's `steps` shall be selectable; any other step shall be shown as locked, shall not be selectable and shall have no image.
- **AC-10** WHEN a new step is earned, the system shall select it. The player may then select any earned step to look at it again.
- **AC-11** WHEN the selected step has a `hint`, the system shall show it on or next to the clue as a translated label and the value as sent. Labels: `metacritic_score` "Metacritic", `platform` "Platform", `genre` "Genre", `year` "Release year", `developer` "Developer". IF the kind is not one of these, THEN the system shall show the value under the generic label "Hint" (Q10). Values stay in English (decision 32).
- **AC-12** The step tabs shall be reachable by keyboard: arrow keys move between earned steps, locked steps are skipped, and each tab's accessible name says its number and whether it is locked.
- **AC-13** The screen shall list the guesses in order. Each shows the title name, or "Skipped", and its result as an icon and a word, never by color alone: "Correct", "Right series" (`franchise`), "Wrong", "Skipped".
- **AC-14** WHILE the game is in progress, the screen shall show "N guesses left" from `guesses_left`, with the right plural form in each language.
- **AC-15** WHILE the game is in progress, the screen shall offer Skip. A skip uses one guess and earns the next step, as the server decides.
- **AC-16** WHILE a guess or skip request is running, the system shall not send another one for the same puzzle: Submit and Skip shall not act, and the picked title shall stay shown. *Verify: a double click on Skip sends one request (SPEC-02 edge case "Double-click on Skip").*
- **AC-17** WHEN a guess response arrives, the screen shall show the view from that response, with no second request (SPEC-02 AC-34).
- **AC-18** WHEN the view's status becomes `won` or `lost`, the screen shall show the end screen (M1-33), and all six steps shall become selectable. The system shall not show the answer, on screen or in the tab title, before that.

### M1-30 Clue media (SPEC-02 Q4, Q20, AC-25, AC-70 to AC-73; CONTRACTS "Clue media"; WCAG 2.2.2)

- **AC-19** The system shall reserve the clue's space from the media's `width` and `height` before the file loads, so the page does not jump, and shall show a loading state in that space.
- **AC-20** An image clue shall have a text alternative "Clue N of M" that never names or describes the game.
- **AC-21** The step-6 clip shall play muted, loop, start on its own where the browser allows, play inside the page (not full screen on a phone), show the `poster` before it plays, and use the `sources` in the order given, so the browser takes the first one it can play.
- **AC-22** The clip shall always have a visible play and pause control that works by keyboard, touch and pointer, with an accessible name that says the current action ("Pause clip" or "Play clip"). (WCAG 2.2.2: moving content that starts by itself and runs over 5 seconds needs a pause.)
- **AC-23** IF the browser blocks autoplay, THEN the system shall show the poster with the play control and no error. WHERE the system asks for reduced motion, the clip shall not start on its own and shall show the poster with the play control (Q5).
- **AC-24** IF a clue file fails to load, or a media request answers 403, THEN the system shall ask for the view again (the dated view for an account, resume with the stored guesses for a guest) and swap in the new links, keeping the selected step and whether the clip was playing. *Verify: fake an expired image link; one refetch, the same step stays selected.*
- **AC-25** IF the clue still fails after one refetch, THEN the system shall show "The clue didn't load" with "Try again" in the clue's place, and shall not refetch in a loop.

### M1-31 Title search (SPEC 4 "search list"; SPEC-02 AC-19 to AC-22, Q15, Q17; CONTRACTS "Title search")

- **AC-26** The guess input shall be a search box with a list of suggestions. WHILE the text has fewer than 2 letters or digits (as the server counts them, `CONTRACTS.md` "Title search"; "a." counts as 1), the system shall send no search and shall show "Type at least 2 letters".
- **AC-27** WHEN the trimmed text has 2 or more characters, the system shall search for it, and shall not send a request for every keystroke while the player is still typing. The list shall always belong to the current text: an older answer shall never replace a newer one.
- **AC-28** WHILE a search request runs, the system shall show "Loading…" in the list.
- **AC-29** The list shall show every item the server returns, up to 200, in the server's order. Each item shows the name and, when not `null`, the year and the franchise. The number of results shall be announced to screen readers.
- **AC-30** IF the search returns no items, THEN the list shall say "No games found". IF the search fails, THEN it shall say "Search failed. Try again.", keep the text, and search again when the text changes.
- **AC-31** A title already guessed in this game (same title id) shall be marked "Already tried" in the list and shall not be pickable.
- **AC-32** WHEN the player picks an item (click, tap, or Enter on the highlighted item), the box shall show that title and Submit shall become active. Submit (the button, or Enter once a title is picked) shall send the guess. WHILE no title is picked, Submit shall not act. Editing the text after a pick shall clear the pick.
- **AC-33** The search box shall follow the combobox pattern: Down and Up move through the items, Enter picks, Escape closes the list, Tab leaves without picking. A screen reader shall hear whether the list is open and which item is highlighted.
- **AC-34** On a phone each item shall be at least 44 CSS px high, the list shall scroll inside itself, and the page shall not scroll sideways at 320 CSS px.
- **AC-35** WHEN a guess is accepted and the game goes on, the system shall clear the box and keep the focus in it, ready for the next guess.
- **AC-36** The box shall not accept more than 100 characters (the server's limit, CONTRACTS "Title search").

### M1-32 Guest progress in the browser (decision 16; SPEC 3.2; SPEC-02 AC-37 to AC-40, AC-57, Q1, Q2 as changed, Q6; CONTRACTS "Guessing", "Resume", "The view")

- **AC-37** WHILE the player is a guest, the system shall keep in this browser one guest record per game, variant and date, holding: the guesses in order (title id and name, or a skip) with their results, the status, `counts_for_streak` from the first guess's response, and `daily_proof` (AC-40). It shall not store the answer, any media link, or anything keyed by language (SPEC-01 AC-55b). Records stay until merged (Q7).
- **AC-38** WHEN a guest submits a guess, the system shall send the guesses of the stored record for that puzzle as `previous`, read at the time of sending, so a guess made in another tab is included.
- **AC-39** WHEN a guest opens a puzzle that has a guest record with guesses, the system shall show the state from resume with those guesses, and shall not show the empty step-1 state first. With no record it shall show the plain view.
- **AC-40** WHEN any guest view (view, today, resume or guess) carries a non-null `daily_proof`, the system shall keep it with that puzzle's record, also before the first guess. A later `null` shall not erase it.
- **AC-41** WHEN a guest's guess is accepted, the system shall update the record before or as it shows the new step, so a reload straight after shows the same state. `counts_for_streak` shall be stored from the first guess's response only; a later `null` shall not overwrite it (SPEC-02 AC-40).
- **AC-42** IF a guest's resume or guess answers 422 `invalid_guess_history`, THEN the system shall drop that puzzle's record, say "The saved progress for this puzzle was damaged, so it starts again", and show the fresh view (Q8).
- **AC-43** IF a guest's guess answers 409 `puzzle_already_finished`, THEN the system shall resume with the stored guesses and show the end screen. (Another tab finished the game.)
- **AC-44** IF browser storage is blocked or full, THEN the game shall stay playable for the open tab and the system shall show once "This browser doesn't let the site save progress. Your game lasts until you close the tab." (SPEC-01 AC-68.)
- **AC-45** IF a stored record is not in the expected shape, THEN the system shall ignore it as if there were none, and shall not crash the screen. Stored data is untrusted; the server re-checks every guess.
- **AC-46** WHILE a guest has the same puzzle open in two tabs, a guess in one shall not erase a guess made in the other. *Verify: tab A guesses, tab B (stale) guesses; the record holds both, in order, or tab B gets `duplicate_guess` and nothing is lost.*

### M1-32 Midnight rollover (decision 10; SPEC 6 "Day boundary"; SPEC-02 Q1, AC-36, AC-69)

- **AC-47** A screen shall keep the puzzle it opened with. A page open across 00:00 UTC shall never switch puzzles by itself (Q4).
- **AC-48** WHEN a guess is submitted, the page becomes visible again, or the countdown reaches zero, and today (by the clock offset) is later than the date the page opened as today, the system shall show "A new day has started (UTC). You can finish this puzzle or play today's." with a "Play today's puzzle" link. The guess still goes to the page's date (SPEC-02 Q1): it is a daily play only if its first guess was before 00:00.
- **AC-49** WHEN `/` or `/games/{slug}` is loaded after 00:00 UTC, the system shall show the new day's puzzle. The earlier day's record stays and shows in the archive.

### M1-30 and M1-32 Account play and session changes (SPEC-02 AC-41, AC-42, Q11; CONTRACTS "The view"; Phase 1 frontend plan hand-off)

- **AC-50** WHILE signed in, the screen shall show the server's stored game, and the system shall not write account games to guest records.
- **AC-51** WHILE signed in, a guess shall carry the guesses the screen shows as `previous` (the server ignores them for an account), so that if the session has ended the guest result matches what the player sees.
- **AC-52** WHEN a game response says `signed_in: false` while the page shows a user, the screen shall show the view it just got, without falling back to step 1 or an extra empty state, and from then on shall keep that game as a guest record. (The session guard signs the page out, SPEC-02 AC-42.)
- **AC-53** IF a signed-in guess fails with a network error, THEN the system shall get the view again before it lets the player retry, so a guess the server did store is shown and not sent twice. *Verify: the fake server stores a skip and drops the answer; the retry shows the skip and does not send a second one.*
- **AC-54** WHEN the player signs in or out while a screen is open, the screen shall load the puzzle again for the new state: after sign-in the account's game, once the merge has finished (AC-100); after sign-out this browser's guest record, which may be empty.

### Error and offline states on game requests (CONTRACTS "Errors", "Guessing"; ARCHITECTURE 5, 8; SPEC-02 AC-75, AC-89)

- **AC-55** IF a guess answers 422 `duplicate_guess`, THEN the system shall say "You have already tried this one." next to the box, clear the pick, and use no guess.
- **AC-56** IF a guess answers 422 `title_not_found`, THEN the system shall say "Pick a title from the list." and clear the pick.
- **AC-57** IF any game request answers 429 `too_many_requests`, THEN the system shall show "Too many attempts. Please wait a moment and try again.", keep the picked title, and shall not resend by itself (Q11).
- **AC-58** IF any game request answers 403 `csrf_origin_mismatch`, THEN the system shall show its catalogue text and shall not retry by itself.
- **AC-59** IF a guess fails with a network error, 503 `service_unavailable` or 500, THEN the system shall show the matching catalogue text next to Submit, keep the picked title, and let the player send it again (after AC-53 for an account).
- **AC-60** IF the view itself fails with a network error or a 5xx, THEN the screen shall show the in-layout error with the request id when there is one and "Try again"; the sidebar, the archive link and language and theme shall keep working. There is no offline play and no queue of unsent guesses.
- **AC-61** Every error text shall come from the catalogues by `code`, in both languages; the backend's English `title` shall never be shown (CONTRACTS "Errors").
- **AC-62** Every message of this section shall be announced to screen readers when it appears.

### M1-33 End screen and share text (SPEC 3.1, 3.4, 4 "end screen"; decisions 9, 24)

- **AC-63** WHEN the game is won, the end screen shall say "You got it!" and "Solved in N guesses" (skips count, decision 9). WHEN it is lost, it shall say "Not this time". Both shall show the answer's name, year and franchise when not `null`, and the full guess list with results.
- **AC-64** WHEN the game ends during play, the system shall move the focus to the end screen's heading. WHEN a finished puzzle is opened, it shall not move the focus.
- **AC-65** The end screen shall offer "Share result", "Statistics" (M1-34) and "Play previous days" (the archive). For today's puzzle it shall show the countdown (M1-37); for a past puzzle, a "Play today's puzzle" link instead.
- **AC-66** WHEN the player presses "Share result", the system shall copy the share text and show "Result copied", announced to screen readers.
- **AC-67** IF copying is refused or not available, THEN the system shall show the share text in a read-only box, selected, with "Couldn't copy. Select the text below and copy it."
- **AC-68** The share text shall hold (Q1): the site and game name with `#N`; one square per guess used, in order (correct, right series, wrong, skipped each with its own symbol); the score `N/6`, or `X/6` for a loss; and the link to the puzzle's own page `/games/{slug}/{date}` on the site's origin. Its words follow the interface language.
- **AC-69** The share text shall never contain the answer, a guessed title, a hint value or a media link. It shall be the same for a guest and an account with the same guesses. *Verify: a unit test over a won game, a lost game and an all-skip game finds none of the view's names, hint values or media URLs in the text.*

### M1-34 Stats dialog (decisions 14, 15, 51; SPEC 3.1, 3.5; SPEC-02 AC-46 to AC-54, Q8; CONTRACTS "Stats and streak")

- **AC-70** A "Statistics" button on the game screen, at any time, and on the end screen shall open a dialog for the current game and its default variant.
- **AC-71** The dialog shall show played, win % (wins divided by played, rounded to a whole number; 0 when nothing is played), current streak, max streak, and the guess distribution for 1 to 6 as bars, each with its number as text.
- **AC-72** WHEN the dialog is opened from the end screen of a won game, the bar for that game's guess count shall be marked.
- **AC-73** WHILE signed in, the numbers shall come from `GET /v1/games/{slug}/stats`. WHILE they load, the dialog shall show placeholders of the same size; IF the request fails, THEN it shall show the error text with "Try again".
- **AC-74** WHILE a guest, the system shall compute the numbers in the browser from the guest records with the server's rules: a finished record counts in played, wins and distribution, daily and archive alike; a streak day is a finished record of the default variant with `counts_for_streak` true, on its puzzle's date; the 3-day grace of SPEC-02 AC-50 applies, and "today" is the server's date by the clock offset.
- **AC-75** The browser computation shall pass every row S1 to S19 (SPEC-02 AC-52) and T1 to T4 (AC-54), with the same row ids, in one table-driven test.
- **AC-76** IF the clock request failed, THEN the guest computation shall use the device's UTC day as today.
- **AC-77** WHILE a guest, the dialog shall say "Stats from this browser. Sign up to keep them on every device." with a "Sign up" link that carries the current page as `redirect`.
- **AC-78** The dialog shall have a title, keep the focus inside while open, close on Escape and return the focus to the button that opened it.
- **AC-79** IF the stats request answers 401 while a user is shown, THEN the dialog shall show the guest numbers (the session guard has signed the page out).

### M1-35 Archive screen (decisions 7, 14, 20; SPEC 3.4, 3.9; SPEC-02 AC-63 to AC-66; CONTRACTS "Archive")

- **AC-80** `/games/{slug}/archive` shall list the game's past puzzles newest first, from the archive route, 30 at a time. "Show more" shall load the next page with `next_before`, and shall not show when `next_before` is `null`.
- **AC-81** Each row shall show `#N`, the date as a UTC day in the current language, the player's state as text ("Not played", "In progress", "Solved in N", "Not solved"), and the state boxes (AC-84).
- **AC-82** WHILE a guest, the state shall come from the guest records (no record is "Not played"). WHILE signed in, it shall come from the server's `state` and `guesses_used`.
- **AC-83** Each row shall be a link to `/games/{slug}/{date}`; opening it shows the puzzle on the same screen with no full reload, and opening it in a new tab works.
- **AC-84** Each row shall show one box per guess slot (6), built only from the state and the number of guesses used (Q2): used slots filled, the last one marked correct for a win, every used slot marked for a loss, empty slots for the rest.
- **AC-85** The boxes shall have a text alternative that says the same as the state text, so they are never the only carrier of the state.
- **AC-86** The list shall never show today or the answer. It shall start with a "Back to today's puzzle" link.
- **AC-87** WHILE the list loads, the screen shall show placeholder rows. IF there are no past puzzles, THEN it shall say "No past puzzles yet". IF loading fails, THEN it shall show the error text with "Try again" inside the layout.
- **AC-88** A past puzzle's screen shall say "Archive puzzle: it counts toward your stats, not your streak." (decision 14).
- **AC-89** WHEN "Show more" adds rows, the focus shall move to the first new row.

### M1-36 Sign-up nudge and guest merge (SPEC 3.2, risk 18; SPEC-02 AC-55 to AC-62, Q2 as changed 2026-11-06; CONTRACTS "Merge of a guest's local games")

- **AC-90** WHEN a guest's game ends in a win and the nudge has not been dismissed in this browser, the end screen shall show: "Nice win! Sign up to keep your streak and stats on every device. Your games from this browser come with you." with "Sign up", "Log in" and "Not now" (Q3).
- **AC-91** "Sign up" and "Log in" shall carry the current page as `redirect` (SPEC-01 AC-14, AC-15).
- **AC-92** The nudge shall be part of the end screen, never a pop-up, and shall not show to a signed-in player.
- **AC-93** WHEN the player presses "Not now", the nudge shall hide and shall not show again in this browser (Q3).
- **AC-94** WHERE storage is blocked, the nudge shall still show and "Not now" shall hide it for the open tab.
- **AC-95** WHEN login or sign-up succeeds and this browser holds guest records with at least one guess for a game, the system shall send them to that game's merge route: for each, `date`, `variant`, `guesses`, `played_as_daily` (true when the record's `counts_for_streak` is true) and `daily_proof` (the stored value or `null`).
- **AC-96** The system shall send at most 500 entries per request, and more in several requests (SPEC-02 AC-62).
- **AC-97** WHEN every request has answered 200, the system shall delete the sent records from this browser, rejected ones included, and shall say "Added N games from this browser to your account." where N is the sum of `stored`; with N = 0 it shall say nothing (Q6).
- **AC-98** IF any merge request fails (network, 5xx, 503), THEN the system shall keep every record, say "Couldn't move your games from this browser. We'll try again next time.", and try again on the next page load while signed in. This is safe because the merge is idempotent (SPEC-02 AC-61).
- **AC-99** IF a merge request answers 401, THEN the system shall keep every record.
- **AC-100** WHILE a merge for this browser runs, the screen shall not show the account's game; it shall show it once the merge has finished or failed.
- *Verify (no progress lost): a guest wins today's puzzle and finishes two archive puzzles, then signs up. Stats show played 3, current streak 1; the browser holds no guest records; the archive shows the three states.*

### M1-37 Countdown (decision 10; SPEC 3.1; SPEC-02 AC-67 to AC-69, Q14; CONTRACTS "Clock")

- **AC-101** The countdown shall show "Next puzzle in hh:mm:ss" to the clock's `next_reset`, updated every second, using the clock offset, so a wrong device clock does not change it.
- **AC-102** IF the clock request fails, THEN the countdown shall count to the next 00:00 UTC by the device clock.
- **AC-103** The countdown shall show on the end screen of today's puzzle (Q9).
- **AC-104** WHEN it reaches zero, it shall say "A new puzzle is ready" with "Play today's puzzle", and shall not load the new puzzle by itself. Screen readers shall not hear it every second; its current value shall be readable on demand.
- **AC-105** WHEN the page becomes visible again after being hidden, the system shall ask for the clock again before showing the countdown.

### Cross-cutting: languages, layout, accessibility, storage (decisions 21, 27, 32; SPEC 3.1, 3.6, 3.7; SPEC-01 AC-55, AC-61 to AC-69; ARCHITECTURE 8)

- **AC-106** Every new text shall come from the catalogues, in English and Russian (string table below), with Russian plural forms where a number is shown. Titles, franchises and hint values from the server stay as sent (decision 32). Dates use the current language and `UTC`.
- **AC-107** WHEN the language changes during a game, the screen shall keep its state, picked title and selected step (SPEC-01 AC-55a).
- **AC-108** At 320, 360, 768 and 1280 CSS px the game, end screen, dialog and archive shall not scroll sideways at page level; the clue shall fit the content width; controls shall be at least 24 by 24 CSS px, and 44 px high on phones.
- **AC-109** A player with only a keyboard shall be able to play a whole game: search, pick, Submit, Skip, step tabs, the clip's control, share, stats and archive, in a sensible focus order and with a visible focus.
- **AC-110** WHEN a guess is answered, a polite announcement shall say the result and what changed, for example "Wrong. Step 3 unlocked. 4 guesses left."
- **AC-111** Result colors shall have at least 3:1 contrast against their background in both themes and shall always come with an icon and a word (SPEC 3.1 "colorblind-safe").
- **AC-112** The only new things Phase 2 stores in the browser are the guest records and the nudge dismissal. Both shall be named for the privacy policy (M1-46, SPEC 3.7). This extends SPEC-01 AC-69.

### Interface strings (English and Russian)

These are the proposed texts. The Russian column needs the check of D6 (a Russian speaker) before launch. Existing keys (`errors.*`, `games.no_puzzle`, `games.unknown_game`, `games.archive_title`) are reused, not repeated.

| Where | English | Russian |
|---|---|---|
| Guesses left (one / few / many) | {{count}} guess left / {{count}} guesses left | Осталась {{count}} попытка / Осталось {{count}} попытки / Осталось {{count}} попыток |
| Skip | Skip | Пропустить |
| Submit | Guess | Ответить |
| Search placeholder | Search for a game… | Найдите игру… |
| Search too short | Type at least 2 letters | Введите хотя бы 2 символа |
| Search loading | Loading… | Загрузка… |
| Search count (one / few / many) | {{count}} result / {{count}} results | {{count}} результат / {{count}} результата / {{count}} результатов |
| Search empty | No games found | Игры не найдены |
| Search failed | Search failed. Try again. | Поиск не удался. Попробуйте ещё раз. |
| Already tried | Already tried | Уже было |
| Step tab | Step {{n}} | Шаг {{n}} |
| Locked step | Step {{n}}, locked | Шаг {{n}}, закрыт |
| Clue alt text | Clue {{n}} of {{total}} | Подсказка {{n}} из {{total}} |
| Results | Correct / Right series / Wrong / Skipped | Верно / Та же серия / Неверно / Пропущено |
| Hint labels | Metacritic / Platform / Genre / Release year / Developer / Hint | Metacritic / Платформа / Жанр / Год выхода / Разработчик / Подсказка |
| Clip control | Play clip / Pause clip | Воспроизвести ролик / Поставить ролик на паузу |
| Clue failed | The clue didn't load. | Подсказка не загрузилась. |
| Try again | Try again | Попробовать ещё раз |
| Guess announcement | {{result}}. Step {{n}} unlocked. {{left}}. | {{result}}. Открыт шаг {{n}}. {{left}}. |
| Win | You got it! | Угадали! |
| Solved in (one / few / many) | Solved in {{count}} guess / Solved in {{count}} guesses | Угадано с {{count}} попытки / Угадано с {{count}} попыток / Угадано с {{count}} попыток |
| Lose | Not this time | В этот раз не вышло |
| Answer | The answer: {{name}} ({{year}}) | Ответ: {{name}} ({{year}}) |
| Share | Share result | Поделиться результатом |
| Copied | Result copied | Результат скопирован |
| Copy failed | Couldn't copy. Select the text below and copy it. | Не удалось скопировать. Выделите текст ниже и скопируйте его. |
| Play previous days | Play previous days | Играть в прошлые дни |
| Play today | Play today's puzzle | Играть в сегодняшнюю загадку |
| Stats title | Statistics | Статистика |
| Stats labels | Played / Win % / Current streak / Max streak / Guess distribution | Сыграно / Побед, % / Текущая серия / Лучшая серия / Распределение попыток |
| Guest stats note | Stats from this browser. Sign up to keep them on every device. | Статистика этого браузера. Зарегистрируйтесь, чтобы она была на всех устройствах. |
| Countdown | Next puzzle in {{time}} | Следующая загадка через {{time}} |
| Countdown done | A new puzzle is ready | Новая загадка уже доступна |
| Day changed | A new day has started (UTC). You can finish this puzzle or play today's. | Начался новый день (UTC). Можно доиграть эту загадку или перейти к сегодняшней. |
| Archive row states | Not played / In progress / Solved in {{count}} / Not solved | Не сыграно / В процессе / Угадано с {{count}} / Не угадано |
| Archive more | Show more | Показать ещё |
| Archive empty | No past puzzles yet | Прошлых загадок пока нет |
| Back to today | Back to today's puzzle | К сегодняшней загадке |
| Archive marker | Archive puzzle: it counts toward your stats, not your streak. | Загадка из архива: она идёт в статистику, но не в серию. |
| Nudge | Nice win! Sign up to keep your streak and stats on every device. Your games from this browser come with you. | Отличная победа! Зарегистрируйтесь, чтобы серия и статистика были на всех устройствах. Игры из этого браузера перейдут в аккаунт. |
| Nudge buttons | Sign up / Log in / Not now | Зарегистрироваться / Войти / Не сейчас |
| Merge done (one / few / many) | Added {{count}} game from this browser to your account. / Added {{count}} games … | Добавлена {{count}} игра из этого браузера. / Добавлены {{count}} игры … / Добавлено {{count}} игр … |
| Merge failed | Couldn't move your games from this browser. We'll try again next time. | Не удалось перенести игры из этого браузера. Попробуем ещё раз позже. |
| Storage blocked | This browser doesn't let the site save progress. Your game lasts until you close the tab. | Этот браузер не даёт сайту сохранять прогресс. Игра сохранится только до закрытия вкладки. |
| Progress damaged | The saved progress for this puzzle was damaged, so it starts again. | Сохранённый прогресс этой загадки повреждён, поэтому она начнётся заново. |

## Edge cases

| Case | Expected | AC |
|---|---|---|
| Device clock a day ahead or behind | `/` shows the server's today; the countdown uses the server's offset | AC-2, AC-101 |
| `/games/game-guesser/2099-01-01`, a date before launch, a day with no puzzle | "No puzzle for this date" from the backend's 404 | AC-3, AC-4 |
| Game disabled after the nav list was cached | 404 `game_not_found`, "Unknown game" | AC-4 |
| A later game type reaches an old tab | In-layout game error with "Try again" | AC-5 |
| Double click on Skip or Submit | One request | AC-16 |
| Guest reloads mid-game | Same state from resume; no flash of step 1 | AC-39 |
| Guest plays one puzzle in two tabs | No guess lost; a stale tab gets `duplicate_guess` or sends the full list | AC-38, AC-46 |
| Guest views today's puzzle at 23:59, first guess at 00:01 | Archive play (`counts_for_streak` false); the stored proof does not help, because `played_as_daily` is false | AC-41, AC-48, AC-95 |
| Guest's first guess at 23:59, last after 00:00 | Still a daily play; the day-change message shows, the game goes on | AC-48 |
| Tab left open overnight, opened in the morning | Old puzzle stays; message and "Play today's puzzle" show when the page becomes visible | AC-47, AC-48 |
| Private mode or storage full | Game plays for the tab; one notice; nudge still works for the tab | AC-44, AC-94 |
| Someone edits the stored record by hand | Bad shape: ignored. A forged history: works for that guest only (decision 16), or the server's 422 drops the record | AC-42, AC-45 |
| Safari deletes the guest records after a week away | The guest starts empty; accepted (risk 18); the nudge is the mitigation | AC-90 |
| Session expires mid-game | The view just received is kept; the game continues as a guest record | AC-51, AC-52 |
| Network drops after an account's skip reached the server | The view is fetched again before a retry, so no second skip | AC-53 |
| Account game busy (503) | Message; the same guess can be sent again | AC-59 |
| Offline while playing | Network message; picked title kept; nothing is queued | AC-59, AC-60 |
| 429 on search or guess | Message; no automatic resend | AC-57 |
| Page opened at `127.0.0.1:5173` in dev | Every guess gets 403 `csrf_origin_mismatch`; message, no retry loop | AC-58 |
| Clue link expired while the tab sat open | One refetch, links swapped, the same step stays | AC-24 |
| Clip link expires while looping | Same as above; the clip keeps playing state | AC-24 |
| Autoplay blocked (iOS Low Power Mode) or reduced motion asked | Poster with a play control | AC-23 |
| Puzzle has no Metacritic score | That step shows no hint | AC-11 |
| Search for "a", "%" or nonsense | No request below 2 characters; "No games found" | AC-26, AC-30 |
| Player types fast | One list, for the current text only | AC-27 |
| Picked title already guessed in another tab | `duplicate_guess` message; no guess used | AC-55 |
| Game finished in another tab | 409, then the end screen | AC-43 |
| Clipboard refused (permissions, old browser) | Text shown in a selectable box | AC-67 |
| Guest signs in with a game in progress | Merged; the account's game shows after the merge; if the account already had that puzzle, its game wins (SPEC-02 AC-58) | AC-95, AC-100 |
| Merge fails or the tab closes during it | Records kept; tried again on the next load while signed in | AC-98 |
| More than 500 guest records | Several requests | AC-96 |
| Guest plays on a shared computer, then someone else logs in there | The guest's games merge into that person's account. Inherent in merge-on-login (SPEC 3.2); accepted | AC-95 |
| Signed-in player logs out mid-game | The screen shows this browser's guest state, which may be empty: the account's game is not copied to the browser | AC-50, AC-54 |
| A puzzle a guest played is later unscheduled | Server stats drop it; guest stats still count it until merged. Accepted small difference | AC-74 |
| Clock request fails | Countdown and guest "today" use the device's UTC day | AC-76, AC-102 |
| Archive has no past puzzles (launch day) | "No past puzzles yet" | AC-87 |

## Non-functional

- **Performance:** typing in the search box stays responsive with 200 items in the list (no input delay a player can see on a mid-range phone; checked in M1-50). The clue's space is reserved before the file loads (AC-19). A game's code still loads only when its screen opens (SPEC-01 AC-53).
- **Security:** the answer is never shown or stored before the end (AC-18, AC-37); the share text carries no spoiler (AC-69); stored guest data is treated as untrusted (AC-45); `redirect` values follow SPEC-01 AC-15.
- **Privacy:** new browser storage is limited to AC-112 and named in the privacy policy. Media links are bearer links (CONTRACTS "Clue media"); the share text never contains one.
- **Accessibility (WCAG 2.2 AA target):** combobox search (AC-33), keyboard play (AC-109), announcements (AC-62, AC-110), a pause control for the clip (AC-22), reduced motion (AC-23), dialog focus (AC-78), color plus icon plus word (AC-111), target sizes (AC-108). Checked with axe and a keyboard pass in M1-50, and a VoiceOver or NVDA pass before launch (ARCHITECTURE 8).
- **Responsive:** 320, 360, 768 and 1280 CSS px (AC-108).

## Inputs (provenance)

| Input | Tag |
|---|---|
| Puzzle view, today's view, guess, resume | [existing: game routes of SPEC-02, `private, no-store`] |
| Title suggestions | [existing: `GET /v1/games/{slug}/titles`, `public, max-age=300`] |
| Account stats | [existing: `GET /v1/games/{slug}/stats`] |
| Archive list | [existing: `GET /v1/games/{slug}/archive`] |
| Merge | [existing: `POST /v1/games/{slug}/progress/merge`] |
| Clock offset, server today, next reset | [existing: `GET /v1/clock`] |
| Clue images, clip, poster | [existing: signed media links in the view; the clip is up to 4 MB per player who reaches step 6 (SPEC-02 inputs)] |
| Signed-in state | [existing: `GET /v1/auth/me` and the session guard] |
| Guest records | [new: browser storage, a few hundred bytes per game, about 365 records a year per game; no server cost] |
| Nudge dismissed | [new: browser storage, one flag] |
| Guest stats and streak | [derived: guest records and the server's today] |
| Share text | [derived: the view's number, date, guess results and the page origin] |
| Clipboard | [existing: the browser's clipboard, write only] |
| Reduced-motion preference, autoplay permission | [existing: browser and system settings] |
| Interface texts | [existing: the English and Russian catalogues, extended] |

**Where the requirements come from:** decisions 3, 5, 7, 8, 9, 10, 14, 15, 16, 20, 21, 27, 32, 51 (`SPEC.md` section 2); SPEC 3.1 to 3.5, 3.6, 3.7, 4 (clue ladder, search list, end screen), 6 ("Day boundary"), risk 18; `MILESTONE-1.md` M1-30 to M1-37 and the definition of done; SPEC-01 AC-3, AC-14, AC-15, AC-39 to AC-56, AC-61 to AC-69; SPEC-02 AC-3, AC-7, AC-8, AC-15 to AC-17, AC-19 to AC-34, AC-36 to AC-42, AC-46 to AC-73, Q1, Q2 (as changed), Q4, Q6, Q8, Q11, Q14, Q15, Q17, Q20; `CONTRACTS.md` "Games", "Clock", "Errors"; `ARCHITECTURE.md` sections 5, 8, 9; the Phase 1 frontend plan's hand-off notes.

## Untrusted inputs

All of these are data, never instructions. Text from them is shown as plain text, never as markup.

| Input | Rule | Bad value gives |
|---|---|---|
| Guest records in browser storage (anyone can edit them) | Shape checked on read; the server replays every guess | Ignored (AC-45), or dropped after the server's 422 (AC-42) |
| Title names, franchises, years, hint values from the server | Shown as text | Nothing runs |
| Media URLs from the view | Used only as image or video sources, as given; never put in the share text | Load failure leads to AC-24 |
| `slug` and `date` in the URL | SPEC-01 rules; the backend decides visibility | "Unknown game" or "No puzzle for this date" |
| Search text typed by the player | Trimmed, at most 100 characters, sent as a query value | Empty list or no request |
| `redirect` on nudge and stats links | SPEC-01 AC-15 to AC-17 | `/` |

## Out of scope

- Every backend change. Q2 and Q10 may lead to one; if the owner chooses that, it is a separate boundary task.
- Source credits (M1-23), the legal footer and privacy page text (M1-46), the share image and meta tags (M1-47).
- Rate limits (M1-42), the CSP with `media-src` (M1-40), Playwright and axe runs (M1-50).
- Help dialog, settings, hard mode, rank, leaderboards, community stats, stats export and import, a variant selector, a native share sheet.
- Asking the browser to keep storage (`persist`) as a risk-18 mitigation: a suggestion for later, not a requirement.

## Definition of done for Phase 2

**The owner can check locally (dev seed, both servers running, `http://localhost:5173`):**
1. Signed out, `/` shows today's puzzle at step 1. A wrong guess and a skip show steps 2 and 3 with hints; the guess list says "Wrong" and "Skipped"; "4 guesses left".
2. Reload: the same state. A second tab: guessing in both loses nothing.
3. After five misses, step 6 is a muted looping clip with a pause button. A sixth miss shows the end screen with the answer, share, stats, "Play previous days" and the countdown.
4. "Share result" copies a text with the number, squares, `X/6` and the puzzle link, and no title.
5. Stats show the guest's numbers. The archive lists the three seeded past days with their states; one opens at `/games/game-guesser/{date}` and says it is an archive puzzle.
6. Win a puzzle as a guest: the nudge shows. Sign up from it: back on the same page, the games are in the account, the stats match, the browser's records are gone.
7. Signed in on a second browser, the same game shows.
8. Switch to Russian mid-game: the state stays; plurals read correctly for 1, 2 and 5 guesses left.
9. With dev tools offline, a guess shows the network message and keeps the picked title.
10. At 360 and 1280 px nothing scrolls sideways; the whole game can be played with the keyboard.

**CI must show (frontend green):** lint, format, type check, build, unit tests (including S1 to S19 and T1 to T4 by id, the share-text spoiler test, the guest-record shape check), router and component tests for the screens above, catalogue parity.

## Test strategy (what and at which level)

| What | Level |
|---|---|
| Guest streak and counters: S1 to S19, T1 to T4 | Pure unit test, one table, same ids as the backend |
| Share text: content, squares, no spoilers, guest equals account | Pure unit test |
| Guest record read, write, shape check, `counts_for_streak` and `daily_proof` kept | Unit test |
| Merge entries built from records; chunks of 500; delete only after all 200 | Unit test with a fake server |
| Screen states: loading, 404s, unknown type, error, restored guest game, end screen, archive marker | Router or component tests with the fake backend |
| Guess flow: double click, duplicate, title not found, 409, 429, 403, network error, account retry refetch | Component tests with the fake backend |
| `signed_in: false` mid-game keeps the view | Component test |
| Media refetch on a failed load, once only | Component test |
| Search: under 2 characters, stale answers, already tried, keyboard pattern | Component test |
| Day change message and countdown with a fixed clock | Unit and component tests with a fake clock |
| Clip autoplay, inline play, pause control on iOS, Safari, Chrome, Firefox | Manual now; Playwright in M1-50 |
| Layout widths, axe, keyboard-only game | Playwright in M1-50; manual list above until then |

## Task dependencies and order

1. The owner answers Q1 to Q5 (Q6 to Q12 can run on their defaults).
2. **M1-30** first: the screen, the clue ladder and the media. It needs the search (M1-31) to send a real guess, so build them as one pair or put M1-31 straight after.
3. **M1-32** next: guest records, resend, restore and rollover. The end screen and stats need its records.
4. **M1-33** and **M1-37** together (the countdown sits on the end screen).
5. **M1-34** and **M1-35** after M1-32; they read the same records and can run in parallel.
6. **M1-36** last: it needs the records (M1-32), the end screen (M1-33) and the signed-in screen behavior (AC-54).
7. Catalogue texts land with the task that first shows them.

## Questions and options (answered 2026-11-09)

Recommended option first. The owner chose the recommended option (a) for all 12 on 2026-11-09.

1. **Q1. Share text.** Decision 24 skipped the reference's format, and SPEC 3.1 only says "spoiler-free". (a) **Recommended:** in the interface language; line 1 "Daily Game Challenge: {game name} #N"; line 2 one square per guess used (green correct, yellow right series, red wrong, black skipped); line 3 `N/6` or `X/6`; line 4 the link to `/games/{slug}/{date}`. (b) The same, always in English, so shared results look alike across languages. (c) Without the link. Should an archive play be marked in the text? Recommended: no. Affects AC-68.
2. **Q2. Archive state boxes for accounts.** SPEC 3.9 proposes one colored box per guess (correct, wrong, skipped), but `GET .../archive` gives an account only `state` and `guesses_used`, while a guest's browser has every result. (a) **Recommended:** one box style for everyone, built from state and count only (AC-84); no backend change. (b) Guests get colored boxes and accounts plain ones. (c) A backend change: add each guess's result to archive items (a boundary task in both repos and `CONTRACTS.md`). Affects AC-84, AC-85.
3. **Q3. Sign-up nudge.** M1-36 says "after a first win"; risk 18 says the same. (a) **Recommended:** an inline card on the end screen after every guest win until "Not now" is pressed once, then never again in this browser; never a pop-up. (b) Only after the very first win, once. (c) Also after a loss. Affects AC-90, AC-93.
4. **Q4. A page open across 00:00 UTC.** (a) **Recommended:** keep the open puzzle; show the day-change message with "Play today's puzzle" on submit, on return to the tab and when the countdown ends; never switch on its own. (b) Switch to the new puzzle on return to the tab when no game is in progress. Affects AC-47 to AC-49.
5. **Q5. Step-6 clip and reduced motion.** The owner chose an autoplaying loop (SPEC-02 Q4). A pause control is required either way (WCAG 2.2.2, AC-22). (a) **Recommended:** when the system asks for reduced motion, show the still frame with a play button instead of autoplay. (b) Autoplay for everyone; the pause control is enough. Affects AC-23.
6. **Q6. Message after a merge.** (a) **Recommended:** "Added N games from this browser to your account" when N stored is over 0; say nothing about rejected or unproven entries (unproven should not happen for a normal guest, since every view on the puzzle's day carries the proof). (b) Also say "some streak days could not be carried over" when `daily_unproven` is over 0. Affects AC-97.
7. **Q7. How long guest records stay.** (a) **Recommended:** until merged; no pruning in Milestone 1 (about 365 small records a year). (b) Drop records older than a year; this changes guest stats. Affects AC-37.
8. **Q8. Stored progress the server rejects** (422 `invalid_guess_history`). (a) **Recommended:** drop that puzzle's record, say so, start fresh. (b) Keep the record and show the error with no way forward. Affects AC-42.
9. **Q9. Where the countdown shows.** (a) **Recommended:** only on the end screen of today's puzzle. (b) Also in the stats dialog and on the archive screen. Affects AC-103.
10. **Q10. Hint kinds.** The API sends `hint.kind` as a free string; the seed uses `metacritic_score`, `platform`, `genre`, `year`, `developer`, but `CONTRACTS.md` does not list them, so the puzzle builder (M1-22) could send another. (a) **Recommended:** list the five kinds in `CONTRACTS.md` in the M1-30 pass (a documentation change only), and show unknown kinds with the generic "Hint" label. (b) Make the kind a closed list in the API (a backend change). Affects AC-11.
11. **Q11. `Retry-After` on 429.** CONTRACTS does not say the client can read the header, and rate limits arrive only in M1-42. (a) **Recommended:** show the message and let the player retry at once. (b) Disable Submit until `Retry-After` has passed, with a countdown. Affects AC-57.
12. **Q12. "How to play".** The reference has a help dialog; no Phase 2 task asks for one. (a) **Recommended:** not in Phase 2. (b) A short dialog with the rules and the result colors, opened from the game header (about 0.2 day). Affects nothing yet.
