# Spec: Phase 3, content for the game   |   Spec ID: SPEC-04   |   Status: agreed with the owner's answers (2026-11-12)

Covers Milestone 1, Phase 3, tasks M1-20 to M1-25 (`MILESTONE-1.md` section 4), with the Milestone decisions D2 (IGDB) and D5 (who reviews), and definition-of-done item 7 ("at least 30 reviewed puzzles are scheduled ahead, and a script adds more").
It lives in the root `specs/` folder next to SPEC-01 to SPEC-03: most of it is backend scripts, but M1-23 (source credits after a game ends) is shown by the frontend, and Q3 adds a hint kind to the documented seam.
Main inputs: `SPEC.md` (decisions 11, 12, 19, 23, 32, 59, 62, 67; sections 3.7, 4 "Game guesser", 6, 7, 8 risks 1, 3, 4, 5; 3.13 "preview window and buffer"), `MILESTONE-1.md`, `ARCHITECTURE.md` sections 7, 9, 10, 14, `CONTRACTS.md` "Games" (the view, clue media, file limits), SPEC-02 (AC-10 to AC-13b, AC-17, AC-26, AC-70 to AC-74b, AC-82; Q4, Q5, Q9, Q20), SPEC-03 (AC-11, non-goal "source credits"), the Phase 1 backend plan's risks (editing a puzzle that has progress, search speed on real titles), the backend as built (tables `games`, `titles`, `puzzles`, `puzzle_clues`, `clue_media_files`; statuses `draft`, `in_review`, `approved`, `scheduled`; content-hash media keys; local and S3 storage), and two research reports of 2026-11-12 (IGDB API and terms; sources for the step-6 clip). Written 2026-11-12; open questions answered the same day.

## In short

1. A script talks to IGDB with the owner's Twitch developer credentials and reads games: name, year, series, platforms, genres, developer, critic score, screenshots.
2. A second script fills the title list that the guess box searches: thousands of games, clean series names, no near-duplicates, safe to run again.
3. A puzzle builder picks answers by rules (popular enough, enough screenshots, no repeats), makes the six clues offline (a pixelated crop, four screenshots, a short muted looping clip with a still frame), puts the files in private storage under content-hash keys, and writes a draft. Its random choices use a secret salt that is never in the public repos.
4. The owner reviews each draft (all six clues, hints, answer, sources) and approves or rejects it. Approved puzzles are scheduled on free days. At least 30 are scheduled before launch.
5. After a game ends, the player can see where each clue came from. IGDB is credited in a fixed place on the site.
6. A check fails loudly when tomorrow's puzzle is missing or broken, and when fewer than 7 days are scheduled ahead.

## Owner's answers (2026-11-12)

The owner answered all 18 questions on 2026-11-12 and accepted the recommended default for each, so the criteria below stand as written. Full text, options and reasoning are in the last section.

| # | Question | Answer | Criteria affected |
|---|---|---|---|
| Q1 | IGDB terms: may we download screenshots and store changed copies (crop, pixelate, WebP)? | Accepted: ask partner@igdb.com in writing at signup (D2); build and review in `local` meanwhile; no IGDB screenshot reaches another environment until IGDB says yes in writing or the owner accepts the risk in writing | AC-1, AC-2 |
| Q2 | Where does the step-6 clip come from? IGDB has only YouTube ids, and YouTube forbids downloading | Accepted: the builder makes the clip from two or more screenshots not used in steps 1 to 5 (slow pan and cross-fade); no outside video source | AC-36 to AC-38, AC-85 |
| Q3 | IGDB has no Metacritic score, only "external critic scores" | Accepted: new hint kind `critic_score`, labelled "Critic score", shown only with at least 4 critic scores | AC-31, string table |
| Q4 | Which IGDB field is the "series" for the franchise flag? | Accepted: the main `franchise`, falling back to the first series (`collections`) | AC-12 |
| Q5 | A draft must have a date today (the date column is required and unique) | Accepted: the date is optional until a puzzle is scheduled; a scheduled puzzle must have one | AC-46, AC-55 |
| Q6 | How is a draft rejected? There is no `rejected` status | Accepted: delete the draft and record the title as excluded, with the reason "rebuild" or "never" | AC-51 to AC-53 |
| Q7 | Review tool: a CLI or a tiny local page? | Accepted: a tiny local page that runs only in the `local` environment | AC-47 to AC-50 |
| Q8 | Candidate filters and their thresholds | Accepted: main games, remakes, remasters and expanded games; released at least a year ago; at least 7 screenshots of at least 1280 by 720; at least 50 ratings (start values, measured first) | AC-21 to AC-24 |
| Q9 | Repeat rules | Accepted: an answer never repeats in Milestone 1; no two answers of one series within 14 days | AC-25, AC-57 |
| Q10 | Which games go in the search list? | Accepted: main games, remakes, remasters, expanded games and standalone expansions with at least one rating, plus every candidate | AC-10, AC-11 |
| Q11 | Form of the credits after a game | Accepted: a "Sources" section on the end screen, from the view's existing `source_url`; no new page and no new API field | AC-63 to AC-70 |
| Q12 | What `source_url` points at | Accepted: the game's page on igdb.com for every IGDB-derived clue | AC-33, AC-64 |
| Q13 | Where the IGDB attribution lives | Accepted: one line in the site footer, text fixed in this spec, landing with M1-46 before any IGDB content reaches production; plus "Images via IGDB" in the Sources section | AC-65, AC-71 |
| Q14 | Where the scripts run and how they reach production | Accepted: the owner's workstation, with the target environment named on every writing run; the check runs on the server once M1-52 sets it up | AC-44, AC-78 |
| Q15 | The alert check's exit codes and what it checks | Accepted: exit 2 when tomorrow is missing or broken (page), 1 when the buffer is under 7 days (digest), another non-zero code when the check cannot run, 0 otherwise; "ready" includes the files being in storage | AC-73 to AC-82 |
| Q16 | Step-1 crop: which screenshot? | Accepted: one not used in steps 2 to 5 | AC-34 |
| Q17 | Launch date and the first scheduled day | Accepted: the owner sets the game's production launch date before Phase 5; scheduling fills from the later of tomorrow and the launch date; the check says "not launched" until 7 days before it | AC-56, AC-61, AC-82 |
| Q18 | Screenshots that show the game's name or logo | Accepted: caught by the reviewer only; no text recognition or AI in Milestone 1 | AC-48 |

