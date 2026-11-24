#!/usr/bin/env bash
# Smoke checks for the production stack: one numbered check per Caddyfile or Compose rule.
# Prints "ok N" or "FAIL N: <what>" for each check and exits 1 if any failed.
#
#   deploy/smoke.sh [--system-ca] [<site> [<https port>]]
#
# Defaults: site dgc.localhost, https port 443. The script connects to 127.0.0.1 with
# `curl --resolve`, so it does not depend on the machine resolving *.localhost, and it trusts
# Caddy's local root certificate copied out of the `web` container (never `curl -k`).
#
# --system-ca     for a real domain: no --resolve, trust the system's certificate store, and skip
#                 check 10 (no test accounts on a real site) and check 12 (it stops the backend).
#
# Rate limits: checks 9 and 10 each send one request the backend counts per IP (a login, a
# register), and every request from this laptop comes from the Docker gateway address. A 429 there
# prints "skip" with the Retry-After value, not a failure, because it proves nothing about the
# rule under test. Wait for the window, or flush Redis on the local stack, and run it again.
# HTTP_PORT       the host port of plain http. Default: asked from the running `web` container
#                 (with --system-ca: 80).
# SKIP_CHECKS     space-separated numbers to skip, for example SKIP_CHECKS="11" before content exists.
# MEDIA_ORIGIN    the value of the vars file (default empty); check 1 needs it for the exact CSP.
set -euo pipefail

system_ca=0
if [[ ${1:-} == --system-ca ]]; then
  system_ca=1
  shift
fi
site=${1:-dgc.localhost}
https_port=${2:-443}
http_port=${HTTP_PORT:-}
media_origin=${MEDIA_ORIGIN:-}

tmp=$(mktemp -d)
backend_container=""
cleanup() {
  # If check 12 stopped the backend and the script died, bring it back.
  if [[ -n $backend_container ]]; then docker start "$backend_container" >/dev/null 2>&1 || true; fi
  rm -rf "$tmp"
}
trap cleanup EXIT

curl_args=(-sS --max-time 20)
if ((system_ca)); then
  : # the system store
else
  container_of() {
    docker ps -q \
      --filter "label=com.docker.compose.project=dgc-prod" \
      --filter "label=com.docker.compose.service=$1" | head -1
  }
  web=$(container_of web)
  [[ -n $web ]] || { echo "FAIL 0: the web container of project dgc-prod is not running" >&2; exit 1; }
  docker cp "$web:/data/caddy/pki/authorities/local/root.crt" "$tmp/root.crt" >/dev/null 2>&1 ||
    { echo "FAIL 0: cannot copy Caddy's root certificate out of the web container (is it healthy yet?)" >&2; exit 1; }
  [[ -n $http_port ]] || http_port=$(docker port "$web" 80/tcp 2>/dev/null | head -1 | sed 's/.*://' || true)
  curl_args+=(--cacert "$tmp/root.crt"
    --resolve "$site:$https_port:127.0.0.1" --resolve "$site:$http_port:127.0.0.1")
fi

http_port=${http_port:-80}
base="https://$site"
[[ $https_port == 443 ]] || base+=":$https_port"

failures=0
ok() { echo "ok $1"; }
fail() { echo "FAIL $1: $2"; failures=$((failures + 1)); }
wanted() {
  if [[ " ${SKIP_CHECKS:-} " == *" $1 "* ]]; then echo "skip $1"; return 1; fi
}

# fetch <name> <curl args...> <url>: headers in $tmp/<name>.hdr, body in $tmp/<name>.body,
# the status code in $status.
fetch() {
  local name=$1
  shift
  : >"$tmp/$name.hdr"
  : >"$tmp/$name.body"
  # A refused or reset connection is a failed check (status 000), not the end of the script.
  status=$(curl "${curl_args[@]}" -D "$tmp/$name.hdr" -o "$tmp/$name.body" -w '%{http_code}' "$@") || status=000
  tr -d '\r' <"$tmp/$name.hdr" >"$tmp/$name.hdr.clean"
  mv "$tmp/$name.hdr.clean" "$tmp/$name.hdr"
}

# hdr <name> <header>: the last value of a response header, "" when absent.
hdr() {
  { grep -i "^$2:" "$tmp/$1.hdr" || true; } | tail -1 | sed -E 's/^[^:]*:[[:space:]]*//'
}

