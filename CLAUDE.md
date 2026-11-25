# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Workspace layout

This folder is the small platform repo, published as the umbrella repo `oleksandr-shvab/daily-game-challenge` (its `.gitignore` excludes the two app folders; `README.md` is the public front page). On GitHub the app repos are `daily-game-challenge-be` and `daily-game-challenge-fe`; locally they keep the folder names below, which Compose, scripts and CI paths rely on. It holds two independent repos, each with its own `.git`, `CLAUDE.md` and `.claude/` (settings and skills), plus the files that tie them together:

- `my-list-be/` — FastAPI backend (Python 3.12, uv with `pyproject.toml` and `uv.lock`, Postgres, Redis). Commands and architecture: `my-list-be/CLAUDE.md`.
- `my-list-fe/` — Vite + React + TypeScript SPA (TanStack Router/Query, Zustand, axios). Commands and architecture: `my-list-fe/CLAUDE.md`.
- `CONTRACTS.md` — the FE/BE seam: API routing, auth cookie, password flows, errors, health endpoints, OpenAPI types.
- `SPEC.md` — the product and game spec; `ARCHITECTURE.md` — the technical decisions for running it in production.
- `compose.prod.yml` — the production stack (Caddy with the built SPA, API, one-shot migration, Postgres, Redis). `compose.admin.yml` — an override that publishes Postgres on `127.0.0.1:5434` only. `deploy/` — `localhost.vars` (dummy values for the local run), `production.vars.example` (placeholders), `smoke.sh` (12 checks against a running stack), `check-vars.sh` (refuses a vars file with placeholders). `docs/runbooks/launch.md` — the launch runbook: trying the stack locally, and every step that needs a server or a domain.

Run commands from inside the repo they belong to (`cd my-list-be && uv run pytest`, `cd my-list-fe && npm run dev`). Run `git` inside the repo a change belongs to; run it from this folder only for the specs and `CONTRACTS.md`. Repo-internal rules live in the repo `CLAUDE.md` files and are not repeated here.

## Working across both repos

- Read `CONTRACTS.md` before any change that touches the FE/BE boundary: endpoints, request/response shapes, status codes, auth/cookie behavior, error format.
- A boundary change is one task covering both repos: update the backend, the frontend and `CONTRACTS.md` in the same pass. Do not leave one side for later.
- Frontend API types are generated from the backend OpenAPI spec (Orval). After a backend schema change, regenerate them; do not hand-patch types.
- Dev runs both servers: backend on `http://localhost:8000`, frontend on `http://localhost:5173`. The frontend calls `/api/...` and Vite's proxy strips `/api`. Always use `localhost`, not `127.0.0.1`, because the session cookie is host-scoped.
- The parent `CONTRACTS.md` wording about messaging another repo's session (`SendMessage`, `ListAgents`) is for the case where each repo runs in its own window. When working from this folder, make both edits yourself.

## Production-like run on this laptop

The whole site runs from Compose at `https://dgc.localhost` with `ENVIRONMENT=production`. It is a separate host from the dev server, so its Secure cookie and HSTS never touch `localhost:5173`. The vars file holds dummy values only. Never deploy `deploy/localhost.vars`.

```bash
mkdir -p var/prod-media
docker compose -f compose.prod.yml -f compose.admin.yml --env-file deploy/localhost.vars up -d --build
docker compose -f compose.prod.yml --env-file deploy/localhost.vars ps -a   # all healthy, migrate exited 0
# seed, from my-list-be (values from deploy/localhost.vars; the seed refuses anything but ENVIRONMENT=local):
CI= ENVIRONMENT=local DATABASE_URL=postgresql+asyncpg://dgc:<POSTGRES_PASSWORD>@localhost:5434/daily_game_challenge \
  SECRET_KEY=<SECRET_KEY> MEDIA_STORAGE=local MEDIA_LOCAL_DIR="<abs path of this folder>/var/prod-media" \
  uv run --no-sync python scripts/seed_dev.py
deploy/smoke.sh                                                              # ok 1 to ok 12
docker compose -f compose.prod.yml --env-file deploy/localhost.vars down     # add -v to drop the data
```

- The plain-http port is published on 8080 (`HTTP_PORT` in the vars file), because port 80 is often taken on a laptop. The redirect still says `https://dgc.localhost/`: Caddy's `http_port` and `https_port` options are for the server's inside, and do not change the `Location` header. Keep `HTTPS_PORT` at 443.
- Browsers send `*.localhost` to loopback by themselves. Caddy signs the certificate with its own local CA: accept the warning once, or import `/data/caddy/pki/authorities/local/root.crt` from the `web` container (`docker compose cp web:/data/caddy/pki/authorities/local/root.crt .`).
- Check 12 stops the backend for a few seconds to get a 502 from Caddy. Checks 9 and 10 send one login and one register, which the backend's per-IP limits count (every local request comes from the Docker gateway address). On a 429 they print `skip` with the Retry-After value, not a failure. To rerun sooner, `docker compose -f compose.prod.yml --env-file deploy/localhost.vars exec redis redis-cli flushall`.
- Media files must be readable by uid 10001 (the backend container). The writer now stores 0644 files. Files promoted with an older backend are 0600: run `chmod -R a+rX var/prod-media` (and the same on a server's media folder).
- Before a server's first start, run `deploy/check-vars.sh <vars file>`: it refuses CHANGE_ME values and the dummy local secrets.
- Changing `my-list-fe/deploy/Caddyfile` needs `up -d --build web`.