## Problem & Motivation

- Phase 1 built a backend that serves puzzles, and Phase 2 a browser game that plays them. The only puzzles are a handful of placeholders from the dev seed. Content, not code, is now the slowest part of the Milestone (`MILESTONE-1.md` section 5, SPEC risk 3).
- The guess box searches a title list that holds 12 seed titles. A real game needs thousands, with clean series names for the franchise flag (SPEC 4 "search list": the reference's list has near-duplicates).
- Each puzzle needs six clue files that meet the limits of SPEC-02 AC-74b, hints stored on the puzzle, and a source for each clue (SPEC 3.7). Making them by hand every day is not possible for one person.
- Both repos are public (decision 59). A generator whose choices come only from public code and public data would let anyone compute future answers, so the choices need a secret salt, and no puzzle data may be committed (ARCHITECTURE 10).
- The game guesser needs a human review before a puzzle goes live (SPEC 7 step 4, D5): answers must be recognisable, the first clue readable, no clue may show the game's name. SPEC risk 4 (fairness) is the main complaint on comparable sites.
- A day with no scheduled puzzle shows "No puzzle for this date" to every player (SPEC-02 edge case). Nothing warns the owner yet. ARCHITECTURE 9 names "tomorrow's puzzle exists by 22:00 UTC" as the most valuable alert.
- The screenshots belong to others (SPEC risk 1, the highest). Source credits and a visible attribution are part of the mitigation, and IGDB itself asks for user-facing attribution.

## Goals / Non-goals

**Goals**
- An IGDB client that the scripts share, with the owner's credentials kept out of the repos and IGDB's rate limit respected (M1-20).
- A repeatable title import that fills the search list with clean, de-duplicated titles and keeps titles that puzzles or games already reference (M1-21).
- A puzzle builder with candidate filters, offline media processing, content-hash private storage, a secret salt, `--dry-run` and safe re-runs (M1-22).
- A source for every clue, credits shown after a game ends, and IGDB attribution in a fixed place (M1-23).
- A review step for the owner and a scheduling step, ending with 30 or more approved puzzles scheduled ahead (M1-24, definition of done item 7).
- A check that fails when tomorrow's puzzle is missing or broken, or the buffer is under 7 days (M1-25).

**Non-goals**
- Any change to how a puzzle is played, checked or shown, beyond the credits (M1-23) and the hint label of Q3.
- An admin UI in the app, roles, previewing upcoming puzzles in the game screen (SPEC 3.13; decision 11 stays: no admin UI).
- Wiring the alert to a notifier or a schedule on the server (M1-52, Phase 5). This spec defines the check and its result; M1-52 runs it and sends the alert.
- Replacing a puzzle that is already visible (today's or a past one), and the "bad puzzle today" runbook (M1-52; SPEC 3.13 "puzzle.withdraw" is a later tool).
- AI help for any step (decision 19: only when a script cannot solve a data problem; Q18).
- Cleaning up stored files that no puzzle uses any more. They stay in private storage; a clean-up comes later.
- Content for other games (word game, movie game). The client and builder serve the game guesser only, though nothing should block reuse.
- The full legal pages (M1-46). This spec fixes only the IGDB attribution text and where the credits appear.
- Monetization of any kind (decision 12). If that changes, the IGDB terms must be checked again (Q1).

## User stories

| ID | As a ... | I want ... | Covered by |
|---|---|---|---|
| US-1 | owner | the scripts to read IGDB with my credentials, without leaking them or getting blocked | AC-1 to AC-9 |
| US-2 | player | to find any well-known game in the guess box, once, with its year and a clean series name | AC-10 to AC-20 |
| US-3 | owner | drafts built for me from fair candidates, with all six clues ready to review | AC-21 to AC-35, AC-41 to AC-46 |
| US-4 | player at step 6 | a short silent clip that adds something the stills did not show | AC-36 to AC-40 |
| US-5 | owner | future answers that nobody can compute from the public code | AC-26 to AC-28 |
| US-6 | owner (reviewer) | to see each draft as the player will, and approve, reject or rebuild it in a few minutes a day | AC-47 to AC-54 |
| US-7 | owner | approved puzzles placed on free days by the rules, at least 30 ahead before launch | AC-55 to AC-62 |
| US-8 | player who finished a puzzle | to see where each clue came from | AC-63 to AC-70 |
| US-9 | rights holder | a visible credit and a way to find the source of an image | AC-33, AC-66, AC-71, AC-72 |
| US-10 | owner | to be told before midnight when tomorrow has no puzzle, or the buffer is running low | AC-73 to AC-82 |
| US-11 | developer | puzzle data and raw screenshots never in Git, and scripts that cannot write to production by accident | AC-5, AC-27, AC-44, AC-83 to AC-86 |

## Acceptance criteria (EARS)

Each group names its source. "IGDB record" means data as IGDB returns it. "Candidate" is a game that may become an answer. "Draft" is a puzzle the builder made and nobody has approved yet. "Today" and "tomorrow" are UTC days from the project clock (decision 10). "Target environment" is the database and media storage a run writes to. "Buffer" is defined in AC-75.

### M1-20 IGDB access and the client (D2; SPEC 7 step 1; research 2026-11-12)

- **AC-1** At signup (D2), the owner shall check the IGDB terms, ask partner@igdb.com in writing whether a free, ad-free site may store and serve cropped, pixelated, re-encoded screenshots with attribution, and record the outcome as a decision in `SPEC.md` section 2 (Q1). The terms do not settle it: the Twitch Developer Services Agreement limits storing copies to 24 hours unless authorised, while IGDB's FAQ says storing is preferred.
- **AC-2** WHILE IGDB has not said yes in writing and the owner has not accepted the risk in writing, no IGDB screenshot shall be stored in any environment other than `local`; building and review go on in `local` (Q1). IF IGDB says no and the owner does not accept the risk, THEN the fallback of `MILESTONE-1.md` section 6 applies (a hand-built list with screenshots the owner provides).
- **AC-3** The client shall read the Twitch client id and secret from the environment of the run. They shall never be committed, printed, logged or written into any stored record. IF either is missing, THEN the client shall stop before any request with a message that names the missing setting.
- **AC-4** The client shall get and renew its access token by itself; WHEN a request is refused because the token expired, it shall renew the token once and repeat the request.
- **AC-5** The client shall stay within IGDB's limits (4 requests a second, 8 open at a time). IF IGDB answers 429 or a 5xx, THEN the client shall wait and retry a bounded number of times, then stop the run with a message; it shall not loop forever.
- **AC-6** The client shall read whole lists by paging (at most 500 records a request), so a run of thousands of games completes without a data dump.
- **AC-7** The client shall give the scripts, per game: the IGDB id, name, release year, game type, the game it is a version of (if any), main franchise, series, platforms of the first release, genres, developers, critic score and the number of critic scores, the number of ratings, and screenshots with their ids, widths and heights.
- **AC-8** The client shall validate every IGDB record at the boundary: a record of the wrong shape, a name with no letters or digits, a year outside 1950 to next year, or a screenshot with no id or size shall be skipped and counted, never stored and never a crash.
- **AC-9** WHEN run with a list command, the client shall print five games with every field of AC-7 (the M1-20 "done when"). *Verify: run against IGDB with the owner's credentials; five games, each field present or shown as missing.*

### M1-21 Title list import (SPEC 4 "search list"; SPEC-02 AC-18 to AC-24, Q9, Q15; Phase 1 plan risks)

- **AC-10** The import shall fill the game guesser's title list with the games of AC-11 from IGDB. These are main games, remakes, remasters, expanded games and standalone expansions with at least one rating, plus every candidate answer (Q10).
- **AC-11** The import shall leave out DLCs, add-ons, bundles, packs, mods, episodes, seasons, updates, forks, ports and editions of another game (a record that is a version of another game). The list shall always include every title that is or may become an answer (AC-21).
- **AC-12** Each title's franchise shall be one clean series name. It shall be IGDB's main franchise, else the game's first series (IGDB keeps "franchise" and "series" apart; Q4). Names shall be trimmed, have no trailing qualifiers such as "(series)", and be spelled the same for every game of one series, so the franchise flag (SPEC-02 AC-28) fires for every game of a series. A short override list, kept with the code and holding no answers, may correct known bad names.
- **AC-13** The import shall show the year of first release (SPEC-02 Q15). A game with no release date shall have no year.
- **AC-14** WHEN two IGDB games would give titles with the same normalized name and the same year, the import shall keep one (the one with more ratings) and drop the other. Titles with the same name and different years (a remake) shall both stay; a guess of either is correct by name (SPEC-02 Q9). *Verify: a fixture with "Doom" (1993) twice and "Doom" (2016) gives two titles.*
- **AC-15** Each title shall remember the IGDB id it came from, so a later run updates that title instead of adding another.
- **AC-16** The import shall be safe to run again: a second run with the same IGDB data shall change nothing. *Verify: run twice; same row count and same rows.*
- **AC-17** The import shall never delete a title that a puzzle answer or a stored guess references (SPEC-02 AC-11). A title that disappears from IGDB shall stay.
- **AC-18** IF an update would rename a title, or change its franchise or kind, in a way that breaks the replay of a stored game (two stored guesses of one game would then share a normalized name, or a wrong stored guess would then match its answer), THEN the import shall leave that title unchanged and report it (Phase 1 plan risk, "editing a puzzle that already has progress").
- **AC-19** WHEN the import ends, it shall print the number of titles added, updated, unchanged, kept as near-duplicates, refused by AC-18 and skipped by AC-8.
- **AC-20** With the real imported list, the title search shall meet SPEC-02's latency target (p95 under 150 ms locally); "the" and "zlda" shall be among the measured queries. IF it does not, THEN the owner chooses one of the fallbacks of the Phase 1 plan (a 3-character minimum, or ignoring stop words) before launch. *Verify: the existing search benchmark against the imported list.*

### M1-22 Candidates and filters (SPEC 7 step 2; SPEC risk 4)

- **AC-21** A game shall be a candidate only WHEN it is a main game, remake, remaster or expanded game, not a version of another game, released at least one year before the run, with enough screenshots for AC-34 and AC-36, and enough ratings to count as "popular enough". The start values are at least 7 screenshots of at least 1280 by 720 pixels and at least 50 ratings; the owner measures how many games pass (AC-24) before fixing them (Q8).
- **AC-22** The thresholds of AC-21 shall be settings of the builder with the defaults written in this spec, so the owner can change them without a code change.
- **AC-23** A title the reviewer has excluded (AC-52) shall never be a candidate again.
- **AC-24** WHEN asked, the builder shall print how many games pass each filter, in order, so the owner can tune the thresholds. *Verify: the counts add up from the full list to the final candidates.*
- **AC-25** A candidate shall not be an earlier answer of the game, in any status (draft, in review, approved, scheduled). An answer never repeats in Milestone 1; the series rule is checked when scheduling (AC-57; Q9).

### M1-22 Secret seed salt (decision 59; ARCHITECTURE 10; Milestone risk "answer leaks")

- **AC-26** Every random choice of the builder (which candidate, which screenshots, which step each goes to, where the step-1 crop sits, which part makes the clip) shall come from a seed made from the game, variant, the build's slot, the generator version and a secret salt. Choices shall not depend on global randomness or the wall clock.
- **AC-27** The salt shall come from the environment of the run. It shall never be committed, printed or logged, shall differ from every other secret of the project, and shall be long enough to resist guessing (the same strength rule as `SECRET_KEY`). IF it is missing or weak, THEN the builder shall stop before reading IGDB, except in tests, which use a fixed test salt.
- **AC-28** With the same inputs, salt and generator version, the builder shall make the same choices. Without the salt, the public code and IGDB data shall not be enough to predict them. *Verify: two runs with one salt give identical drafts; a run with another salt gives different choices.*

### M1-22 Clues and media (SPEC 4 "clue ladder"; SPEC-02 AC-13, AC-13b, AC-74, AC-74b, Q4, Q20; ARCHITECTURE 10)

- **AC-29** Each draft shall have exactly six clues: steps 1 to 5 `image`, step 6 `video`, as SPEC-02 AC-13 and AC-13b require.
- **AC-30** The hints shall be: step 1 none; step 2 the critic score; step 3 the platform of first release; step 4 the genre; step 5 the release year; step 6 the developer. A hint whose data is missing shall be left out (`null`), never invented. Values are English (decision 32), at most 255 characters, several platforms, genres or developers joined by ", " with at most three.
- **AC-31** The step-2 hint shall have the kind `critic_score` and be IGDB's critic score, rounded to a whole number, shown only when it rests on at least 4 critic scores; otherwise it is `null` (Q3). IGDB does not provide Metacritic, so the builder shall never write the kind `metacritic_score`. The frontend labels `critic_score` "Critic score".
- **AC-32** Hints shall be stored on the puzzle when it is built (SPEC-02 AC-13), so a later title or IGDB change cannot alter a puzzle.
- **AC-33** Every clue shall have a `source_url`: the game's page on igdb.com for every clue derived from IGDB screenshots, the clip included, which gives the "clear path to the source" the Twitch agreement asks for (Q12). The builder shall also keep, for its own records, the IGDB id of each screenshot it used.
- **AC-34** Step 1 shall be a small pixelated crop of a screenshot, made offline, so the picture is hard but not impossible to read. The crop shall come from a screenshot not used in steps 2 to 5 (Q16). Steps 2 to 5 shall be four different full screenshots.
- **AC-35** Every image and poster shall be WebP, at most 1920 by 1080 pixels and 1 MB, with all metadata (EXIF and the like) removed (SPEC-02 AC-74b; ARCHITECTURE 10).
- **AC-36** Step 6 shall be a muted looping clip of 8 to 15 seconds (about 12), H.264 MP4, no audio track, at most 1280 by 720 pixels and 4 MB, with an optional WebM copy and one WebP poster frame (SPEC-02 Q4, Q20, AC-74b). The builder shall make the clip from screenshots not used in steps 1 to 5 where the game has enough, else from the step 2 to 5 screenshots (AC-37, decision 74) (a slow pan and cross-fade), so no new source is needed (Q2; IGDB has only YouTube ids, and YouTube's terms forbid downloading).
- **AC-37** (amended by decision 74, 2026-11-20) When the game has at least two eligible screenshots beyond the five used in steps 1 to 5, the clip shall show two or three of them, so step 6 adds information. When it has fewer, the clip shall be made from the step 2 to 5 screenshots instead. A game needs at least five eligible screenshots, not seven.
- **AC-38** The clip shall never be taken from an outside video (YouTube, Steam trailers or any other source) in Milestone 1 (Q2). Using one later needs a new owner decision on its terms.
- **AC-39** The builder shall refuse to store any clue file that breaks the limits of SPEC-02 AC-74b, and the content type, size, width, height and duration it stores shall be measured from the file it checked (SPEC-02 AC-74b).
- **AC-40** The poster shall be a frame of the clip itself.

### M1-22 Storage, drafts and re-runs (SPEC 7 step 3; SPEC-02 AC-74; ARCHITECTURE 10; decision 62)

- **AC-41** Every stored file shall be keyed by the SHA-256 of its content (SPEC-02 AC-74), never by date, game, step or answer. Storing a file that is already there shall not create a second object.
- **AC-42** Files shall go to the target environment's private storage (the local folder, or the S3-compatible bucket), never to a public place, and never into Git.
- **AC-43** Raw IGDB screenshots and intermediate files shall stay in a working folder outside both repos, or in one ignored by Git. No screenshot, clip, answer list or draft shall be committed (decision 59). Test fixtures shall be images made by us.
- **AC-44** WHEN the builder writes, the run shall name its target environment, and it shall print that name before writing. WHERE the target is not `local`, the run shall ask for confirmation, or require an explicit flag, before the first write. The writing scripts run on the owner's workstation (Q14).
- **AC-45** WHERE the run uses `--dry-run`, the builder shall do every step up to writing (read IGDB, filter, choose, process media in the working folder, check limits) and shall write nothing to the database or storage. It shall print what it would create, by slot, with no answer names unless asked to show them.
- **AC-46** The builder shall write each draft with all six clues, their files and their media records in one step: either the whole draft exists or none of it. Re-running a build for the same slot shall not create a second draft. A puzzle's date shall be optional while it is a draft, in review or approved, and required once it is scheduled; a "slot" is a build number, not a date (Q5). The date stays unique per game and variant where it is set.

### M1-24 Review (D5; SPEC 7 step 4; SPEC-02 Q5)

- **AC-47** The review tool shall show each draft in review as the player will see it: the six clues in order at their real size, the clip playing muted and looping, each hint with its label, then the answer (name, year, franchise) and each clue's source link. The tool shall be a tiny local page that runs only in the `local` environment and refuses to start in any other (Q7).
- **AC-48** The review tool shall show the reviewer a short checklist for each draft: the answer is a recognisable game; step 1 is readable but hard; no clue shows the game's name, logo or a character name on screen; hints are correct; the clip plays and adds something. The reviewer is the only check for on-screen text in Milestone 1 (Q18).
- **AC-49** WHEN the reviewer approves a draft, the system shall move it to `approved`. Only a puzzle in review can be approved.
- **AC-50** The builder shall put a complete draft straight into `in_review`. A build that failed part way leaves nothing (AC-46), and a rejected draft is deleted (AC-51), so the Phase 3 tools never write `draft`. A rebuild is driven by the exclusion row with the reason "rebuild" (owner's answer of 2026-11-12, decision 69).
- **AC-51** WHEN the reviewer rejects a draft, the system shall delete the draft and record an exclusion for its title with the reason "rebuild" (the answer is fine, the clues are not) or "never" (the answer is unsuitable). There is no `rejected` status (Q6).
- **AC-52** WHEN a draft is rejected as "never", its title shall be excluded from candidates for good (AC-23). WHEN it is rejected as "rebuild", the next build for that answer shall choose other screenshots and another crop.
- **AC-53** A rejected draft shall leave nothing a player can reach: no puzzle row in a visible state and no media record. Its files may stay in private storage (non-goal: clean-up).
- **AC-54** Review shall be quick enough for the D5 budget: one draft fits on one screen at 1280 by 800, and approve or reject is one action plus the reason. *Verify: the owner reviews 10 drafts in about 10 minutes.*

### M1-24 Scheduling (SPEC 3.13 "preview window and buffer"; ARCHITECTURE 9; SPEC-02 AC-12, AC-17; definition of done item 7)

- **AC-55** WHEN the owner runs scheduling, the system shall give approved puzzles the free dates from the first schedulable day (AC-56) onwards, in the order they were approved, and set them to `scheduled`. A date that already has a puzzle of that game and variant shall not get a second one.
- **AC-56** The first schedulable day shall be the later of tomorrow and the game's launch date. Today and past dates shall never be scheduled by the tool. The owner sets the production launch date before Phase 5 (Q17).
- **AC-57** Scheduling shall not put two answers of the same series within 14 days of each other; a puzzle that would break this waits for a later date, and another approved one takes the day. (Q9)
- **AC-58** Before scheduling a puzzle, the system shall check it is complete: six clues, the media rules of SPEC-02 AC-13b, and every file present in the target storage. IF it is not, THEN it shall stay `approved` and be reported.
- **AC-59** The owner shall be able to move a scheduled puzzle whose date is after today back to `approved`, which frees its date. A scheduled puzzle dated today or earlier shall not be moved, changed or deleted by the tools (it is visible, and may have stored games; SPEC-02 edge case "unscheduled later" and the Phase 1 plan risk).
- **AC-60** WHEN scheduling ends, the system shall print the scheduled dates (with answers only when asked) and the buffer of AC-75.
- **AC-61** Before launch, at least 30 approved puzzles shall be scheduled on consecutive days from the launch date (definition of done item 7; M1-24 "done when").
- **AC-62** A puzzle shall become visible only by the existing rule (scheduled, date today or earlier, on or after launch, game enabled; SPEC-02 AC-12). No script shall change the visibility rule, and nothing runs at 00:00.

### M1-23 Source credits after a game (SPEC 3.7 "source credit per puzzle"; SPEC-02 AC-26; SPEC-03 non-goal)

- **AC-63** WHEN a game ends (won or lost), today's or an archive puzzle, the end screen shall offer the clue sources. The sources shall be a "Sources" section on the end screen that the player opens, built from the view's existing `source_url`, with no new page and no new API field (Q11).
- **AC-64** The Sources section shall list the six steps in order. For each: the step number, the clue as the player saw it (image, or the clip's poster), and a link to its `source_url` whose text is the link's host name (for example "igdb.com").
- **AC-65** The section shall say "Images via IGDB" when every source is igdb.com, and shall link to igdb.com.
- **AC-66** Each source link shall open in a new tab, shall not pass the page as referrer, and shall carry no signed media link or anything about the player.
- **AC-67** The Sources section shall never be shown, and no source link shall exist on the page, before the game ends. The backend already sends `source_url` only at the end (SPEC-02 AC-26).
- **AC-68** IF a step's `source_url` is `null`, THEN that row shall say "Source not recorded" instead of a link. (AC-33 makes this a data fault, but the screen must not break.)
- **AC-69** The Sources section shall work by keyboard and screen reader: it is opened by a button with an accessible name, each thumbnail has the text "Clue N" (never the game's name before the player has seen the answer; on the end screen the answer is already shown), and links say where they go.
- **AC-70** The new texts shall be in English and Russian (string table below).
- **AC-71** The site shall carry the IGDB attribution in a fixed place that every visitor can reach: one line in the site footer, "Game data and images: IGDB.com", linked to igdb.com. The text is fixed here and lands with the footer in M1-46, before any IGDB content reaches production (Q13).
- **AC-72** The privacy or legal page (M1-46) shall name IGDB as the source of game data and images, with the rights notice of SPEC 3.7.

### M1-25 Buffer and tomorrow alert (ARCHITECTURE 9 "tomorrow's puzzle exists by 22:00 UTC", "alert when the scheduled buffer drops below 7 days"; SPEC 3.13)

- **AC-73** A check command shall look at every enabled game's default variant in the target environment and report two things: whether tomorrow's puzzle is ready (AC-74), and the buffer (AC-75).
- **AC-74** Tomorrow's puzzle is ready WHEN it exists, is `scheduled`, is on or after the launch date, has six clues that meet SPEC-02 AC-13b, and every file it names exists in storage. *Verify: a fixture with tomorrow's step-6 file missing from storage is "not ready".*
- **AC-75** The buffer shall be the number of consecutive days, starting tomorrow, that have a ready puzzle. A gap ends the count: puzzles after a gap do not count.
- **AC-76** IF tomorrow's puzzle is not ready for any enabled game, THEN the check shall exit with code 2. (Q15)
- **AC-77** IF tomorrow's puzzle is ready but the buffer is under 7 days, THEN the check shall exit with code 1. With both fine, it shall exit 0.
- **AC-78** The check shall only read: it shall never change a puzzle, a file or a status, and may run against production. It runs on the server once M1-52 sets it up; the schedule (by 22:00 UTC daily) and the notifier are M1-52 (Q14).
- **AC-79** The check's output shall name the game, the dates and what is wrong (missing, wrong status, missing clue, missing file) and the buffer in days. It shall never print an answer, a title, a hint or a media key, because its output goes to alert channels.
- **AC-80** WHEN the check cannot reach the database or storage, it shall exit with a code other than 0, 1 and 2, so the alert fires for "unknown" and not "fine".
- **AC-81** The check shall take its "today" from the project clock, and tests shall inject the clock. *Verify: at 23:59:59 UTC tomorrow is the next day; at 00:00:00 it moves.*
- **AC-82** WHEN the launch date is in the future, the check shall start counting from the launch date and report "not launched" without failing, until 7 days before launch (Q17).

### Cross-cutting: secrets, data and safety (decision 59; ARCHITECTURE 9, 10, 14)

- **AC-83** No script shall commit, print or log credentials, the salt, signed links or storage keys. Answers may be printed only in the reviewer's local session and only when asked (AC-45, AC-60).
- **AC-84** Scripts that write shall refuse to run in CI.
- **AC-85** Every fetch-by-URL in the scripts shall go only to hosts on an allow list (IGDB's API, its token service and its image host; Q2 adds no clip source) (ARCHITECTURE 14).
- **AC-86** The builder, review and scheduling steps shall never edit a puzzle that has stored games (Phase 1 plan risk): its answer, its clues and its date stay as they are.

### Interface strings (English and Russian)

Proposed texts; the Russian column needs the D6 check.

| Where | English | Russian |
|---|---|---|
| Sources button | Sources | Источники |
| Sources heading | Where these clues come from | Откуда эти подсказки |
| Step row | Clue {{n}} | Подсказка {{n}} |
| Via IGDB | Images via IGDB | Изображения: IGDB |
| No source | Source not recorded | Источник не указан |
| Footer attribution (M1-46) | Game data and images: IGDB.com | Данные об играх и изображения: IGDB.com |
| Hint label `critic_score` (Q3) | Critic score | Оценка критиков |

## Edge cases

| Case | Expected | AC |
|---|---|---|
| IGDB credentials missing or wrong | Stop before any request, naming the setting | AC-3 |
| Token expires in a long import | Renewed once, run goes on | AC-4 |
| IGDB answers 429 or 503 for a while | Bounded retries, then the run stops with a message; a re-run continues safely | AC-5, AC-16 |
| IGDB record with no name, a strange year, or a screenshot with no size | Skipped and counted | AC-8 |
| IGDB data contains HTML or a prompt-like text in a name | Stored and shown as plain text only | Untrusted inputs |
| Same game twice in IGDB (same name and year) | One title kept | AC-14 |
| Remake with the original's name | Both titles, years differ; either guess is correct (Q9) | AC-14 |
| A title that games reference is renamed in IGDB in a way that breaks replay | Left unchanged, reported | AC-18 |
| A title disappears from IGDB | Stays | AC-17 |
| A game in two franchises, or a series with no franchise | Main franchise, else the first series (Q4) | AC-12 |
| Candidate with 6 screenshots when 7 are needed | Not a candidate | AC-21 |
| Few critic scores | No step-2 hint | AC-31 |
| No developer, genre or platform in IGDB | That hint is `null` | AC-30 |
| A screenshot shows the title or logo | The reviewer rejects with "rebuild" | AC-48, AC-52 |
| A processed image over 1 MB, or a clip over 4 MB | Re-encoded within limits, or refused and the draft not written | AC-39, AC-46 |
| Builder killed half way | No partial draft; re-run builds it | AC-46 |
| Builder run twice for the same slot | One draft | AC-46 |
| Salt missing or equal to another secret | Builder stops before reading IGDB | AC-27 |
| Someone runs the public code with IGDB data and no salt | Cannot reproduce our choices | AC-28 |
| Reviewer rejects an answer as unsuitable | Title excluded for good | AC-52 |
| Approved puzzle's file missing in production storage | Stays `approved`, reported | AC-58 |
| Two approved answers of one series | The second waits 14 days | AC-57 |
| Owner tries to unschedule today's puzzle | Refused | AC-59 |
| Tomorrow's step-6 file was deleted from the bucket | Check exits 2 | AC-74, AC-76 |
| Puzzles for days 1 to 5 and 7 to 30 | Buffer 5, exit 1 | AC-75, AC-77 |
| Database down at check time | Exit code for "unknown" | AC-80 |
| Before launch, nothing scheduled yet | "Not launched", no failure until 7 days before launch | AC-82 |
| Builder pointed at production by mistake | Target printed; confirmation needed | AC-44 |
| A step's `source_url` is null after the game | "Source not recorded" | AC-68 |
| A guest opens an archive puzzle they finished long ago | Sources shown with fresh media links from the view | AC-63, AC-64 |
| Sources section opened while the game is in progress | Not possible; nothing on the page | AC-67 |

## Non-functional

- **Rate limits:** the client never exceeds 4 requests a second or 8 open requests (AC-5).
- **Run time:** a full title import of the AC-10 scope finishes in under an hour on the owner's machine (an estimate; IGDB's paging at 500 records and 4 requests a second allows about 2,000 records a second at best).
- **Search latency:** p95 under 150 ms locally with the real list (AC-20).
- **Security and secrecy:** credentials and the salt come from the environment only (AC-3, AC-27); no puzzle data or raw media in Git (AC-43); storage stays private with content-hash keys (AC-41, AC-42); the alert never prints answers (AC-79); scripts write only to a named target (AC-44).
- **Privacy:** the scripts handle no personal data. The source links send no referrer and nothing about the player (AC-66).
- **Accessibility:** the Sources section meets the same WCAG 2.2 AA target as SPEC-03 (AC-69).
- **Cost:** storage grows by about 5 images of at most 1 MB and a clip of at most 4 MB per puzzle (SPEC-02 inputs); the IGDB API is free under its terms (Q1).

## Inputs (provenance)

| Input | Tag |
|---|---|
| IGDB games, franchises, series, platforms, genres, companies, ratings, screenshots | [new: IGDB API v4, free under its terms (Q1); needs a Twitch developer account with two-factor auth (D2); 4 requests a second] |
| Twitch client id and secret | [new: owner's secrets in the run's environment] |
| IGDB screenshot files | [new: downloaded from IGDB's image host during builds; kept outside the repos; copyrighted by the games' owners (SPEC risk 1)] |
| Step-6 clip source | [derived: screenshots already fetched, not used in steps 1 to 5 (Q2)] |
| Secret seed salt | [new: one secret per environment that builds; never in Git] |
| Title list | [existing: the `titles` table; filled by M1-21] |
| Earlier answers, statuses, dates | [existing: the `puzzles` table] |
| Exclusions with reasons | [new: a record per rejected title (Q6)] |
| Clue files and their records | [existing: private storage and `clue_media_files`, filled by M1-22] |
| `source_url` per clue | [existing: `puzzle_clues.source_url`, filled by M1-22; sent in the view at the end] |
| Launch date | [existing: `games.launch_date`; production value to be set (Q17)] |
| Today, tomorrow | [derived: project clock, UTC] |
| Buffer | [derived: scheduled puzzles and storage] |
| Interface texts for credits | [existing: frontend catalogues, extended] |

**Where the requirements come from:** decisions 11, 12, 19, 23, 32, 59, 62, 67 (`SPEC.md` section 2); SPEC 3.7, 3.13 ("preview window and buffer"), 4, 6, 7, 8 (risks 1, 3, 4, 5); `MILESTONE-1.md` D2, D5, M1-20 to M1-25, definition of done item 7, section 6; `ARCHITECTURE.md` sections 7, 9, 10, 14; `CONTRACTS.md` "Games" (the view, clue media, file limits); SPEC-02 AC-11 to AC-13b, AC-17, AC-18 to AC-24, AC-26, AC-28, AC-74, AC-74b, Q4, Q5, Q9, Q15, Q20; SPEC-03 AC-11 and its non-goal on credits; the Phase 1 backend plan's risks; the research of 2026-11-12.

## Untrusted inputs

All of these are data, never instructions. They are validated at the boundary and shown only as plain text.

| Input | Rule | Bad value gives |
|---|---|---|
| IGDB API responses (names, franchises, series, genres, companies, URLs) | Shape and value checks (AC-8); text stored and shown as plain text, never as markup; never put into a shell command or SQL string | Record skipped and counted |
| Image and video files from outside | Decoded, re-encoded and checked against the limits (AC-35, AC-39); never stored as received | File refused, draft not written |
| URLs inside IGDB data | Fetched only from allow-listed hosts (AC-85); `source_url` built by us, not copied from free text | No fetch; error |
| Override list for franchise names | Kept with the code, reviewed in pull requests | n/a |
| Reviewer's input in the review tool | Only the actions approve, reject (with one of two reasons) and rebuild | Refused |
| `source_url` in the view (frontend) | Shown only as a link with `http` or `https`; host name shown as text | Row shows "Source not recorded" |

## Changes at the FE/BE boundary

- **API shape:** no change. `source_url` already reaches the browser at the end of a game (Q11).
- **`CONTRACTS.md` "Games", "The view":** one sentence saying `source_url` is the game's page on igdb.com (Q12), and the hint kinds list gains `critic_score` (Q3), in the same pass as M1-22, with the frontend label "Critic score" in both catalogues.
- **Backend schema only (Q5):** a puzzle's date becomes optional until it is scheduled; no route or response changes, because unscheduled puzzles are never visible.
- `CONTRACTS.md` "Clue media", "Limits for the files of a clue" changes only if M1-22 changes the AC-74b limits.

## Out of scope

- Playing, checking or showing puzzles (Phases 1 and 2), apart from the credits and the hint label.
- The alert's schedule and notifier, runbooks, backups (M1-52). The legal pages (M1-46), apart from the attribution text.
- An admin UI or roles (SPEC 3.13), previewing upcoming puzzles in the game.
- Replacing a visible puzzle; a pool of spares for that runbook (approved puzzles serve as the pool, AC-59).
- Text recognition or AI checks on screenshots (Q18).
- Clean-up of unused stored files.
- Other games' content.

## Definition of done for Phase 3

**The owner can check locally:**
1. The client lists five games with all fields (AC-9).
2. The title import runs twice; the second run changes nothing; "zlda" finds Zelda games with years; series names are clean; the search benchmark meets the target.
3. `--dry-run` of the builder prints planned drafts and writes nothing; a real run writes complete drafts in review; a second run adds nothing.
4. The review tool shows a draft with six clues, the clip, hints, answer and sources; approve, reject "rebuild" and reject "never" each do what AC-49 to AC-52 say.
5. Scheduling places approved puzzles from the first schedulable day with no series within 14 days; at least 30 are scheduled (in production before launch).
6. Playing a scheduled puzzle to the end shows the Sources section with six rows and links to igdb.com.
7. The check exits 0 with 30 days scheduled, 1 with 5, 2 with tomorrow's file removed, and prints no answers.

**CI must show:** backend lint, format, tests (client paging, retries and validation against recorded fixtures with no network; import idempotence, near-duplicates, AC-17 and AC-18; filters; seed determinism with a test salt; media limits on generated files; atomic draft writes; review and scheduling rules; the check's codes with an injected clock), migrations job if the schema changes; frontend tests for the Sources section and catalogue parity.

## Test strategy (what and at which level)

| What | Level |
|---|---|
| IGDB client paging, rate limit, retries, token renewal, validation | Unit tests with recorded fixtures; no network in CI |
| Title import: mapping, franchise cleaning, near-duplicates, idempotence, protected titles | Database tests with fixtures |
| Candidate filters and counts | Unit tests over fixture games |
| Seed: same salt same choices, other salt other choices, no salt refused | Unit tests |
| Media: crop, WebP limits, metadata removed, clip length, size, no audio, poster | Unit tests on small generated images |
| Draft written whole or not at all; re-run adds nothing; dry run writes nothing | Database and storage tests |
| Review and scheduling rules (status moves, exclusion, 14-day series rule, today locked, completeness) | Database tests |
| Alert check: ready, missing, broken, gaps, before launch, codes, no answers in output | Database tests with an injected clock |
| Sources section: shown only at the end, rows, null source, link attributes, keyboard | Frontend component tests |
| Real IGDB run, review of 10 drafts, clip playback in browsers | Manual |

## Task dependencies and order

1. **D2 first:** the owner creates the Twitch developer account, checks the terms and writes to IGDB about images (Q1). IGDB's answer gates production, not M1-22 in `local`.
2. **M1-20** (client), then **M1-21** (title import; also re-runs the search benchmark).
3. **M1-22** (builder), the largest; the clip made from screenshots (Q2) is not yet estimated.
4. **M1-24** (review and scheduling) after M1-22; D5 says the owner reviews.
5. **M1-23**: the backend part (`source_url` filled) lands with M1-22; the frontend Sources section can be built any time against the dev seed, which already has `source_url`.
6. **M1-25** after M1-24; M1-52 schedules it and sends the alerts.
7. Before launch: the production launch date (Q17), 30 scheduled puzzles in production (AC-61), the attribution in the footer (AC-71, with M1-46).

## Questions and options (answered 2026-11-12)

Recommended option first. The owner chose the recommended option (a) for all 18 on 2026-11-12.

1. **Q1. IGDB terms for screenshots (D2).** IGDB's FAQ says "we prefer if you store and serve the data", but says nothing about images. The Twitch Developer Services Agreement, which IGDB's docs point to, says not to store copies longer than 24 hours without authorisation, and not to modify program materials. (a) **Recommended:** at signup, email partner@igdb.com and ask whether a free, ad-free site may store and serve cropped, pixelated, re-encoded screenshots with attribution; build and review in `local` meanwhile; nothing reaches production until the answer is yes or the owner accepts the risk in writing. (b) Rely on the FAQ and proceed. (c) The Milestone fallback: a hand-built list with screenshots the owner provides. Affects AC-1, AC-2.
2. **Q2. Source of the step-6 clip.** IGDB's videos are YouTube ids only, and YouTube's terms forbid downloading and re-hosting. Steam's store has trailer files, but no published terms allow reusing them, and Steam's subscriber agreement forbids redistributing content and using bots. (a) **Recommended:** the builder makes the clip from two or more screenshots not used in steps 1 to 5 (slow pan and cross-fade, about 12 seconds); no new source or terms. It is a weaker clue than real gameplay. (b) Steam trailers cut to 12 seconds, as an accepted rights risk like the screenshots, with a source link to the Steam page. (c) The owner records clips himself. (d) Go back to an image at step 6, which reverses SPEC-02 Q4. Affects AC-36 to AC-38, and the M1-22 estimate.
3. **Q3. Step-2 hint.** IGDB gives an "aggregated rating based on external critic scores", not Metacritic. (a) **Recommended:** a new kind `critic_score`, labelled "Critic score" (Russian "Оценка критиков"), shown only with at least 4 critic scores. This adds one kind to `CONTRACTS.md`'s list and one frontend label. (b) Keep `metacritic_score` and "Metacritic" (inaccurate). (c) Use another score (IGDB's total rating) with its own label. (d) No hint at step 2. Affects AC-31.
4. **Q4. Franchise flag source.** IGDB has a main `franchise`, other `franchises`, and `collections` ("series"). (a) **Recommended:** the main franchise, else the first series. (b) The first series, else the franchise. (c) The franchise only; games with none never get the flag. Affects AC-12.
5. **Q5. Dates of drafts.** The puzzle date is required and unique per game and variant, so a draft or an approved spare must hold a date. (a) **Recommended:** the date becomes optional until a puzzle is scheduled; a scheduled puzzle must have one (a backend schema change; no API change). (b) The builder builds for target dates, and a rejection frees the date. `approved` then has no pool of spares. Affects AC-46, AC-55.
6. **Q6. Rejecting a draft.** (a) **Recommended:** delete the draft and record an exclusion with the reason "rebuild" or "never". (b) A new `rejected` status (changes SPEC-02 Q5's four statuses). Affects AC-51 to AC-53.
7. **Q7. Review tool.** (a) **Recommended:** a tiny local page that runs only in the `local` environment and shows the draft as the player sees it. (b) A CLI that opens the files in the system viewer and takes approve or reject. Affects AC-47 to AC-50.
8. **Q8. Candidate thresholds.** (a) **Recommended start values:** main games, remakes, remasters and expanded games; released at least a year ago; at least 7 screenshots of at least 1280 by 720 pixels; at least 50 ratings. Measure the counts first (AC-24). (b) Stricter: at least 200 ratings (only well-known games). (c) Looser: at least 20 ratings. Affects AC-21.
9. **Q9. Repeats.** (a) **Recommended:** an answer never repeats in Milestone 1; no two answers of one series within 14 days. (b) An answer may repeat after 2 years; series gap 7 days. Affects AC-25, AC-57.
10. **Q10. Search list scope.** (a) **Recommended:** main games, remakes, remasters, expanded games and standalone expansions with at least one rating, plus every candidate. (b) Every main game in IGDB, rated or not (much larger list; check the search latency). (c) Only candidates (a small list that gives the answer away). Affects AC-10, AC-11.
11. **Q11. Form of the credits.** (a) **Recommended:** a "Sources" section on the end screen, from the existing `source_url`, link text = host name; no API change. (b) A separate page `/games/{slug}/{date}/sources`, like the reference's "Screenshot Sources" page. (c) A new per-step source label in the view (a boundary change). Affects AC-63 to AC-70.
12. **Q12. What `source_url` points at.** (a) **Recommended:** the game's page on igdb.com. (b) The original screenshot file on IGDB's image host. (c) Both (needs a second field, a boundary change). Affects AC-33, AC-64.
13. **Q13. IGDB attribution.** IGDB asks for attribution "visible to your users and located in a static location". (a) **Recommended:** one line in the site footer, "Game data and images: IGDB.com", landing with M1-46, before any IGDB content reaches production; plus "Images via IGDB" in the Sources section. (b) Add the footer line now, in Phase 3. (c) On the legal page only. Affects AC-65, AC-71.
14. **Q14. Where scripts run.** (a) **Recommended:** on the owner's workstation, writing to the environment named on each run; the check runs on the server once M1-52 sets it up. (b) A scheduled GitHub Action with environment secrets (ARCHITECTURE 10's other option): needs the salt and IGDB secrets in GitHub, and the review still happens locally. Affects AC-44, AC-78.
15. **Q15. Alert codes and scope.** (a) **Recommended:** exit 2 when tomorrow is missing or broken (page), exit 1 when the buffer is under 7 days (digest), another non-zero code when the check cannot run, 0 otherwise; "ready" includes the files being in storage. (b) One non-zero code for every problem. Affects AC-74 to AC-80.
16. **Q16. Step-1 crop.** (a) **Recommended:** from a screenshot not used in steps 2 to 5. (b) From the step-2 screenshot (needs one screenshot fewer, but step 2 then repeats it). Affects AC-34.
17. **Q17. Launch date.** (a) **Recommended:** the owner sets the game's production launch date before Phase 5; scheduling starts from the later of tomorrow and that date; the check reports "not launched" until 7 days before it. (b) Set it now to a provisional date and move it later. Affects AC-56, AC-61, AC-82.
18. **Q18. Names and logos inside screenshots.** (a) **Recommended:** the reviewer is the only check in Milestone 1. (b) Add an automatic text check on screenshots (decision 19 allows AI only as a fallback). Affects AC-48.