expected_csp="default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data: $media_origin; media-src 'self' $media_origin; font-src 'self'; connect-src 'self'; object-src 'none'; base-uri 'self'; form-action 'self'; frame-ancestors 'none'"

# security_header_problems <name>: prints what is wrong with the security headers of a response.
security_header_problems() {
  local n=$1 problems=""
  [[ $(hdr "$n" content-security-policy) == "$expected_csp" ]] || problems+=" Content-Security-Policy;"
  [[ $(hdr "$n" strict-transport-security) == max-age=* ]] || problems+=" Strict-Transport-Security;"
  [[ $(hdr "$n" x-content-type-options) == nosniff ]] || problems+=" X-Content-Type-Options;"
  [[ $(hdr "$n" referrer-policy) == strict-origin-when-cross-origin ]] || problems+=" Referrer-Policy;"
  [[ -n $(hdr "$n" permissions-policy) ]] || problems+=" Permissions-Policy;"
  [[ $(hdr "$n" x-frame-options) == DENY ]] || problems+=" X-Frame-Options;"
  [[ $(hdr "$n" cross-origin-opener-policy) == same-origin ]] || problems+=" Cross-Origin-Opener-Policy;"
  [[ -z $(hdr "$n" server) ]] || problems+=" Server (must be absent);"
  [[ -z $(hdr "$n" via) ]] || problems+=" Via (must be absent);"
  echo "$problems"
}

# need_index: fetch / once, for the checks that read it (1, 2, 3 and 5), so a skipped check 1
# does not leave the others with no files.
have_index=0
index_status=000
need_index() {
  ((have_index)) && return 0
  fetch index "$base/"
  index_status=$status
  have_index=1
}

# 1: the page, no-cache, the exact CSP.
if wanted 1; then
  need_index
  csp=$(hdr index content-security-policy)
  if [[ $index_status != 200 ]]; then fail 1 "GET / answered $index_status"
  elif [[ $(hdr index cache-control) != no-cache ]]; then fail 1 "Cache-Control of / is '$(hdr index cache-control)', want no-cache"
  elif [[ $csp != "$expected_csp" ]]; then fail 1 "CSP is '$csp', want '$expected_csp'"
  else ok 1; fi
fi

# 2: the other headers on the same response.
if wanted 2; then
  need_index
  problems=$(security_header_problems index)
  if [[ $index_status != 200 ]]; then fail 2 "GET / answered $index_status"
  elif [[ -n $problems ]]; then fail 2 "wrong or missing on /:$problems"
  else ok 2; fi
fi

# 3: a hashed asset is immutable.
if wanted 3; then
  need_index
  asset=$(grep -o '/assets/[^"]*\.js' "$tmp/index.body" | head -1 || true)
  if [[ $index_status != 200 ]]; then fail 3 "GET / answered $index_status, so index.html names no asset"
  elif [[ -z $asset ]]; then fail 3 "no /assets/*.js file named in index.html"
  else
    fetch asset "$base$asset"
    if [[ $status != 200 ]]; then fail 3 "$asset answered $status"
    elif [[ $(hdr asset cache-control) != "public, max-age=31536000, immutable" ]]; then
      fail 3 "Cache-Control of $asset is '$(hdr asset cache-control)'"
    else ok 3; fi
  fi
fi

# 4: a missing asset is a real 404, never index.html.
if wanted 4; then
  fetch missing "$base/assets/does-not-exist.js"
  if [[ $status != 404 ]]; then fail 4 "/assets/does-not-exist.js answered $status, want 404"
  elif [[ $(hdr missing content-type) == text/html* ]] || grep -qi '<!doctype html\|<html' "$tmp/missing.body"; then
    fail 4 "the 404 body is HTML"
  else ok 4; fi
fi

# 5: an SPA route gets index.html with no-cache.
if wanted 5; then
  need_index
  fetch route "$base/games/game-guesser/2020-01-01"
  if [[ $status != 200 ]]; then fail 5 "SPA route answered $status, want 200"
  elif [[ $index_status != 200 ]]; then fail 5 "GET / answered $index_status, nothing to compare with"
  elif ! cmp -s "$tmp/route.body" "$tmp/index.body"; then fail 5 "SPA route body is not index.html"
  elif [[ $(hdr route cache-control) != no-cache ]]; then fail 5 "Cache-Control of the SPA route is '$(hdr route cache-control)'"
  else ok 5; fi
fi

