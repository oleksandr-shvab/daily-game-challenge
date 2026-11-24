# Launch runbook

Nothing here has been run against a server. Milestone 1 finished locally (SPEC decision 81), so every step that needs a server, a domain or an outside account is written down here instead. Steps marked **(owner)** need your accounts or your decision. Commands run from the platform repo (`MyList project/`) unless a step says otherwise. `<domain>` and `<server>` stand for the real values.

Parts: A try it on this laptop, B what you need, C first start, D content, E backups and updates, F the hosting checklist, G before a real public launch.

## A. Try it on this laptop

1. Start the stack, seed it and run the smoke checks. The commands are in the platform `CLAUDE.md`, section "Production-like run on this laptop".
   ```bash
   mkdir -p var/prod-media
   docker compose -f compose.prod.yml -f compose.admin.yml --env-file deploy/localhost.vars up -d --build
   deploy/smoke.sh        # ok 1 to ok 12
   ```
2. Open `https://dgc.localhost`. Accept the certificate warning once, or trust Caddy's local root:
   ```bash
   docker compose -f compose.prod.yml --env-file deploy/localhost.vars cp web:/data/caddy/pki/authorities/local/root.crt .
   ```
   Import `root.crt` into the browser's certificate authorities. Delete the file afterwards.
3. Without seeded content the page loads, but the game list is empty and smoke check 11 fails with "seed the stack first".
4. Stop with `... down`. Add `-v` to also drop the data. If you ever started a stack with a throwaway Postgres password, `down -v` is the only way to change it (see C2).

## B. What a launch needs

1. **(owner)** One x86 VPS with 2 vCPU and 4 GB. ARM (for example Hetzner CAX) needs a test build of both images first, because npm can miss platform-specific packages on musl and arm.
2. **(owner)** A domain at a registrar with 2FA on the account. Point an A record at the server. Add an AAAA record only if the server gives the `edge` network real IPv6 (B5).
3. On the server:
   - firewall open for 22, 80 and 443 (and 443/udp) only. Docker publishes ports past ufw, which is why only `web` publishes anything;
   - key-only SSH, automatic security updates;
   - Docker Engine with the Compose plugin.
