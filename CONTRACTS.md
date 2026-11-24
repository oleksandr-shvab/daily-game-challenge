# Daily Game Challenge: Frontend/Backend Contracts

Shared reference for `my-list-fe` and `my-list-be`. Anything here must stay true on
both sides — when one repo's Claude session changes one of these, update this file
in the same session and flag it to the other repo's session (message it directly if
a Claude Code session is running there, e.g. `SendMessage` by session name from
`ListAgents`).

Each repo's `CLAUDE.md` links here under "Related"; this file doesn't duplicate
repo-internal detail (stack choices, file layout) — only the seams between the two.

## API base and routing

- Backend serves on `http://localhost:8000`. The API lives under `/v1` (`/v1/auth/login`); the
  health endpoints (`/healthz`, `/readyz`) are outside the version prefix.
- Frontend calls `/api/v1/...`; Vite's dev proxy (and the production proxy) strips `/api` and
  forwards `/v1/...` to the backend. This keeps a stable frontend-facing path independent of backend
  mounting. A breaking change to the API means `/v2`, served next to `/v1` until the clients move.
- Frontend dev server: `http://localhost:5173`. Backend CORS allows this origin (local only).
- The backend commits its OpenAPI document as `my-list-be/openapi/openapi.json` (rewrite it with
  `uv run python scripts/export_openapi.py`; a test and CI fail when it is stale). Operation ids are
  `<tag>_<handler name>` (`auth_login`), so renaming a handler is an API change.

## Auth

- Session-cookie auth (Django-auth style), not JWT. Backend sets an httpOnly,
  `SameSite=Lax` cookie named `session_id` on `POST /auth/register` and
  `POST /auth/login` (register auto-logs-in). Session data lives in Redis
  (`session:{opaque token}` → user id), no Postgres sessions table.
- `GET /auth/me` returns the current user; the frontend requests it on every page
  load without blocking public pages, and treats a 401 as a guest.
- `POST /auth/logout` deletes the Redis key and clears the cookie.
- **Cookie host-scoping gotcha**: the cookie is host-scoped, so frontend must reach
  the backend via `http://localhost:8000`, not `127.0.0.1:8000` — otherwise the
  cookie won't round-trip to `http://localhost:5173`.
- CSRF: every request on the API except GET, HEAD and OPTIONS (in practice POST, PUT, PATCH and
  DELETE) is checked before anything else (before the
  session, the body, the content type and the route's own rules). The request's origin is the
  `Origin` header, or the origin of `Referer` if `Origin` is absent. If neither is present, the value
  is `null`, or the origin is not exactly one of the allowed origins (scheme, host and port; no
  wildcard, no suffix match), the answer is 403 `csrf_origin_mismatch` and nothing changes. GET,
  HEAD and OPTIONS are not checked. Allowed origins: the origin of `FRONTEND_URL`; in `local` and
  `test` also the origins in `BACKEND_CORS_ORIGINS` and the API's own origin
  (`API_BASE_URL`, default `http://localhost:8000`, so "Try it out" on `/docs` works). Staging and
  production allow only `FRONTEND_URL`'s origin.
- JSON-only bodies: a POST, PUT or PATCH that carries a body must have `Content-Type:
  application/json` (a `charset` parameter is fine), otherwise 415 `unsupported_media_type`. A
  body is any request with `Transfer-Encoding` (whatever `Content-Length` says) or a non-zero or
  unreadable `Content-Length`, so an empty chunked POST without `application/json` gets 415. A request
  with no body framing (for example `POST /auth/logout` from a browser) is not refused for its
  content type.
- No custom CSRF header exists (decision Q18); the frontend sends nothing extra. The browser sets
  `Origin` itself. Dev notes: open the frontend at `http://localhost:5173`, not `127.0.0.1:5173`,
  and not the preview server on 4173, because neither origin is allowed. The Vite proxy must keep
  the browser's `Origin` header. curl and scripts must send `-H 'Origin: http://localhost:5173'`.
  `SameSite=Lax` stays as defense in depth.
- Frontend never handles a raw token; all requests use `withCredentials: true`.
- The cookie is `Secure` in every environment except `local` and `test`. Passwords are 8 to 128
  characters (counted as characters, not bytes) and are hashed with argon2id.

### Password reset

- `POST /auth/forgot-password` — body `{ email }`. Always responds `202` with a
  generic message (`"If an account with that email exists, a reset link has been
  sent."`), whether or not the email is registered — this is deliberate, do not
  build any frontend behavior that infers account existence from this response.
- If the account exists and is active, backend generates a single-use reset token,
  stores it in Redis (`password_reset:{token}` → user id, 2-day TTL), and "sends" a
  reset email — no real sender is wired up yet. In `local` and `test` the link is logged
  server-side, so during dev it must be copied from backend logs; in any other environment nothing
  is logged (the link is an account-takeover token). The frontend's Playwright suite reads the logged line from the backend's output, so the line keeps the email and the link (`tests/test_password_reset.py` in the backend pins it).
- Reset link format: `{FRONTEND_URL}/reset-password?token={token}` (`FRONTEND_URL`
  defaults to `http://localhost:5173` in dev). Frontend's `/reset-password` route
  reads `token` from the query string and submits it back in the next call.
- `POST /auth/reset-password` — body `{ token, new_password, confirm_password }`.
  Both password fields are validated server-side (min 8 / max 128 chars, and must
  match) — never rely on client-side "passwords match" checks alone. Responds `204`
  on success (frontend should redirect to `/login`), `400` if the token is
  missing/invalid/expired/already used, `422` on password validation failure.
- Requesting a new reset link invalidates any earlier unused one for that user.
- On success, backend revokes **all** of the user's active sessions (not just the
  reset-flow token) — the user is logged out everywhere and must log in again with
  the new password. Frontend should not assume any pre-existing session/cookie
  still works after a reset completes.
