#!/usr/bin/env bash
# Watch for a VNC-dropped Supabase CLI verification code and paste it into
# the waiting `supabase login` prompt in tmux session sb-login.
#
# Usage (agent VM):
#   bash scripts/m2_watch_cli_code.sh
#
# Human (after Dashboard shows the CLI verification code):
#   printf '%s\n' 'YOUR_CODE' > /tmp/supabase-cli-code
#   chmod 600 /tmp/supabase-cli-code
#
# Never paste codes into chat. This file is deleted after a successful submit.
set -euo pipefail

CODE_FILE="${M2_CLI_CODE_FILE:-/tmp/supabase-cli-code}"
SESSION="${M2_SB_LOGIN_TMUX:-sb-login}"
INTERVAL="${M2_CLI_CODE_INTERVAL:-5}"
TMUX_CFG=/exec-daemon/tmux.portal.conf
LOG=/tmp/m2-watch-cli-code.log
LOCK=/tmp/m2-watch-cli-code.lock

exec 9>"$LOCK"
if ! flock -n 9; then
  echo "another m2_watch_cli_code is already running" >&2
  exit 0
fi

echo "$(date -u +%Y-%m-%dT%H:%MZ) cli-code watcher started (file=$CODE_FILE session=$SESSION)" | tee -a "$LOG"

tmux_cmd() {
  if [[ -f "$TMUX_CFG" ]]; then
    tmux -f "$TMUX_CFG" "$@"
  else
    tmux "$@"
  fi
}

is_waiting_for_code() {
  local pane
  pane="$(tmux_cmd capture-pane -t "$SESSION" -p -J -S -8 2>/dev/null || true)"
  [[ "$pane" == *"Enter your verification code"* ]] || return 1
  [[ "$pane" != *"Operation cancelled"* ]] || {
    # cancelled may appear in scrollback; require a live prompt marker
    [[ "$pane" == *"◆"* ]] || [[ "$pane" == *"_└"* ]] || [[ "$pane" == *"│  _"* ]]
  }
}

while true; do
  if [[ -f "$CODE_FILE" ]]; then
    # Read first non-empty line; strip whitespace; never echo the code.
    code="$(tr -d '[:space:]' <"$CODE_FILE" | head -c 64 || true)"
    # Accept typical Supabase CLI codes (alphanumeric, often 6–12 chars).
    if [[ "$code" =~ ^[A-Za-z0-9]{4,32}$ ]]; then
      if tmux_cmd has-session -t "=$SESSION" 2>/dev/null; then
        if is_waiting_for_code; then
          echo "$(date -u +%Y-%m-%dT%H:%MZ) code file detected — submitting to $SESSION (not logged)" | tee -a "$LOG"
          tmux_cmd send-keys -t "$SESSION:0.0" -l -- "$code"
          sleep 0.3
          tmux_cmd send-keys -t "$SESSION:0.0" C-m
          rm -f "$CODE_FILE"
          # Give CLI a moment to write ~/.supabase/access-token
          for _ in 1 2 3 4 5 6 7 8 9 10; do
            if [[ -f "${HOME}/.supabase/access-token" ]]; then
              echo "$(date -u +%Y-%m-%dT%H:%MZ) CLI access-token present — apply watcher should proceed" | tee -a "$LOG"
              exit 0
            fi
            sleep 1
          done
          echo "$(date -u +%Y-%m-%dT%H:%MZ) submitted code; waiting for token file (will keep watching)" | tee -a "$LOG"
        else
          echo "$(date -u +%Y-%m-%dT%H:%MZ) code file present but $SESSION not waiting — leave file" | tee -a "$LOG"
        fi
      else
        echo "$(date -u +%Y-%m-%dT%H:%MZ) tmux session $SESSION missing" | tee -a "$LOG"
      fi
    else
      echo "$(date -u +%Y-%m-%dT%H:%MZ) ignoring invalid code file shape (not logged)" | tee -a "$LOG"
      # Do not delete — human may still be writing.
    fi
  fi
  sleep "$INTERVAL"
done
