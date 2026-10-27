# MyList: Frontend/Backend Contracts

Shared reference for `my-list-fe` and `my-list-be`. Anything here must stay true on
both sides — when one repo's Claude session changes one of these, update this file
in the same session and flag it to the other repo's session (message it directly if
a Claude Code session is running there, e.g. `SendMessage` by session name from
`ListAgents`).

Each repo's `CLAUDE.md` links here under "Related"; this file doesn't duplicate
repo-internal detail (stack choices, file layout) — only the seams between the two.

## API base and routing

- Backend serves on `http://localhost:8000`, no `/api` prefix (`/auth/login`, not
  `/api/auth/login`).
- Frontend calls `/api/...`; Vite's dev proxy strips `/api` and forwards to the
  backend. This keeps a stable frontend-facing path independent of backend mounting.
- Frontend dev server: `http://localhost:5173`. Backend CORS allows this origin.

## Auth

- Session-cookie auth (Django-auth style), not JWT. Backend sets an httpOnly,
  `SameSite=Lax` cookie named `session_id` on `POST /auth/register` and
  `POST /auth/login` (register auto-logs-in). Session data lives in Redis
  (`session:{opaque token}` → user id), no Postgres sessions table.
- `GET /auth/me` returns the current user; frontend calls this in its root route's
  `beforeLoad` to rehydrate client auth state on every fresh page load.
- `POST /auth/logout` deletes the Redis key and clears the cookie.
- **Cookie host-scoping gotcha**: the cookie is host-scoped, so frontend must reach
  the backend via `http://localhost:8000`, not `127.0.0.1:8000` — otherwise the
  cookie won't round-trip to `http://localhost:5173`.
- No CSRF protection exists yet (backend gap, judged sufficient for now via
  `SameSite=Lax` since there's currently one mutating domain). Not something the
  frontend compensates for — revisit together once more mutating routes land
  (`items`).
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
  is logged (the link is an account-takeover token).
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
- Not yet implemented: there's no rate limiting on `forgot-password` — a known gap,
  not something to imply otherwise in frontend UX copy.

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
  `method_not_allowed` (405), `service_unavailable` (503), `internal_error` (500).
- Every response carries `X-Request-ID` (the proxy's value if well formed, else generated) and the
  same id is in the body as `request_id`; the frontend shows it on its error screen.
- The frontend's `ApiError` mirrors this (`status`, `code`, `params`, `requestId`, `fieldErrors`) and
  shows texts looked up by `code`; a response without a JSON body (a proxy error page) becomes
  `code: "http_error"`, and no response at all becomes `status: 0, code: "network_error"`.
- Success bodies are unchanged. The `202` of `forgot-password` still returns `{"detail": "..."}`.

## Health

- `GET /healthz` (liveness, no dependencies) and `GET /readyz` (Postgres and Redis; `503` with
  `code: "service_unavailable"` and `params.failed` listing what is down). They are not part of the
  app's API: the proxy must not expose them publicly.

## API types

- Frontend generates types from the backend's OpenAPI spec via Orval — not
  hand-written. (Not set up yet: until it is, the auth types in the frontend are hand-written.) If a frontend type or Zod schema looks like it duplicates a backend
  Pydantic model, it should be generated instead.
- When backend schemas change shape, regenerate frontend types from the updated
  OpenAPI spec in the same pass, rather than hand-patching frontend types.

## Keeping this file in sync

- Treat this file as the seam contract, not documentation of either repo's
  internals — keep entries short and point back to the owning repo's `CLAUDE.md`
  for detail.
- When editing something listed here, update this file before/alongside the code
  change, not as an afterthought.