- `forgot-password` is rate limited per IP (10 an hour) and per email (3 an hour). Over the IP
  limit it answers `429` (see "Rate limits"). Over the email limit it still answers the same `202`
  and sends nothing, so the response never shows that an email was tried before. Do not write UX
  copy that promises an email arrives.

### Password update (authenticated)

- `POST /auth/update-password` — requires an authenticated session (cookie), same
  as any other protected route. Body: `{ old_password, new_password,
  confirm_password }`.
- Validated server-side: `new_password`/`confirm_password` must match, `new_password`
  must be 8-128 chars, and **must differ from `old_password`** — surface all three as
  form-level checks in the UI, but never rely on them client-side only.
- Responses: `204` on success, `400` if `old_password` doesn't match the current
  password, `422` on the validation failures above, `401` if not authenticated.
- On success, backend revokes every *other* active session for that user (other
  devices/tabs get logged out) but keeps the session that made this request valid —
  no re-login needed, no cookie changes, just show a success state and clear the
  form. This differs from `reset-password`, which logs the user out everywhere
  including the current session.
- No email/notification is sent on password change (out of scope for now).

## Errors

- Every error response from the backend is an RFC 9457 problem-details body (content type
  `application/problem+json`) with extension members:
  `{"type": "about:blank", "status": 409, "title": "Email already registered",
  "code": "email_already_registered", "params": {}, "request_id": "...", "errors": []}`.
- `code` is the stable machine-readable name and the only thing the frontend may branch on or
  translate. `title` is English, for developers and logs. `params` carries values for the message
  (for example `{"min": 8}`).
- Validation failures use status 422 and `code: "validation_error"`. Each entry of `errors` is
  `{"field": "password", "code": "too_short", "params": {"min": 8}}`; `field` is the request field
  name (`""` if none). The submitted values are never echoed back.