# 6: the health endpoints are not reachable through the proxy, and the interactive docs are off.
if wanted 6; then
  bad=""
  for path in /api/healthz /api/readyz /api/docs /api/redoc; do
    fetch health "$base$path"
    [[ $status == 404 ]] || bad+=" $path=$status"
  done
  if [[ -n $bad ]]; then fail 6 "want 404 for /api/healthz, /api/readyz, /api/docs and /api/redoc, got:$bad"; else ok 6; fi
fi

# 7: an API response with no Cache-Control of its own gets no-store, and Caddy sets the request id.
if wanted 7; then
  fetch clock -H 'X-Request-ID: client-chosen-id' "$base/api/v1/clock"
  rid=$(hdr clock x-request-id)
  if [[ $status != 200 ]]; then fail 7 "/api/v1/clock answered $status"
  elif [[ $(hdr clock content-type) != application/json* ]]; then fail 7 "content type is '$(hdr clock content-type)'"
  elif [[ $(hdr clock cache-control) != no-store ]]; then fail 7 "Cache-Control is '$(hdr clock cache-control)', want no-store"
  elif [[ -z $rid ]]; then fail 7 "no X-Request-ID"
  elif [[ $rid == client-chosen-id ]]; then fail 7 "the client's X-Request-ID reached the backend"
  else
    # The clock sets no-store itself. /openapi.json is the one backend answer with no
    # Cache-Control of its own, so it shows the `?Cache-Control` rule of the Caddyfile.
    fetch openapi "$base/api/openapi.json"
    if [[ $status != 200 ]]; then fail 7 "/api/openapi.json answered $status"
    elif [[ $(hdr openapi cache-control) != no-store ]]; then fail 7 "Cache-Control of /api/openapi.json is '$(hdr openapi cache-control)', want no-store"
    else ok 7; fi
  fi
fi

# 8: http redirects to https with no port in the location.
if wanted 8; then
  if [[ $https_port != 443 ]]; then
    echo "skip 8 (custom https port)"
  else
    http_url="http://$site"
    [[ $http_port == 80 ]] || http_url+=":$http_port"
    fetch redirect "$http_url/"
    if [[ $status != 308 ]]; then fail 8 "$http_url/ answered $status, want 308"
    elif [[ $(hdr redirect location) != "https://$site/" ]]; then fail 8 "Location is '$(hdr redirect location)', want https://$site/"
    else ok 8; fi
  fi
fi

# unique_email: a new address per call, so the per-email limits never see a repeat.
unique_email() { echo "smoke-$(date +%s)-$(od -An -N6 -tx1 /dev/urandom | tr -d ' \n')@example.com"; }

# 9: Caddy keeps Origin (the backend's CSRF check), and caps a request body at 1 MB.
# Only the login with the right Origin reaches the backend's limiter (the CSRF check refuses the
# other first, and Caddy answers the big one itself), so one login is counted per run.
if wanted 9; then
  login="{\"email\":\"$(unique_email)\",\"password\":\"not-a-real-password\"}"
  fetch good -X POST -H 'Content-Type: application/json' -H "Origin: https://$site" -d "$login" "$base/api/v1/auth/login"
  good=$status
  fetch evil -X POST -H 'Content-Type: application/json' -H 'Origin: https://evil.example' -d "$login" "$base/api/v1/auth/login"
  evil=$status
  head -c 2097152 /dev/zero | tr '\0' 'a' >"$tmp/big.body.in"
  fetch big -X POST -H 'Content-Type: application/json' -H "Origin: https://$site" --data-binary "@$tmp/big.body.in" "$base/api/v1/auth/login"
  big=$status
  if [[ $evil != 403 ]] || ! grep -q csrf_origin_mismatch "$tmp/evil.body"; then fail 9 "login with a foreign Origin answered $evil, want 403 csrf_origin_mismatch"
  elif [[ $big != 413 ]]; then fail 9 "a 2 MB body answered $big, want 413"
  elif [[ -n $(security_header_problems big) ]]; then fail 9 "the 413 lacks headers:$(security_header_problems big)"
  elif [[ $good == 429 ]]; then echo "skip 9 (rate limited, Retry-After $(hdr good retry-after) s: Origin passthrough not checked)"
  elif [[ $good != 401 ]]; then fail 9 "login with the site's Origin answered $good, want 401"
  else ok 9; fi
fi

