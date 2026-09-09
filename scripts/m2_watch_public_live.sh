#!/usr/bin/env bash
# Watch public destiny-media for catalog.json HTTP 200 (+ sample objects).
# When media is live AND credentials exist, run verify→finalize→commit.
# When media is live but no anon/PAT, only signal /tmp/m2-media-live (do not
# claim full MILESTONE_COMPLETE — DB counts/sensitive still need verify).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INTERVAL="${M2_PUBLIC_LIVE_INTERVAL:-30}"
LOG=/tmp/m2-watch-public-live.log
LOCK=/tmp/m2-watch-public-live.lock
DONE=/tmp/m2-watch-public-live.done
CATALOG_URL='https://xchddfpfzrzhlbbmyhyn.supabase.co/storage/v1/object/public/destiny-media/inventory/catalog.json'
SAMPLES=(
  'tours/39/primary.jpg'
  'stays/1/primary.jpg'
  'vehicles/1/primary.webp'
  'awards/5/primary.jpg'
)

exec 9>"$LOCK"
if ! flock -n 9; then
  echo "another m2_watch_public_live is already running" >&2
  exit 0
fi

if [[ -f "$DONE" ]]; then
  echo "already completed earlier (remove $DONE to re-run)" | tee -a "$LOG"
  exit 0
fi

echo "$(date -u +%Y-%m-%dT%H:%MZ) public-live watcher started" | tee -a "$LOG"

http_code() {
  curl -s -o /dev/null -w '%{http_code}' "$1" || echo 000
}

media_live() {
  local code sample
  code="$(http_code "$CATALOG_URL")"
  [[ "$code" == "200" ]] || return 1
  for sample in "${SAMPLES[@]}"; do
    code="$(http_code "https://xchddfpfzrzhlbbmyhyn.supabase.co/storage/v1/object/public/destiny-media/$sample")"
    [[ "$code" == "200" ]] || return 1
  done
  return 0
}

while true; do
  if media_live; then
    echo "$(date -u +%Y-%m-%dT%H:%MZ) public media LIVE (catalog + samples HTTP 200)" | tee -a "$LOG"
    echo "media_live $(date -u +%Y-%m-%dT%H:%MZ)" >/tmp/m2-media-live

    # shellcheck disable=SC1091
    source "$ROOT/scripts/m2_load_access_token.sh" || true
    if [[ -n "${DESTINY_SUPABASE_ANON_KEY:-}" ]] || [[ -n "${SUPABASE_SERVICE_ROLE_KEY:-}" ]] || [[ -n "${SUPABASE_ACCESS_TOKEN:-}" ]]; then
      echo "$(date -u +%Y-%m-%dT%H:%MZ) credentials present — attempting verify/finalize" | tee -a "$LOG"
      set +e
      if [[ -n "${SUPABASE_ACCESS_TOKEN:-}" ]] && [[ -z "${SUPABASE_SERVICE_ROLE_KEY:-}" || -z "${DESTINY_SUPABASE_ANON_KEY:-}" ]]; then
        python3 "$ROOT/scripts/m2_bootstrap_keys.py" >>"$LOG" 2>&1
        # shellcheck disable=SC1091
        source "$ROOT/scripts/m2_load_access_token.sh" || true
      fi
      if [[ -n "${DESTINY_SUPABASE_ANON_KEY:-}" ]]; then
        python3 "$ROOT/scripts/verify_m2_remote.py" >>"$LOG" 2>&1
        rc=$?
      elif [[ -n "${SUPABASE_SERVICE_ROLE_KEY:-}" ]]; then
        python3 "$ROOT/scripts/verify_m2_remote.py" --service-role >>"$LOG" 2>&1
        rc=$?
      else
        rc=2
      fi
      set -e
      if [[ $rc -eq 0 ]]; then
        python3 "$ROOT/scripts/m2_finalize_docs.py" >>"$LOG" 2>&1
        bash "$ROOT/scripts/m2_post_apply_commit.sh" >>"$LOG" 2>&1 || true
        date -u +%Y-%m-%dT%H:%MZ >"$DONE"
        echo "SUCCESS" >>"$DONE"
        echo "apply_ok" >/tmp/m2-apply-ready
        echo "$(date -u +%Y-%m-%dT%H:%MZ) finalize+commit done" | tee -a "$LOG"
        exit 0
      fi
      echo "$(date -u +%Y-%m-%dT%H:%MZ) verify failed rc=$rc — media live but milestone incomplete" | tee -a "$LOG"
    else
      echo "$(date -u +%Y-%m-%dT%H:%MZ) media live but no anon/PAT — cannot verify DB counts yet" | tee -a "$LOG"
    fi
    # Keep watching in case credentials appear later while media stays live
  fi
  sleep "$INTERVAL"
done