4. DNS hygiene (plan 07, O-1 to O-4), **(owner)**:
   - O-1: DNSSEC at the registrar if it offers it. A CAA record: `0 issue "letsencrypt.org"` (add ZeroSSL only if you keep Caddy's fallback).
   - O-2: until email exists, `v=spf1 -all` on the apex and a `_dmarc` record with `p=reject`, so nobody can send as the domain. Step F3 replaces this for the sending subdomain.
   - O-3: keep a list of DNS records. Delete a CNAME before deleting what it points at. No wildcard records.
   - O-4: in GitHub, turn on secret scanning with push protection and Dependabot alerts on both app repos.
5. IPv6. `compose.prod.yml` sets `enable_ipv6: true` on the `edge` network, so the backend sees each IPv6 visitor's own address. If the server cannot give it IPv6, change that line to `edge: {}` and publish no AAAA record. Otherwise every IPv6 visitor shares one address, and one per-IP rate-limit bucket.
6. Leave `HTTPS_PORT=443` in the vars file. Caddy's redirect does not carry another port, so a different value breaks the http to https redirect.

## C. First start

1. Clone the three repos side by side on the server (`my-list-be`, `my-list-fe`, and the platform repo; the platform repo has no remote, so `rsync` or `scp` it up). Build happens on the server for now.
2. Make the vars file. It lives outside the repo, root-owned, mode 600:
   ```bash
   sudo install -d -m 700 /etc/dgc
   sudo install -m 600 deploy/production.vars.example /etc/dgc/production.vars
   openssl rand -hex 32      # once each for POSTGRES_PASSWORD, SECRET_KEY, MEDIA_SIGNING_KEY (all different)
   sudoedit /etc/dgc/production.vars
   ```
   Set `SITE_ADDRESS=<domain>`, `FRONTEND_URL=https://<domain>`, `MEDIA_LOCAL_BASE_URL=https://<domain>/api`, `ACME_EMAIL`. Never reuse `deploy/localhost.vars`.
3. Check the file: `deploy/check-vars.sh /etc/dgc/production.vars`. It refuses any `CHANGE_ME` and the dummy local secrets. The backend does not look at `POSTGRES_PASSWORD` or `SITE_ADDRESS`, so this is the only check on them.
4. `POSTGRES_PASSWORD` is used only when Postgres first creates its data folder. If the stack ever started with `CHANGE_ME` or another throwaway password, run `docker compose -f compose.prod.yml --env-file /etc/dgc/production.vars down -v` before the real first start. Changing the file later changes nothing inside the database.
5. Preflight. The backend refuses to start in `production` on a weak or placeholder secret, a non-https `FRONTEND_URL` or `MEDIA_LOCAL_BASE_URL`, a localhost CORS origin, and a media key that is weak or equal to `SECRET_KEY`:
   ```bash
   docker compose -f compose.prod.yml --env-file /etc/dgc/production.vars run --rm --no-deps backend \
     python -c "from app.core.config import settings; print('ok', settings.ENVIRONMENT)"
   ```
   It prints `ok production`, or the refusals. It does not check the Postgres password's strength, Redis, or that DNS points at this server.
6. Make the media folder readable by the container (uid 10001). Clue files written before backend PR #37 are mode 0600:
   ```bash
   sudo mkdir -p /srv/dgc/media && sudo chmod -R a+rX /srv/dgc/media
   ```
   Put `MEDIA_HOST_DIR=/srv/dgc/media` in the vars file. Without it Compose uses `./var/prod-media`.
7. Start. Include `compose.admin.yml` so Postgres listens on the server's loopback for D1 (it never listens on a public address):
   ```bash
   docker compose -f compose.prod.yml -f compose.admin.yml --env-file /etc/dgc/production.vars up -d --build
   docker compose -f compose.prod.yml --env-file /etc/dgc/production.vars ps -a   # all healthy, migrate exited 0
   ```
   Caddy asks Let's Encrypt for a certificate on the first request. DNS must already point at the server, and ports 80 and 443 must be reachable.
8. Smoke checks against the real domain:
   ```bash
   SKIP_CHECKS="11" deploy/smoke.sh --system-ca <domain>
   ```
   `--system-ca` uses the system's certificate store and skips check 10 (it would leave a test account) and check 12 (it stops the backend). Check 11 needs a scheduled puzzle: drop it from `SKIP_CHECKS` after step D.
9. HSTS. The Caddyfile sends `max-age=31536000` only, because a domain you had not set could not carry `includeSubDomains`. Now that the domain is set, edit `my-list-fe/deploy/Caddyfile`: `Strict-Transport-Security "max-age=31536000; includeSubDomains"`, then `up -d --build web`. Add `preload` only after the site has run a few weeks on HTTPS, because it is slow to undo.

## D. Content: promote and schedule from the workstation

Order follows `my-list-be/CLAUDE.md` ("Promote and game settings"). The scripts run on the workstation against the server's Postgres through an SSH tunnel.

1. Open the tunnel (keep it running). Port 15434 avoids the local stack's 5434:
   ```bash
   ssh -N -L 15434:127.0.0.1:5434 <user>@<server>
   ```
2. In the shell you run the scripts from, not in the workstation `.env`, set the production values: `ENVIRONMENT=production`, `DATABASE_URL=postgresql+asyncpg://dgc:<POSTGRES_PASSWORD>@localhost:15434/daily_game_challenge`, and the same `SECRET_KEY`, `MEDIA_SIGNING_KEY`, `FRONTEND_URL`, `MEDIA_LOCAL_BASE_URL` and `BACKEND_CORS_ORIGINS=[]` as the vars file. The settings validation runs on import and refuses a non-production value. Set `MEDIA_LOCAL_DIR` to a mirror folder of the workstation (for example `~/dgc-media-mirror`).
3. From `my-list-be`, on the target:
   ```bash
   uv run python scripts/import_titles.py --target production --confirm-target production
   uv run python scripts/manage_game.py --target production --confirm-target production --launch-date <YYYY-MM-DD> --enable
   ```
4. **(owner) IGDB image gate.** Decision 73 allows IGDB screenshots for the learning project and says it is revisited before any real public launch. While `IGDB_IMAGES_CLEARED_BY` is empty, promote refuses every non-local target. Before setting it, record the review as a new SPEC decision (IGDB's written yes, or your written acceptance of the risk), and make the value name that decision.
5. Promote the approved puzzles (rows and files; files go to the mirror), then schedule:
   ```bash
   uv run python scripts/promote_puzzles.py --target production --confirm-target production \
     --source-database-url postgresql+asyncpg://user:pass@localhost:5433/daily_game_challenge_content \
     --source-media-dir var/content-media
   uv run python scripts/schedule_puzzles.py --target production --confirm-target production
   ```
   A puzzle you scheduled locally is not promoted (only `approved` ones are): unschedule it there first.
6. Copy the mirror to the server and fix permissions:
   ```bash
   rsync -a ~/dgc-media-mirror/ <user>@<server>:/srv/dgc/media/
   ssh <user>@<server> 'chmod -R a+rX /srv/dgc/media'
   ```
7. The buffer check, on the server. Exit 2 means tomorrow is not ready (`missing_file` here means a forgotten rsync); exit 1 means under 7 days of buffer:
   ```bash
   docker compose -f compose.prod.yml --env-file /etc/dgc/production.vars exec backend python scripts/check_puzzle_buffer.py
   ```
8. Run smoke check 11 now: `deploy/smoke.sh --system-ca <domain>`.

## E. Backups and updates

1. Postgres, nightly, encrypted, copied to another provider (M1-52 builds it, rehearsed locally first):
   ```bash
   docker compose -f compose.prod.yml --env-file /etc/dgc/production.vars exec -T db \
     pg_dump -U dgc -Fc daily_game_challenge | age -r <public key> > dgc-$(date +%F).dump.age
   ```
2. The media folder is copied too. It can also be rebuilt by promoting again, because the workstation's content database and mirror are a second copy. Redis is not backed up: losing it logs everyone out and resets the rate-limit counters.
3. **(owner)** Restore one dump into a scratch Postgres before launch and check a login and today's puzzle.
4. Redis runs with `--maxmemory 256mb` and `noeviction`. At the cap, writes fail (a login errors) instead of evicting a session or a rate-limit counter. 256 MB holds far more sessions than this site will have. Raise it with the traffic.
5. Update: `git pull` in both app repos (and copy the platform repo up again), then `docker compose ... up -d --build`. `migrate` runs first and a failed migration stops the start, so the old containers keep running. Old asset files go with the old image, and open tabs reload once (`version-skew.ts`). Rollback is checking out the previous commit and running the same command. It is safe only when migrations are expand-and-contract (`ARCHITECTURE.md`, section 6, "Migrations").
6. Logs: `docker compose ... logs --tail 200 backend`. Each service keeps 3 files of 10 MB. Caddy's access log is off. If you turn it on, add a log filter that drops the `token` query parameter, because `/reset-password?token=...` takes over an account.

## F. Needs hosting (decision 81)

Each is blocked on the server or an outside account. M1-52 is the largest.

1. **Public HTTPS on the domain.** Parts B and C. Then run an external TLS grade and `curl -sI https://<domain>/` and compare with smoke checks 1 and 2.
2. **SSH deploy and uptime monitor (M1-52).**
   - GHCR push from CI and pull by digest, instead of building on the server.
   - A GitHub Actions deploy over SSH with a required approval; staging as a second Compose project; a rehearsed rollback.
   - An uptime monitor on `https://<domain>/` and `https://<domain>/api/v1/games`. `/readyz` stays hidden.
   - The buffer check (D7) on a schedule, with its two alerts: tomorrow's puzzle missing, and a buffer under 7 days.
3. **Email (M1-43, D4, plan 07 O-2).** **(owner)** Choose a provider. On a sending subdomain: SPF, DKIM and a DMARC record as the provider specifies. Then send a reset email to Gmail and to a Russian mailbox. Until this works, password reset does not (the reset link is not logged in production).
4. **Sentry (M1-45).** **(owner)** Create a free project, put the DSN in `/etc/dgc/production.vars` under the key M1-45 defines, rebuild, and trigger a deliberate test error. Check it shows a request id and no personal data.
5. **Legal pages (M1-46, D6).** **(owner)** A lawyer reviews the privacy policy and terms. Replace the draft marks and the placeholder with a real contact address and takedown contact, in English and Russian.
6. **Russian reachability (M1-54).** Load `https://<domain>/` and play a puzzle, including the step-6 clip, from a Russian vantage point (a Russian VPN or a friend there), and from a Russian mailbox for F3.
7. **IGDB image gate (decision 73).** D4.
8. **Load test (M1-51).** Rerun the k6 midnight spike against the server, not the laptop. Compare p95 on guess submit with the local result.
9. **Launch checklist (M1-54).** `ARCHITECTURE.md`, section 4, "First-deploy checklist": run it and sign it off.

## G. Before a real public launch

- Everything in F that touches users: email, error tracking, legal pages, the IGDB review.
- The HSTS change of C9, and `preload` after a few weeks.
- Redis AUTH and separate migrator and app database roles (left out of plan 06; each is a later edit of `compose.prod.yml` and the vars file).
- A CSP `report-to` endpoint, and a committed Playwright run against the production stack once the e2e suite can use it (decision 79).
- A `__Host-` cookie prefix (a boundary change, so both repos and `CONTRACTS.md`).