- Other codes in use: `email_already_registered` (409), `invalid_credentials` (401),
  `not_authenticated` (401), `invalid_or_expired_reset_token` (400), `incorrect_password` (400),
  `passwords_do_not_match` and `new_password_same_as_old` (422, as field errors), `not_found` (404),
  `method_not_allowed` (405), `csrf_origin_mismatch` (403), `unsupported_media_type` (415),
  `game_not_found`, `variant_not_found` and `puzzle_not_found` (404, see "Games"),
  `title_not_found`, `duplicate_guess` and `invalid_guess_history` (422) and
  `puzzle_already_finished` (409), see "Games",
  `invalid_media_link` (403) and `range_not_satisfiable` (416), see "Clue media",
  `bad_request` (400: a body the JSON parser rejects before validation, for example a number longer
  than 4300 digits), `too_many_requests` (429, see "Rate limits"), `service_unavailable` (503),
  `internal_error` (500). Every `application/problem+json` error
  response carries `Cache-Control: no-store` and `X-Content-Type-Options: nosniff`
  (CORSMiddleware's own plain-text 400 on a refused preflight, dev only, is not one of them).
- Every response carries `X-Request-ID` (the proxy's value if well formed, else generated) and the
  same id is in the body as `request_id`; the frontend shows it on its error screen.
- The frontend's `ApiError` mirrors this (`status`, `code`, `params`, `requestId`, `fieldErrors`) and
  shows texts looked up by `code` in its English and Russian catalogues (`errors.<code>`; an unknown code shows a generic text, never the backend's English); a response without a JSON body (a proxy error page) becomes
  `code: "http_error"`, and no response at all becomes `status: 0, code: "network_error"`.
- Success bodies are unchanged. The `202` of `forgot-password` still returns `{"detail": "..."}`.

### Rate limits

- A route over its limit answers `429` with `code: "too_many_requests"` and a `Retry-After` header
  (whole seconds until the window ends, at least 1). The frontend's query retry already treats 429
  as retryable at most twice, and `errors.too_many_requests` exists in both catalogues.
- Fixed windows counted in Redis, per client address (an IPv6 address counts as its /64) or per
  hashed email. The counts are backend settings (`RATE_LIMIT_*`); the windows are fixed:

  | Route | Key | Default | Window |
  |---|---|---|---|
  | `POST /auth/login` | IP, and separately the email | 10 and 10 | 1 min, 15 min |
  | `POST /auth/register` | IP | 10 | 1 hour |
  | `POST /auth/forgot-password` | IP (429); the email (silent 202) | 10; 3 | 1 hour |
  | `POST /auth/update-password` | user id | 10 | 1 hour |
  | `POST /auth/reset-password` | IP | 10 | 1 hour |
  | `POST /games/{slug}/puzzles/{date}/guesses` | IP | 60 | 1 min |
  | `GET /games/{slug}/titles` | IP | 120 | 1 min |

  `update-password` and `reset-password` share one setting, `RATE_LIMIT_PASSWORD_CHANGE`.
- The limit is checked before the route's own work but after the request body is validated, so a
  malformed request is a `422` and is not counted.
- A per-email login limit means someone who knows an email can lock that email out of logging in
  for 15 minutes. This is accepted at this size.
- Per-IP limits need the real client address. Behind the proxy, uvicorn runs with `--proxy-headers`
  and trusts the `X-Forwarded-For` that Caddy sets itself; Caddy must not trust a client's value
  (keep `trusted_proxies` unset). If this breaks, every visitor shares one address.
- If Redis fails, the limiter lets the request through.
- The e2e suite registers and logs in from one address, so the e2e backend config in the frontend
  repo (`e2e/support/backend-env.ts`) raises every `RATE_LIMIT_*` count to 1000. Staging and
  production refuse to start with `RATE_LIMITS_ENABLED=false`.
- A guest's guess stores nothing, so the response must say whether it is right. A script can try
  titles until one is correct; the guess limit only makes that slow (SPEC decision 80).

## Games

Routes (all under `/v1`, so the frontend calls `/api/v1/games/...`). Game routes work for a guest
with no cookie; none of them answers 401, except the stats and merge routes. Operation ids: `games_list_games`,
`games_get_today_puzzle`, `games_get_puzzle`, `games_search_titles`, `games_submit_guess`,
`games_resume_puzzle`, `games_get_stats`, `games_merge_progress`, `games_list_archive`.

- `GET /games` returns `{"items": [{"slug", "default_variant", "launch_date"}]}`: the enabled games
  only. Name, nav order and the default game stay in the frontend registry.
- `GET /games/{slug}/puzzles/today` and `GET /games/{slug}/puzzles/{date}` return the puzzle view.
  `today` is the server's UTC date, and the body names the `date` it resolved to. The frontend
  never computes "today" itself.
- `slug` is an exact match of an enabled game, else 404 `game_not_found`. `variant` is an optional
  query parameter and defaults to the game's `default_variant`; a variant the game does not have
  gives 404 `variant_not_found`. For the game guesser the only variant is its default, named
  `default`.
- `date` is exactly `YYYY-MM-DD` and a real day (`2026-02-30` and `20261102` are not). Otherwise 422
  `validation_error` with `errors: [{"field": "date", "code": "invalid_value", "params": {}}]`.
  Field names in validation errors are bare: no `path.` or `query.` prefix, as for `body`.
- A puzzle that does not exist or is not visible (a draft or other unscheduled status, a future
  date, a date before the game's launch date) gives 404 `puzzle_not_found`. The body is the same in
  every case apart from `request_id`, so a player cannot tell a future puzzle from a missing one.
  The order of the checks is game, variant, puzzle. A puzzle becomes visible at 00:00:00 UTC on its
  date, with no job.

Title search, for the guess box:

- `GET /games/{slug}/titles?q=` returns `{"items": [{"id", "name", "franchise", "year"}]}`: titles
  of the game's title kind whose name or franchise is close to `q`. `franchise` and `year` can be
  `null`. Nothing in an item says whether the title is an answer. The `id` is what a guess sends.
- `q` is required plain text. `%`, `_` and backslashes are ignored like other punctuation; they never act as wildcards. The
  match ignores case, accents and punctuation ("half life" finds "Half-Life 2") and forgives typos
  ("zlda" finds "The Legend of Zelda: Breath of the Wild"). A trimmed `q` under 2 characters, or one
  with fewer than 2 letters or digits after normalization ("a.", "a-"), gives `{"items": []}`; a `q` over 100 characters gives 422
  `validation_error` with `errors: [{"field": "q", "code": "too_long", "params": {"max": 100}}]`.
- Best matches come first: an exact name, then names that start with `q`, then closer matches, then
  by name. At most 200 items, and only real matches: a nonsense `q` gives few or none, never a
  padded list. An unknown or disabled `slug` gives 404 `game_not_found`.

Guessing:

- `POST /games/{slug}/puzzles/{date}/guesses` with the body `{"title_id": 123 | null, "previous":
  [123, null, ...]}` (both fields are required; `title_id: null` is a skip). It answers 200 with the
  full new puzzle view, so no second call is needed. `slug`, `variant` (optional query parameter)
  and `date` follow the same rules and give the same 404s as the view, checked first. The response
  is `private, no-store`. The route needs an allowed `Origin` and a JSON body, like every POST.
- A signed-in account has a stored game: the server keeps its guesses, and the stored game wins.
  `previous` is ignored completely (an account that sends five skips, or anything else, gets the
  same answer as one that sends `[]`), so the client may send `[]`. The new guess is stored before
  the answer, and nothing is stored when the guess is refused. The first stored guess creates the
  game; a view or a resume never does. Two requests of one account for one puzzle at once (two
  tabs) run one after the other, so no guess is lost or repeated. The score, the steps and the
  answer follow the same rules as for a guest, so the same guesses give the same view.
- A guest has no stored game, so the client sends its own earlier guesses in `previous`, in order
  (a skip is `null`), and the server replays them through the same rules as the new guess and
  stores nothing. On the first guess
  `previous` is `[]`.
- The rules: a guess is correct when its title is the answer or has the same normalized name as the
  answer (a duplicate row of the same title counts). A wrong guess whose title and the answer have
  the same normalized franchise gets `result: "franchise"`; a title or answer with no franchise
  never matches, and a skip never gets it. Results are `correct`, `franchise`, `wrong` and
  `skipped`. A correct guess sets `status: "won"`; the sixth guess or skip that is not correct sets
  `"lost"`. The score is `guesses_used`, skips included. Only when the game ends does the view
  carry `answer` and the `source_url` of every step.
- `counts_for_streak`: on a guest's first guess (`previous` empty) it is `true` when the server's
  UTC date equals the puzzle's date and `false` otherwise (an archive play). On every later request
  it is `null`: the browser keeps the first value. For an account the server sets it once, when the
  first guess is stored, from the server's UTC date at that moment, and never changes it: a game
  begun at 23:59 and finished after midnight still counts as a daily play. Every response for an
  account that has a stored game carries the stored value; with no stored game it is `null`.
- Errors, in the order the server checks them: first 422 `validation_error` for a malformed body
  (FastAPI validates the body before the route runs), then the 404s of the view, then 422
  `invalid_guess_history` when `previous` has more than 5 entries, has a title that does not exist, repeats a title, or has an entry after a correct guess;
  409 `puzzle_already_finished` when `previous` already ends the game (its last entry is correct),
  whatever `title_id` is; 422 `title_not_found` when `title_id` is not a title of the game's kind;
  422 `duplicate_guess` when `title_id`, or a title with the same normalized name, is already in `previous`. A refused guess uses no guess. A
  body that is not that shape (a missing field, a string id, more than 20 entries in `previous`)
  is 422 `validation_error` with the field name (`title_id`, `previous`, or `previous.0`).
- For an account the same checks run in the same order, except that there is no history to check:
  `invalid_guess_history` never happens, because `previous` is not read. 409
  `puzzle_already_finished` means its stored game is already won or lost, and `duplicate_guess`
  means the title (or one with the same normalized name) is already among its stored guesses.
- An account guess can also get 503 `service_unavailable` when its stored game is busy (another
  request for the same game held it for more than 5 seconds). Nothing was stored, so the client may
  retry the same guess.

Resume:

- `POST /games/{slug}/puzzles/{date}/resume` with the body `{"previous": [123, null, ...]}` shows a
  game again after a reload and changes nothing. It answers 200 with the full puzzle view and
  `private, no-store`. `slug`, `variant` and `date` follow the same rules and give the same 404s
  as the view, checked first, then the body: a malformed body is 422 `validation_error` (the
  field is `previous`, or `previous.0`; more than 20 entries is `too_long`).
- A signed-in account gets its stored game, and `previous` is ignored: `[]` is fine. An account
  with no stored game gets the empty game.
- A guest sends its own list in `previous`, in order, and gets the replay. It may hold up to 6
  entries, because it can be a whole lost game (a guess accepts at most 5). More than 6 entries, a
  title that does not exist, a repeated title, or an entry after a correct guess is 422
  `invalid_guess_history`. A replay that ends the game (a correct guess, or six entries that
  were not correct) returns the finished view, with the answer and every step's `source_url`.
  For a guest `counts_for_streak` is `null`.
- The response's `signed_in` says which case ran. A guess or resume answered with `signed_in:
  false` is a guest result: nothing was stored, so a client that still shows a user must switch to
  signed out (as for a 401) and keep its own guess list.

Stats and streak:

- `GET /games/{slug}/stats?variant=` needs a signed-in account. A guest gets 401
  `not_authenticated`, even for an unknown `slug`. It answers 200 with `{"played", "wins",
  "current_streak", "max_streak", "distribution"}` and `private, no-store`. `slug` and `variant`
  (optional, default: the game's default variant) follow the same rules as the view and give 404
  `game_not_found` or `variant_not_found`. The win rate is the client's to compute from `wins` and
  `played`.
- `distribution` is an object with the keys `"1"` to `"6"` (JSON keys are strings), each the number
  of wins in that many guesses, zeros included. A skip counts as a guess.
- `played` counts finished games (won or lost), daily and archive alike. A game in progress counts
  for nothing.
- Only games on puzzles that are still visible count, as in the archive: a puzzle later moved back
  to draft, or now before the game's launch date, drops out of every field. A stored win with an
  impossible guess count (outside 1 to 6) still counts in `played`, `wins` and the streak but has no
  `distribution` bucket; the server logs a warning, never an error response (spec row T4).
- A day counts for the streak when the game on that day's puzzle is finished (won or lost), its
  `counts_for_streak` is true and the variant is the default. The streak day is the puzzle's date,
  not the day it was finished. An archive play never fills a day.
- The streak rule: walk the streak days in order. A gap of 1 to 3 missed days keeps the run and adds
  nothing to it; a gap of 4 or more starts a new run at 1. `current_streak` is the last run's length
  while at most 3 days were missed since the last streak day, not counting today (today is not
  missed until it is over), and 0 otherwise. `max_streak` is the longest run.
- For a variant other than the default, `current_streak` and `max_streak` are `null`; the other
  fields count that variant's own games.
- Stats are computed on every read from the stored games, never stored. They are the server's
  numbers for an account; a guest has no stats route, so the browser computes its own from its
  local history.
- Shared test vectors: the tables S1 to S19 (streak) and T1 to T4 (counters) in SPEC-02 (AC-52,
  AC-54, `specs/02-phase-1-backend-core-games.md`). The backend tests use their ids
  (`tests/test_stats_rules.py`), and the frontend's guest stats must pass the same rows with the
  same ids.

Merge of a guest's local games:

- `POST /games/{slug}/progress/merge` with `{"entries": [{"date", "variant", "guesses",
  "played_as_daily", "daily_proof"}]}` moves the games a guest played in this browser into the signed-in account.
  A guest gets 401 `not_authenticated`. `slug` gives 404 `game_not_found` for the whole request. It
  answers 200 with `{"stored", "already_present", "rejected", "daily_unproven",
  "rejected_entries": [{"date", "variant", "code"}]}` and `private, no-store`. The route needs an allowed `Origin` and a JSON body,
  like every POST.
- When to call it: once, right after the guest signs in or registers, with the local history of the
  game. Send the entries in chunks of at most 500 (more is 422 `validation_error` with
  `errors: [{"field": "entries", "code": "too_long", "params": {"max": 500}}]`, and nothing is
  stored). Clear the local games only after every chunk answered 200.
- An entry is `date` (`YYYY-MM-DD`, strict like the puzzle `date`), `variant` (the game's variant
  name, at most 32 characters), `guesses` (the whole game in order, `null` for a skip: a title id
  or `null`, at most 20 items in the body, and a game has 1 to 6) and `played_as_daily` (a boolean,
  true when the guest began that puzzle on its own day) and `daily_proof` (the string the server put in
  the guest's view of that puzzle on its own day, or `null`; at most 100 characters). There is no outcome field: the server
  replays `guesses` through the same rules as a guess and decides won, lost or in progress. Extra
  fields are ignored. A malformed entry (a bad date, a non-boolean flag, more than 20 guesses)
  is 422 `validation_error` for the whole request, with the field `entries.<index>.<name>`.
- The server stores each good entry as the account's game on that puzzle with `origin: merge`. Its
  `counts_for_streak` is true only when `played_as_daily` is true AND `daily_proof` is the server's
  proof for that game, variant and date. With a missing or wrong proof the entry is still stored, as
  an archive play (`counts_for_streak: false`), and counted in `daily_unproven` (which is not part of
  the sum below). A finished game counts in the stats like any other; one that is still in progress can be
  continued with the guess route. The stored times are the time of the request.
- Each entry is checked in this order, and the first failing check decides. 1) It has 1 to 6
  guesses, else `invalid_guess_history`. 2) Its variant exists, else `variant_not_found`. 3) Its
  puzzle exists and is visible, else `puzzle_not_found` (a draft, the future, before the launch
  date, no puzzle that day). 4) If the account already has a game on that puzzle, the entry is
  counted in `already_present` without being replayed, valid or not, and the account's game is not
  changed: the account wins. 5) Its guesses replay as a game, else `invalid_guess_history` (an
  unknown title, a repeated title, or a guess after the game ended). A rejected entry is listed in
  `rejected_entries`, in request order, with its `date`, `variant` and one `code`; the other
  entries still merge. When one request has two
  entries for the same date and variant, the first that passes every check is stored and any later
  one counts as `already_present`.
- `stored + already_present + rejected` is the number of entries sent.
- Safe to retry: sending the same request again stores nothing new and leaves the stats as they
  were (every entry whose puzzle the account now has a game on counts as `already_present`, including one
  that was rejected the first time because another entry for the same puzzle was stored; the rest
  are rejected again with the same code),
  so the client may retry after a network error or send chunks in any number of requests.
- A merge can also get 503 `service_unavailable` when a game of the account was busy for more than
  5 seconds, or when two merges of the same account collided. Nothing was stored, so the same request may be sent again.

Archive:

- `GET /games/{slug}/archive?variant=&before=&limit=` (`games_list_archive`) lists the visible past
  puzzles of the game, newest first, as `{"items": [{"date", "number", "state", "guesses_used"}],
  "next_before"}`. Like every game route it works for a guest with no cookie. `private, no-store`.
- `slug` and `variant` follow the same rules and give the same 404s as the view (`game_not_found`,
  `variant_not_found`). There is no `puzzle_not_found`: a day with no visible puzzle (a gap, a
  draft, a day before the launch date) is simply not in the list. Nothing in an item is an answer.
- `before` is a day (`YYYY-MM-DD`, strict like `date`), and only days strictly before it are listed.
  It defaults to today, and a later value is treated as today, so today and the future are never
  listed: today's puzzle is played through `/puzzles/today`. A bad `before` is 422
  `validation_error` with `field: "before"` (code `invalid_value`).
- `limit` is 1 to 100 and defaults to 30. Outside that, or not a number, it is 422
  `validation_error` with `field: "limit"` and code `too_small` (`params: {"min": 1}`),
  `too_large` (`params: {"max": 100}`) or `invalid_type` (not a number).
- `next_before` is the date of the last item when more puzzles follow, else `null` (also `null`
  when the page is exactly the last one). To read the next page, send it back as `before`, with the
  same `variant` and `limit`. Dates are unique per game and variant, so no puzzle repeats or is
  skipped between pages.
- `number` is the same number the puzzle view shows (days since the game's launch date, plus 1).
- A guest gets `state: null` and `guesses_used: null`: its progress is in the browser, which fills
  both in. An account gets `state`, one of `not_played`, `in_progress`, `won`, `lost`, from the
  server's stored game, and `guesses_used`, the number of stored guesses with skips counted (`0`
  for `not_played`). It sees only its own games.
- A past puzzle is played through the same view, resume and guess routes as today's. Its
  `counts_for_streak` is `false`, because the server's UTC date is not the puzzle's date. A finished
  archive play counts in the stats (`played`, `wins`, `distribution`) but never fills a streak day
  (see "Stats and streak").

The view (`type: "game_guesser"` tags it, so later games can add other types):

- `type`, `slug`, `variant`, `date`, `number` (days since the game's launch date, plus 1), `status`
  (`in_progress`, `won`, `lost`), `max_guesses` (6), `guesses_used`, `guesses_left`, `guesses`
  (each `title_id`, `name`, `result`; a skip has null `title_id` and `name`), `steps`, `answer`,
  `counts_for_streak`, `signed_in` and `daily_proof`.
- `steps` holds only the steps earned so far: steps 1 to `guesses_used + 1` while the game is in
  progress, all six at the end. Each step is `step`, `hint` (`{"kind", "value"}`, or `null` when the
  step has no hint), `media` (see "Clue media") and `source_url` (`null` until the game ends).
- `source_url`, once the game has ended, is the game's page on igdb.com
  (`https://www.igdb.com/games/<slug>`) for every clue made from IGDB screenshots, the clip
  included. It is a plain link the frontend shows as a source; it never carries a signed link.
- `hint.kind` is a free string. The kinds today are `critic_score` (IGDB's aggregated critic score,
  a whole number, shown only when at least 4 critic scores back it), `platform`, `genre`, `year` and
  `developer`. `metacritic_score` is no longer produced. The frontend shows any other kind under a
  generic "Hint" label, so a new kind stays visible with no frontend change and only needs a label
  to read well. `hint.value` is English (decision 32).
- `answer` is `null` until the game ends, then `{"title_id", "name", "franchise", "year"}`. The
  response holds no internal puzzle or progress id.
- `counts_for_streak` is `null` for a guest on every read and after its first guess (see
  "Guessing"). For an account it is the value stored with its game, or `null` before the first
  guess.
- `signed_in` is true when the request has a valid session. A game response with `signed_in: false`
  while the frontend shows a user means the session ended; the frontend switches to signed out, as
  for a 401.
- `daily_proof` is a string only in a guest's view of a puzzle on that puzzle's own UTC day (the
  view, today's view, a guess or a resume); otherwise `null`, and always `null` for an account. The
  browser keeps it with the local game and sends it back on merge, so the merged game can count for
  the streak. It does not expire and is not tied to a session.

Clue media:

- Each step in `steps` has `media`: `type` (`image` or `video`), `width`, `height`, `expires_at`,
  `sources` and `poster`. Step 6 of the game guesser is a `video`; steps 1 to 5 are `image`.
- `sources` is a list of `{"url", "content_type"}`. Use it in order: take the first one the browser
  can play. A video lists the WebM file first when there is one, and the MP4 file is always last. An
  image has one entry (`image/webp`). `width` and `height` are those of the last (MP4) source.
- `poster` is `{"url", "content_type", "expires_at"}`, the still frame of a video (`image/webp`),
  and `null` for an image.
- Every URL is absolute and used as it is: do not prefix it, add a header or send a cookie. It loads
  as an `<img>` or `<video>` source. In dev with local storage it is
  `http://localhost:5173/api/v1/media/<key>?exp=...&sig=...`, so it goes through the Vite proxy;
  with S3 storage it points at the bucket (the CSP of M1-40 needs `media-src` and `img-src` for the
  bucket's origin).
- Links exist only for steps the player has earned, on a visible puzzle. A step that is not earned
  has no link and no key anywhere in the response, and neither has the poster of an unearned video.
  Every earned step is signed, step 1 included.
- Links expire. Images and posters live 600 seconds by default (allowed 60 to 3600); a video lives
  3600 seconds (allowed 600 to 86400), because the browser asks for new parts of a looping clip for
  as long as it plays, and each request is checked. `expires_at` says when. A link is a bearer link:
  anyone who has it can open it until it expires.
- Refetch on failure: when a media request answers 403 or fails after `expires_at`, ask for the
  view again (the puzzle route, or resume) and swap in the new links.
- The key in a link is the file's SHA-256, never built from the date, game, step or answer.

The local media route (`MEDIA_STORAGE=local`: development, tests, and production if the S3 check
fails) is `GET` and `HEAD /v1/media/{key}?exp=<unix seconds>&sig=<signature>`. It is not in the
OpenAPI document and the frontend never calls it through the generated client; it only loads
the links above.

- Checked in this order: the key (64 lowercase hex digits), the signature and the expiry, then the
  puzzle the file belongs to, then `Range`. A bad key, a wrong signature or an expired link is 403
  `invalid_media_link`, which says nothing about the file. A file of a puzzle that is not visible
  (for example unscheduled after the link was issued) is 404 `puzzle_not_found`. The signature and
  the expiry are checked on every request, a ranged one too.
- A full answer is 200 with `Accept-Ranges: bytes`, the stored content type (`image/webp`,
  `video/mp4` or `video/webm`, never guessed), `X-Content-Type-Options: nosniff` and
  `Cache-Control: private, max-age=<seconds the link has left>`. Its 403, 404 and 416 also carry
  `nosniff`.
- Ranges: one valid `Range` gets 206 with `Content-Range` and only those bytes (`bytes=0-1`,
  `bytes=100-` and `bytes=-500` all work, and an end past the file is cut to its last byte). A
  `Range` that is malformed, or lies outside the file, gets 416 `range_not_satisfiable` with
  `Content-Range: bytes */<size>`. Several ranges get the whole file with 200, not
  `multipart/byteranges`. A unit other than `bytes` is ignored (200 with the whole file, RFC 9110
  section 14.2), and empty list elements such as `bytes=0-1,` are accepted (section 5.6.1). Only a
  `<video>` element sees a 416, so the frontend has no text for it.
- With `MEDIA_STORAGE=s3` the links point at the bucket and the route answers 403 to everything.
  A bucket link cannot add `X-Content-Type-Options`; the stored content type comes from the upload.
  A bucket response carries `Cache-Control: private` and an `Expires` equal to the link's expiry,
  so a browser never caches it past the link's lifetime.

Limits for the files of a clue (AC-74b; the puzzle builder, M1-22, enforces them and may change them,
and this table is then updated):

1 MB in this table means 1,048,576 bytes (decision 70).

| File | Content type | Codec and tracks | Duration | Size in pixels | Size in bytes |
|---|---|---|---|---|---|
| Video | `video/mp4` (required), `video/webm` (optional copy) | H.264 for MP4; no audio track | 8 to 15 seconds | at most 1280 by 720 | at most 4 MB |
| Image, poster | `image/webp` | | | at most 1920 by 1080 | at most 1 MB |

A clue has these files (AC-13b): an image clue has one image and no poster; a video clue has one MP4,
at most one WebM and one poster. If a visible puzzle breaks this, the view is 500 `internal_error`.

Caching (`Cache-Control`):

| Response | Value |
|---|---|
| `GET /games` | `public, max-age=300` |
| `GET /games/{slug}/titles` | `public, max-age=300` |
| puzzle view (`today` and dated) | `private, no-store` |
| `POST /games/{slug}/puzzles/{date}/guesses` | `private, no-store` |
| `POST /games/{slug}/puzzles/{date}/resume` | `private, no-store` |
| `POST /games/{slug}/progress/merge` | `private, no-store` |
| `GET /games/{slug}/archive` | `private, no-store` |
| `GET /games/{slug}/stats` | `private, no-store` |
| `GET` and `HEAD /v1/media/{key}`, 200 and 206 | `private, max-age=<seconds the link has left>` |
| any error response, including every 404 | `no-store` |

## Health

- `GET /healthz` (liveness, no dependencies) and `GET /readyz` (Postgres and Redis; `503` with
  `code: "service_unavailable"` and `params.failed` listing what is down). They are not part of the
  app's API: the proxy must not expose them publicly.

## Clock

- `GET /v1/clock` returns `{ now, today, next_reset }`: the server's UTC time, the UTC date and the
  next 00:00 UTC. It touches no database and sends `Cache-Control: no-store`.
- Display only. The frontend may use the offset between `now` and the device clock to draw a
  countdown to `next_reset`. The server alone decides what "today" is for visibility, streak flags
  and the archive; the client never decides it from its own clock.

## API types

- The frontend generates its API client and types from the backend's OpenAPI snapshot with Orval
  (`npm run api:generate`); the generated code is committed under `my-list-fe/src/api/generated/`.
  Do not hand-write types for backend models.
- Two checks keep the sides in step: the backend's CI fails when `openapi/openapi.json` is stale or
  has a breaking change against `main` (unless the pull request has the `breaking-change` label);
  the frontend's CI regenerates the code from the backend's `main` snapshot and fails when it
  differs from what is committed.
- A boundary change is therefore: change the backend, rewrite the snapshot, merge it (label
  `breaking-change` if it breaks clients), then regenerate and commit in the frontend in the same
  pass. When backend schemas change shape, regenerate; do not hand-patch types.
- The snapshot's `info.title` is "Daily Game Challenge API". Orval copies it into the header of every
  generated file, so changing it is a non-breaking boundary change: merge the backend snapshot first,
  then regenerate the frontend client.

## Keeping this file in sync

- Treat this file as the seam contract, not documentation of either repo's
  internals — keep entries short and point back to the owning repo's `CLAUDE.md`
  for detail.
- When editing something listed here, update this file before/alongside the code
  change, not as an afterthought.
