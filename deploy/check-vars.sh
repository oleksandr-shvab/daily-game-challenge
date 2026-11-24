#!/usr/bin/env bash
# Refuses a vars file that is not ready for a server: any CHANGE_ME value, and the public dummy
# secrets of localhost.vars on a site that is not *.localhost. The backend already refuses weak
# secrets and an http FRONTEND_URL; this covers what it cannot see (POSTGRES_PASSWORD, SITE_ADDRESS).
#   deploy/check-vars.sh /etc/dgc/production.vars
set -euo pipefail

file=${1:?usage: deploy/check-vars.sh <vars file>}
[[ -r $file ]] || { echo "cannot read $file" >&2; exit 1; }

site=$(sed -n 's/^SITE_ADDRESS=//p' "$file" | tail -1)
bad=0
# The file is read as text, never sourced.
while IFS= read -r line || [[ -n $line ]]; do
  [[ $line =~ ^[[:space:]]*(#|$) ]] && continue
  key=${line%%=*}
  value=${line#*=}
  if [[ $value == *CHANGE_ME* ]]; then
    echo "FAIL: $key still holds CHANGE_ME" >&2
    bad=1
  fi
  if [[ $value == *local-only-not-a-secret* && $site != *.localhost ]]; then
    echo "FAIL: $key holds the public dummy secret of localhost.vars" >&2
    bad=1
  fi
done <"$file"

[[ -n $site ]] || { echo "FAIL: SITE_ADDRESS is missing" >&2; bad=1; }
((bad == 0)) && echo "ok: $file has no placeholder values"
exit "$bad"
