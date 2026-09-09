#!/usr/bin/env bash
# Keep supabase CLI login prompt fresh for VNC authorize (sessions go stale).
# Runs in tmux; refreshes every M2_CLI_REFRESH_SECS (default 900).
set -euo pipefail
SESSION="${M2_SB_LOGIN_TMUX:-sb-login}"
INTERVAL="${M2_CLI_REFRESH_SECS:-900}"
TMUX_CFG=/exec-daemon/tmux.portal.conf
URL_FILE=/tmp/supabase-cli-login.url
LOG=/tmp/m2-cli-login-refresh.log

tmux_cmd() {
  if [[ -f "$TMUX_CFG" ]]; then
    tmux -f "$TMUX_CFG" "$@"
  else
    tmux "$@"
  fi
}

extract_url() {
  local pane url
  pane="$(tmux_cmd capture-pane -t "$SESSION" -p -J -S -40 2>/dev/null || true)"
  url="$(printf '%s' "$pane" | tr -d '\n' | grep -oE 'https://supabase.com/dashboard/cli/login[^ ]+' | tail -1 || true)"
  if [[ -n "$url" ]]; then
    printf '%s\n' "$url" >"$URL_FILE"
    return 0
  fi
  return 1
}

refresh_login() {
  if ! tmux_cmd has-session -t "=$SESSION" 2>/dev/null; then
    tmux_cmd new-session -d -s "$SESSION" -c /workspace -- bash -l
  fi
  tmux_cmd send-keys -t "$SESSION:0.0" C-c
  sleep 0.4
  tmux_cmd send-keys -t "$SESSION:0.0" 'supabase login --agent no' C-m
  sleep 2
  tmux_cmd send-keys -t "$SESSION:0.0" C-m
  sleep 2
  if extract_url; then
    echo "$(date -u +%Y-%m-%dT%H:%MZ) refreshed CLI login URL" | tee -a "$LOG"
  else
    echo "$(date -u +%Y-%m-%dT%H:%MZ) refresh failed to parse URL" | tee -a "$LOG"
  fi
}

echo "$(date -u +%Y-%m-%dT%H:%MZ) cli login refresher started (every ${INTERVAL}s)" | tee -a "$LOG"
# Ensure a waiting session exists now
if ! extract_url; then
  refresh_login
fi
while true; do
  sleep "$INTERVAL"
  # Skip refresh if already logged in
  if [[ -f "${HOME}/.supabase/access-token" ]]; then
    echo "$(date -u +%Y-%m-%dT%H:%MZ) access-token present — refresher idle" | tee -a "$LOG"
    sleep "$INTERVAL"
    continue
  fi
  refresh_login
done
