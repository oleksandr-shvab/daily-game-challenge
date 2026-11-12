# Phase 3 frontend: clue sources on the end screen and the "Critic score" label — Implementation Plan

Status: draft, 2026-11-12. Scope: the frontend repo `my-list-fe/` (own git, GitHub `oleksandr-shvab/my-list-fe`, trunk-based, one PR per step). No change to `CONTRACTS.md` here: the one Phase 3 edit of the seam is made by backend PR M1-22b (`plans/04-phase-3-backend.md`). Line numbers were checked against frontend `main` at `ef8f791` and backend `main` at `08fdb12`. The owner answered SPEC-04's Q1 to Q18 on 2026-11-12 with option (a) for each; they are not reopened.

## Source requirements

- Spec: `specs/04-phase-3-content.md` (SPEC-04), frontend criteria **AC-63 to AC-70** (M1-23, "Source credits after a game") and the frontend label of **AC-31** (Q3: `critic_score` shows as "Critic score"). Interface strings: `specs/04-…:211-223`. Boundary note: `specs/04-…:305-310`.
- Answers that shape this plan: Q11 (a Sources section on the end screen, from the view's existing `source_url`, no new page, no new API field), Q12 (`source_url` is the game's igdb.com page), Q13 ("Images via IGDB" in the section; the footer line lands with M1-46), Q3 (`critic_score`, "Critic score").
- Not in this plan: the footer attribution (AC-71) and the legal page (AC-72), both M1-46; every backend task (`plans/04-phase-3-backend.md`).