# 10: the session cookie flags. Not on a real site: it would leave a test account behind.
if wanted 10; then
  if ((system_ca)); then
    echo "skip 10 (no test accounts on a real site)"
  else
    body="{\"email\":\"$(unique_email)\",\"password\":\"smoke-test-password-1\"}"
    fetch register -X POST -H 'Content-Type: application/json' -H "Origin: https://$site" -d "$body" "$base/api/v1/auth/register"
    cookie=$(hdr register set-cookie)
    if [[ $status == 429 ]]; then echo "skip 10 (rate limited, Retry-After $(hdr register retry-after) s: cookie flags not checked)"
    elif [[ $status != 201 && $status != 200 ]]; then fail 10 "register answered $status"
    else
      missing=""
      # The backend writes "SameSite=lax": compare in lower case.
      for flag in secure httponly samesite=lax; do
        [[ ${cookie,,} == *"$flag"* ]] || missing+=" $flag"
      done
      if [[ $cookie != session_id=* ]]; then fail 10 "no session_id cookie: '$cookie'"
      elif [[ -n $missing ]]; then fail 10 "the cookie lacks:$missing"
      else ok 10; fi
    fi
  fi
fi

# 11: clue media through the proxy: a signed link, and a 2-byte range answered as 206, uncompressed.
if wanted 11; then
  fetch puzzle "$base/api/v1/games/game-guesser/puzzles/today"
  if [[ $status != 200 ]]; then fail 11 "today's puzzle answered $status: seed the stack first"
  else
    media_url=$(grep -o "\"url\":\"$base/api/v1/media/[^\"]*\"" "$tmp/puzzle.body" | head -1 | sed -E 's/^"url":"//; s/"$//' || true)
    if [[ -z $media_url ]]; then fail 11 "no media URL under $base/api/v1/media/ in today's puzzle: seed the stack first"
    else
      fetch range -H 'Range: bytes=0-1' -H 'Accept-Encoding: gzip, zstd, br' "$media_url"
      size=$(wc -c <"$tmp/range.body" | tr -d ' ')
      if [[ $status != 206 ]]; then fail 11 "a range request answered $status, want 206"
      elif [[ ! $(hdr range content-range) =~ ^bytes\ 0-1/[0-9]+$ ]]; then fail 11 "Content-Range is '$(hdr range content-range)'"
      elif [[ $size != 2 ]]; then fail 11 "the range body is $size bytes, want 2"
      elif [[ -n $(hdr range content-encoding) ]]; then fail 11 "the range answer has Content-Encoding"
      else
        # Two bytes are too short for Caddy's `encode` to touch, so a larger answer shows the same
        # rule: /api is never compressed.
        fetch big_json -H 'Accept-Encoding: gzip, zstd, br' "$base/api/openapi.json"
        if [[ -n $(hdr big_json content-encoding) ]]; then fail 11 "/api/openapi.json is compressed ($(hdr big_json content-encoding))"
        else ok 11; fi
      fi
    fi
  fi
fi

# 12: a 502 made by Caddy itself (the backend is down) carries the same headers. This stops the
# backend for a few seconds, so it runs only against the local stack. The check fails if the backend
# is not healthy again within 60 seconds.
if wanted 12; then
  if ((system_ca)); then
    echo "skip 12 (stops the backend)"
  else
    backend_container=$(container_of backend)
    if [[ -z $backend_container ]]; then
      fail 12 "no running backend container of project dgc-prod to stop"
    elif ! docker stop "$backend_container" >/dev/null; then
      backend_container=""
      fail 12 "could not stop the backend container"
    else
      fetch down "$base/api/v1/clock"
      down=$status
      docker start "$backend_container" >/dev/null || fail 12 "could not start the backend container again"
      healthy=0
      for _ in $(seq 1 60); do
        if [[ $(docker inspect -f '{{.State.Health.Status}}' "$backend_container" 2>/dev/null) == healthy ]]; then healthy=1; break; fi
        sleep 1
      done
      backend_container=""
      if ((!healthy)); then fail 12 "the backend was not healthy again within 60 s"
      elif [[ $down != 502 ]]; then fail 12 "with the backend stopped, /api/v1/clock answered $down, want 502"
      elif [[ -n $(security_header_problems down) ]]; then fail 12 "the 502 lacks headers:$(security_header_problems down)"
      else ok 12; fi
    fi
  fi
fi

if ((failures)); then
  echo "$failures check(s) failed"
  exit 1
fi
