# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Workspace layout

This folder is the small platform repo (its `.gitignore` excludes the two app folders). It holds two independent repos, each with its own `.git`, `CLAUDE.md` and `.claude/` (settings and skills), plus the files that tie them together:

- `my-list-be/` — FastAPI backend (Python 3.12, uv with `pyproject.toml` and `uv.lock`, Postgres, Redis). Commands and architecture: `my-list-be/CLAUDE.md`.
- `my-list-fe/` — Vite + React + TypeScript SPA (TanStack Router/Query, Zustand, axios). Commands and architecture: `my-list-fe/CLAUDE.md`.
- `CONTRACTS.md` — the FE/BE seam: API routing, auth cookie, password flows, errors, health endpoints, OpenAPI types.
- `SPEC.md` — the product and game spec; `ARCHITECTURE.md` — the technical decisions for running it in production.

Run commands from inside the repo they belong to (`cd my-list-be && uv run pytest`, `cd my-list-fe && npm run dev`). Run `git` inside the repo a change belongs to; run it from this folder only for the specs and `CONTRACTS.md`. Repo-internal rules live in the repo `CLAUDE.md` files and are not repeated here.

## Working across both repos

- Read `CONTRACTS.md` before any change that touches the FE/BE boundary: endpoints, request/response shapes, status codes, auth/cookie behavior, error format.
- A boundary change is one task covering both repos: update the backend, the frontend and `CONTRACTS.md` in the same pass. Do not leave one side for later.
- Frontend API types are generated from the backend OpenAPI spec (Orval). After a backend schema change, regenerate them; do not hand-patch types.
- Dev runs both servers: backend on `http://localhost:8000`, frontend on `http://localhost:5173`. The frontend calls `/api/...` and Vite's proxy strips `/api`. Always use `localhost`, not `127.0.0.1`, because the session cookie is host-scoped.
- The parent `CONTRACTS.md` wording about messaging another repo's session (`SendMessage`, `ListAgents`) is for the case where each repo runs in its own window. When working from this folder, make both edits yourself.
