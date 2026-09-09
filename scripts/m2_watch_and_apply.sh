#!/usr/bin/env bash
# Watch for Supabase credentials, then run apply_m2_remote.sh once.
# Intended for agent VMs waiting on:
#   - CLI login (~/.supabase/access-token)
#   - drop file /tmp/destiny-m2.env (VNC; KEY=value; chmod 600)
#   - mid-session env injection (best-effort; often requires a new agent)
#
# Usage:
#   bash scripts/m2_watch_and_apply.sh
#   M2_WATCH_INTERVAL=10 bash scripts/m2_watch_and_apply.sh
#
# Lock/state: /tmp/m2-watch-apply.{lock,log,done}
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INTERVAL="${M2_WATCH_INTERVAL:-15}"
LOCK=/tmp/m2-watch-apply.lock
DONE=/tmp/m2-watch-apply.done
LOG=/tmp/m2-watch-apply.log
APPLY="$ROOT/scripts/apply_m2_remote.sh"

exec 9>"$LOCK"
if ! flock -n 9; then
  echo "another m2_watch_and_apply is already running" >&2
  exit 0
fi

if [[ -f "$DONE" ]]; then
  echo "already completed earlier (remove $DONE to re-run)" | tee -a "$LOG"
  exit 0
fi

echo "$(date -u +%Y-%m-%dT%H:%MZ) watcher started (interval=${INTERVAL}s)" | tee -a "$LOG"

have_creds() {
  # shellcheck disable=SC1091
  source "$ROOT/scripts/m2_load_access_token.sh"
  if [[ -n "${SUPABASE_ACCESS_TOKEN:-}" ]]; then
    return 0
  fi
  if [[ -n "${SUPABASE_SERVICE_ROLE_KEY:-}" && -n "${DESTINY_SUPABASE_ANON_KEY:-}" ]]; then
    return 0
  fi
  return 1
}

while true; do
  if have_creds; then
    echo "$(date -u +%Y-%m-%dT%H:%MZ) credentials detected — starting apply_m2_remote.sh" | tee -a "$LOG"
    if [[ -f "$ROOT/supabase/seed/destiny-inventory-media-staged.tar" ]] && head -1 "$ROOT/supabase/seed/destiny-inventory-media-staged.tar" 2>/dev/null | grep -q 'git-lfs'; then
      echo "$(date -u +%Y-%m-%dT%H:%MZ) resolving Git LFS media tarball" | tee -a "$LOG"
      (cd "$ROOT" && git lfs pull --include='supabase/seed/destiny-inventory-media-staged.tar') >>"$LOG" 2>&1 || true
    fi
    set +e
    bash "$APPLY" >>"$LOG" 2>&1
    rc=$?
    set -e
    echo "$(date -u +%Y-%m-%dT%H:%MZ) apply exit=$rc" | tee -a "$LOG"
    if [[ $rc -eq 0 ]]; then
      date -u +%Y-%m-%dT%H:%MZ >"$DONE"
      echo "SUCCESS" >>"$DONE"
      # Signal file for agent poll (no secrets)
      echo "apply_ok" >/tmp/m2-apply-ready
      echo "$(date -u +%Y-%m-%dT%H:%MZ) apply ok — committing finalize docs" | tee -a "$LOG"
      set +e
      bash "$ROOT/scripts/m2_post_apply_commit.sh" >>"$LOG" 2>&1
      commit_rc=$?
      set -e
      echo "$(date -u +%Y-%m-%dT%H:%MZ) post-apply commit exit=$commit_rc" | tee -a "$LOG"
      exit 0
    fi
    echo "$(date -u +%Y-%m-%dT%H:%MZ) apply failed; will retry when credentials still present" | tee -a "$LOG"
    sleep "$INTERVAL"
    continue
  fi
  sleep "$INTERVAL"
done