**State of the code (checked 2026-11-12):**
- Phase 2 is merged (`ef8f791`, PR #35). The end screen is `src/features/games/game-guesser/end-screen.tsx` (192 lines); it shows only for a won or lost view (frontend `CLAUDE.md:74`).
- The generated client already has `source_url: string | null` on every step, "Null until the game ends" (`src/api/generated/models/stepRead.ts`), and each step's `media` with `sources`, `poster` and `expires_at` (`mediaRead.ts`). **No regeneration is needed**: SPEC-04 changes no API shape (Q11), and no backend PR of Phase 3 changes the OpenAPI snapshot (backend plan, "Hand-off").
- Hint labels are a map of five kinds with a generic fallback (`src/features/games/clue-ladder/clue-ladder.tsx:8-27`); the catalogues hold `games.hint.metacritic_score` = "Metacritic" (`src/i18n/locales/en.json:77`, `ru.json:83`).
- The dev seed sends `source_url: "https://example.com/seed/source"` on every step (`my-list-be/scripts/seed_dev.py:47`).
- The frontend has no `LEARNINGS.md` (checked).

## Clarifications & recommendations

No questions could be asked (this planner runs as a subagent). Facts were checked in the code; judgment calls are marked **R-n**.

- **R-1. A disclosure button, no new dependency.** AC-69 asks for a section "opened by a button with an accessible name". A `<button aria-expanded aria-controls>` that shows a region below it is the ARIA disclosure pattern and needs no Radix component (shadcn has no collapsible installed; `src/components/ui/` has none). Closed by default, so the end screen stays as short as it is now.
- **R-2. Link text is the host without a leading `www.`.** The backend builds `https://www.igdb.com/games/<slug>` (backend plan R-18), and AC-64's example text is "igdb.com". "Images via IGDB" (AC-65) shows when every row's host, after that strip, is `igdb.com`.
- **R-3. One parse rule for a source.** `sourceLinkOf(sourceUrl)`: `null`, a string `new URL` refuses, or a protocol other than `http:` or `https:` gives "Source not recorded" (AC-68, spec "Untrusted inputs"); otherwise `{ href: url.href, host }`. The `href` is the parsed URL's own, never with anything added (AC-66).
- **R-4. Thumbnails reuse the view's links, with no refresh of their own.** A thumbnail is the step's image (`media.sources[0]` for an image) or the clip's poster (`media.poster`) at a small fixed size. These are the same signed links the ladder shows above (bearer links, private, never put in the source link). An image link lives 600 s; if the section is opened after that, or a thumbnail fails, the row shows a box with the text "Clue N" in place of the picture. The source link, the part the AC is about, still works. Asking for fresh links would mean a second user of `useRefreshLinks` (`refresh-links.ts`) for a decoration; Open question 1.
- **R-5. `critic_score` replaces `metacritic_score` in the label map and the catalogues.** The backend stops producing `metacritic_score` in M1-22b and changes the dev seed with it. Keeping the old key costs nothing, but `CONTRACTS.md` will no longer list it; removing it keeps the map equal to the documented kinds. Either way an unknown kind still shows under "Hint" (`clue-ladder.tsx:17-21`). Open question 2.
- **R-6. Where the section sits.** After the row of buttons (Share, Statistics, Play previous days) and the share status, before the sign-up nudge and the countdown (`end-screen.tsx:136-189`). The section is part of the end screen only, so it cannot exist before the game ends (AC-67) by construction, not by a flag.

## Execution mode

- **Owner's choice (already decided, not asked again):** one `implementer` agent per PR, then `plan-verifier`; the owner merges. Commits and PRs only when the owner asks.
- **Extra passes:** the owner's rule (code-review high and test-writer) is for backend PRs with a migration or a route; neither frontend PR has one. Neither is risky: M1-23 renders data the view already has, and FE-Q3 adds one label. `plan-verifier` only.
- **Test budget** (the owner's rule for agents, same as Phase 2 R-9): write the tests listed under the PR, no more, and check each can fail by mutating the rule it covers (drop the protocol check, show the section during play) and watching it go red.
- **Running alongside the backend:** M1-23 depends on nothing and can run alongside backend wave A (M1-22a with M1-20), in its own repo. FE-Q3 merges in the same pass as backend M1-22b (the boundary task). Scratch prefixes in the shared session scratchpad: `p3_23_`, `p3_q3_`; never run a scratch script another agent wrote. If both a frontend and a backend agent run the app, the frontend dev server stays on `http://localhost:5173` (the only allowed origin for POSTs; `my-list-fe/CLAUDE.md:32`).

## Order and estimates

Agent minutes are estimates, calibrated on Phases 1 and 2. Owner review is separate.

| Step | PR | Waits for | Implementer | plan-verifier | Agent total | Owner review |
|---|---|---|---|---|---|---|
| any (alongside backend wave A) | **M1-23** Sources section | nothing | 20 | 5 | ~25 min | 15-20 min |
| with backend M1-22b | **FE-Q3** "Critic score" label | nothing; merge in the same pass as M1-22b | 3 | 2 | ~5 min | 2 min |

`MILESTONE-1.md:96` gives M1-23 0.5 days for backend and frontend together; the backend half (filling `source_url`) is inside M1-22b and M1-22d. Not changed by this plan.

## Modules affected

| Where | Why | PR |
|---|---|---|
| `src/features/games/game-guesser/clue-sources.tsx` (new) | The Sources disclosure and its six rows | M1-23 |
| `src/features/games/game-guesser/source-link.ts` (new) | `sourceLinkOf` (R-3) and the host text (R-2), pure | M1-23 |
| `src/features/games/game-guesser/end-screen.tsx` | Mount the section (R-6) | M1-23 |
| `src/i18n/locales/en.json`, `ru.json` | `games.sources.*` (M1-23); `games.hint.critic_score`, remove `games.hint.metacritic_score` (FE-Q3) | both |
| `src/features/games/clue-ladder/clue-ladder.tsx` | Label map: `critic_score` replaces `metacritic_score` (`:8-14`) | FE-Q3 |
| `src/features/games/game-guesser/share-text.test.ts` | Its fixture hint kind (`:45`) follows the rename; text only | FE-Q3 |
| `CLAUDE.md` (frontend) | "Games": one bullet on the Sources section | M1-23 |

Not touched: `src/api/generated/` (no regeneration), routes, queries, guest records, the backend.

## Facts found (file:line)

- `StepRead` is `{ step, hint, media, source_url }`, `source_url` `string | null` (`src/api/generated/models/stepRead.ts`); `MediaRead` has `type`, `width`, `height`, `expires_at`, `sources`, `poster` (`mediaRead.ts`).
- At the end of a game the view holds all six steps with `source_url` (`CONTRACTS.md:355-357`); during play only earned steps, all with `source_url: null`.
- `EndScreen` takes the whole `view` (`end-screen.tsx:14-32`), so the section needs no new prop from `GuesserGame` (`guesser-game.tsx:186`).
- The end screen's layout: heading `:115`, answer `:119-132`, guess list `:134`, buttons `:136-152`, share status `:155-168`, nudge `:171-177`, countdown `:180-189`.
- Hint labels: `HINT_LABEL_KEYS` (`clue-ladder.tsx:8-14`), fallback `games.hint.hint` (`:17-21`); catalogues `en.json:76-83`.
- The catalogue parity test fails when the two files differ in keys (`src/i18n/catalogues.test.ts:52`; frontend `CLAUDE.md:121`).
- The test harness builds views from the generated type (`src/test/router-harness.ts:46-67`); end-screen tests exist in `end-screen.test.tsx` with `startApp` and the fake backend.
- The seed's `source_url` is `https://example.com/seed/source` (`my-list-be/scripts/seed_dev.py:47`), so in dev the rows say "example.com" and "Images via IGDB" does not show.

## Architectural constraints

From `my-list-fe/CLAUDE.md`:
- Generated code is never hand-edited; the `api-types` CI job fails on a diff ("Key architectural decisions", `:46`). Platform rule: regenerate with Orval, never hand-patch (root `CLAUDE.md`, "Working across both repos").
- Never write user-visible text in a component; both catalogues; backend values are shown as data (`:119-125`).
- Touch controls 44 px high below 768 px (`max-md:`), at least 24 px everywhere (`:92`).
- Tests: `*.test.ts(x)` next to the code; component tests start with `// @vitest-environment jsdom` and import `src/test/dom-setup.ts` first; no `jest-dom`; query by role and text with `userEvent` (`:105-106`).
- A game screen is lazy; keep new code inside the game guesser's import graph (`:58`).
- Comments only where the why is not obvious (`:110`).

From the spec:
- No source link and no Sources section before the game ends (AC-67); the backend already sends `source_url` only at the end (SPEC-02 AC-26).
- Links open in a new tab, send no referrer and carry nothing about the player (AC-66).
- `source_url` is untrusted text: shown only as a link with `http` or `https`; the host shown as text (`specs/04-…:303`).
- WCAG 2.2 AA, as SPEC-03 (`specs/04-…:268`).

## Approach

Every PR: branch from a fresh `main` (`p3-m1-23-sources`, `p3-q3-critic-label`), PR to `main`, the four CI jobs green (lint, build, test, api-types).

### M1-23. Sources section on the end screen (AC-63 to AC-70)

1. **`source-link.ts`** (pure): `sourceLinkOf(sourceUrl: string | null): { href: string; host: string } | null` (R-3); `displayHost(host)` drops one leading `www.` (R-2); `allFromIgdb(steps)` is true when every step has a link whose display host is `igdb.com`.
2. **`clue-sources.tsx`**: `ClueSources({ steps })`, given the view's six steps.
   - A `Button` (variant `outline`, `max-md:h-11`) "Sources" with `aria-expanded` and `aria-controls` pointing at the region (AC-69, R-1).
   - When open: a region with the heading "Where these clues come from" (an `h3`, below the end screen's `h2`), then an ordered list of the steps by `step` (AC-64).
   - Each row:
     - the step text "Clue {{n}}";
     - a thumbnail (R-4): `<img>` of the image or the poster, a fixed small box (for example 96 px wide, height from `media.width` and `media.height`), `alt` "Clue {{n}}" (AC-69); when `expires_at` is past at render or the image fires `error`, a box with the same text instead;
     - the link: `<a href={href} target="_blank" rel="noopener noreferrer" referrerPolicy="no-referrer">` with the display host as its text (AC-64, AC-66). Since the text is only a host, give it an accessible name that says where it goes: `aria-label` from `games.sources.link_label` ("Source of clue {{n}}: {{host}}, opens in a new tab"; AC-69). Or "Source not recorded" as plain text when `sourceLinkOf` gives `null` (AC-68).
   - Under the list, when `allFromIgdb`: "Images via IGDB", where "IGDB" links to `https://www.igdb.com` with the same `target`, `rel` and `referrerPolicy` (AC-65).
   - Open state is local to the component (closed on mount). No query, no request.
3. **`end-screen.tsx`**: render `<ClueSources steps={view.steps} />` after the share status block and before the nudge (R-6). Nothing else changes.
4. **Catalogues** (`en.json`, `ru.json`; Russian from `specs/04-…:217-221`; the D6 reviewer checks it later):
   - `games.sources.button`: "Sources" / "Источники"
   - `games.sources.heading`: "Where these clues come from" / "Откуда эти подсказки"
   - `games.sources.clue`: "Clue {{n}}" / "Подсказка {{n}}"
   - `games.sources.via_igdb`: "Images via {{igdb}}" / "Изображения: {{igdb}}" (the link is rendered with `Trans` or as a split around the name)
   - `games.sources.not_recorded`: "Source not recorded" / "Источник не указан"
   - `games.sources.link_label`: "Source of clue {{n}}: {{host}}, opens in a new tab" / "Источник подсказки {{n}}: {{host}}, откроется в новой вкладке" (this one is mine, not in the spec table; the D6 reviewer checks it too)
5. **Docs**: frontend `CLAUDE.md` "Games", next to the "End screen" bullet: the Sources section, the link rules (R-3), that thumbnails reuse the view's links and fall back to text (R-4).

Tests:
- `source-link.test.ts`, one table: `https://www.igdb.com/games/doom` gives host "igdb.com" and the same `href`; `http://example.com/x` gives "example.com"; `null`, `""`, `"not a url"`, `"javascript:alert(1)"`, `"data:text/html,x"` and `"ftp://igdb.com/x"` give `null`; `allFromIgdb` is true for six igdb.com steps and false when one is `example.com` or `null` (AC-64, AC-65, AC-68).
- One component test in `end-screen.test.tsx` (jsdom, `startApp`, the fake backend): an in-progress view has no "Sources" button; a lost view with six steps (one `source_url: null`, five igdb.com) has it collapsed; pressing it with the keyboard (Tab, Enter) shows six rows in step order, five links with `target="_blank"`, `rel` containing `noreferrer`, `referrerpolicy="no-referrer"`, text "igdb.com" and an `href` equal to the given URL, one "Source not recorded", and no "Images via IGDB" (one source is missing) (AC-63, AC-64, AC-66 to AC-69).
- Catalogue parity runs as is (AC-70).

Manual (`http://localhost:5173`, dev seed, signed out): lose today's puzzle with six skips; the end screen shows "Sources"; opening it lists six rows with thumbnails and "example.com" links that open in a new tab; DevTools Network shows the new tab's request without a `Referer`; Tab reaches the button and every link; Russian shows the Russian texts. After backend M1-22d and a real puzzle in the content database (backend R-11): the links say "igdb.com" and "Images via IGDB" shows.

Acceptance M1-23: AC-63 to AC-70; SPEC-04 local DoD item 6 (with a real puzzle, after the backend's M1-24b).

### FE-Q3. "Critic score" label (AC-31, frontend half; Q3)

1. `clue-ladder.tsx:8-14`: `critic_score: 'games.hint.critic_score'` replaces `metacritic_score` (R-5).
2. Catalogues: `games.hint.critic_score`: "Critic score" / "Оценка критиков" (`specs/04-…:223`); remove `games.hint.metacritic_score` from both.
3. `share-text.test.ts:45`: the fixture's hint kind becomes `critic_score` (the test checks that hint values never reach the share text; the kind's name does not matter to it).
4. No new test: the label is a map entry, and the catalogue parity test covers the two files.

Merge in the same pass as backend M1-22b, which edits `CONTRACTS.md` ("The view", hint kinds) and switches the dev seed to `critic_score`. Either order is safe: an unlabelled kind shows under "Hint", and an unused label shows nowhere.

Manual: re-run the backend seed after M1-22b merges; step 2 of a seeded puzzle shows "Critic score: 90".

## Client regeneration

None in Phase 3. The snapshot does not change (backend plan, "Hand-off"), and `src/api/generated/` stays as it is; the `api-types` CI job proves it on every PR. If a backend PR ever does change `openapi/openapi.json`, regenerate after that backend merge with `npm run api:generate` (locally it reads `../my-list-be/openapi/openapi.json`) in its own PR, and never edit the generated files by hand (`my-list-fe/CLAUDE.md:46`; root `CLAUDE.md`).

## Skills for implementer

Project skills are in `my-list-fe/.claude/skills/`; when the implementer runs from the platform folder, read the `SKILL.md` files directly.

| Files | Load | Why |
|---|---|---|
| Every code change | `shvab:karpathy-guidelines` | Small, surgical diffs |
| `clue-sources.tsx`, `end-screen.tsx` | `shvab:react-best-practices`, `react-component-api`, `react-state-patterns` | One local `open` state; derive rows from `steps`, never copy them; accessible disclosure |
| `source-link.ts` | none beyond the above | Pure function; `URL` parsing per the WHATWG URL standard (`docs` if in doubt) |
| `clue-ladder.tsx` | `react-component-api` | One map entry |
| `src/i18n/locales/*.json` | none | **Gap:** no skill; follow `CLAUDE.md` "Translations" (`Trans` for the linked "IGDB") |
| `*.test.ts(x)` | `shvab:react-testing-library` | `startApp`, jsdom, `userEvent` keyboard, queries by role |
| `CLAUDE.md` | `shvab:no-ai-slop` | The owner wants plain, short sentences |

`shvab:zod` does not apply (no stored data is parsed).

## Verification

Run in `/home/alexandr/Developer/MyList project/my-list-fe`.

Gate for every PR (what CI runs, scoped where possible):
- `npm run lint`, `npm run format:check`, `npm run build`.
- The PR's tests: M1-23 `npx vitest run src/features/games/game-guesser/source-link.test.ts src/features/games/game-guesser/end-screen.test.tsx src/i18n`; FE-Q3 `npx vitest run src/features/games/game-guesser/share-text.test.ts src/features/games/clue-ladder src/i18n`.
- api-types: `API_SPEC=https://raw.githubusercontent.com/oleksandr-shvab/my-list-be/main/openapi/openapi.json npm run api:generate && git status --porcelain -- src/api/generated` prints nothing.
- No full `npm test` run is needed locally: neither PR touches shared code (routes, harness, queries); CI runs the full suite.

## Risks

- **Expired thumbnails** after 10 minutes on the end screen (R-4): the row shows "Clue N" as text; the source link still works. Open question 1 offers a refresh.
- **The host is the only link text**, which a screen reader reads as "igdb.com"; the `aria-label` adds the clue number and "opens in a new tab".
- **Russian texts** are the spec's, plus one of mine (`link_label`); the D6 reviewer checks them.
- **IGDB changes its page URLs.** The links are built by the backend from IGDB's slug and stored per puzzle; a change breaks old links only, and the row still shows the host.

## Rollback

- Each PR is one squash commit; revert with a revert PR.
- Reverting M1-23 removes the section; nothing is stored.
- Reverting FE-Q3 brings back "Metacritic"; a `critic_score` hint then shows under "Hint" until it is re-applied.

## Open questions for the owner

Answered by the owner on 2026-11-12 (`SPEC.md` decision 69): option (a) for all three. The new string `games.sources.link_label` goes to the D6 Russian check.

1. **Expired thumbnails in the Sources section (R-4).** (a) **Recommended:** a text box "Clue N" when the link has expired or failed; no request. (b) When the section opens with expired links, ask for fresh links once through the screen's existing `useRefreshLinks` (about 10 more agent minutes and one more test).
2. **Keep or drop the `metacritic_score` label (R-5).** (a) **Recommended:** drop it with FE-Q3; the map then equals the kinds in `CONTRACTS.md`. (b) Keep it, harmless, in case old data appears (none exists outside the dev seed, which M1-22b changes).
3. **`www.` in the link text (R-2).** (a) **Recommended:** show "igdb.com" for `www.igdb.com`, as AC-64's example. (b) Show the host exactly as stored ("www.igdb.com").

## Traceability

| AC | PR, step | Checked by |
|---|---|---|
| AC-31 (label) | FE-Q3.1, .2 | catalogue parity; manual "Critic score: 90" |
| AC-63 | M1-23.2, .3 | end-screen component test (button only when finished) |
| AC-64 | M1-23.1, .2 | `source-link.test.ts`; component test (six rows, order, host text) |
| AC-65 | M1-23.1, .2 | `source-link.test.ts` (`allFromIgdb`); component test (absent with a missing source); manual with a real puzzle |
| AC-66 | M1-23.2 | component test (`target`, `rel`, `referrerpolicy`, `href` unchanged); manual Network check |
| AC-67 | R-6, M1-23.3 | component test (in-progress view has no button) |
| AC-68 | M1-23.1, .2 | `source-link.test.ts`; component test ("Source not recorded") |
| AC-69 | M1-23.2 | component test (keyboard, `aria-expanded`, link names); manual screen reader pass |
| AC-70 | M1-23.4, FE-Q3.2 | `catalogues.test.ts` |
| AC-71, AC-72 | M1-46 | not in this plan (backend plan "Hand-off" carries the fixed text) |
