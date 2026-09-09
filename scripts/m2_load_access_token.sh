#!/usr/bin/env bash
# Load Destiny M2 credentials from local files when env vars are unset.
# Safe to source: never prints secret values; does not change caller shell options.
#
# Sources (first match wins per var):
#   1) Existing process env
#   2) /tmp/destiny-m2.env  (KEY=value drop file for VNC — chmod 600 recommended)
#      Supports: SUPABASE_ACCESS_TOKEN, SUPABASE_SERVICE_ROLE_KEY, DESTINY_SUPABASE_ANON_KEY
#   3) ~/.supabase/access-token  (after `supabase login`) → SUPABASE_ACCESS_TOKEN
#
# Usage:
#   source scripts/m2_load_access_token.sh
#   # or: eval "$(bash scripts/m2_load_access_token.sh --export)"
#

_m2_token_file="${HOME}/.supabase/access-token"
_m2_env_file="${M2_CREDENTIALS_FILE:-/tmp/destiny-m2.env}"

_m2_load_env_file() {
  if [ ! -f "$_m2_env_file" ]; then
    return 1
  fi
  # Parse KEY=VALUE lines only for allowed keys; ignore comments/blank.
  # Do not `source` the file (avoids executing arbitrary content).
  local _line _key _val _loaded=0
  while IFS= read -r _line || [ -n "$_line" ]; do
    case "$_line" in
      ''|\#*) continue ;;
    esac
    _key="${_line%%=*}"
    _val="${_line#*=}"
    # trim CR/spaces around key/value without echoing
    _key="$(printf '%s' "$_key" | tr -d '[:space:]')"
    _val="$(printf '%s' "$_val" | tr -d '\r' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^["'\'']//' -e 's/["'\'']$//')"
    case "$_key" in
      SUPABASE_ACCESS_TOKEN|SUPABASE_SERVICE_ROLE_KEY|DESTINY_SUPABASE_ANON_KEY)
        if [ -n "$_val" ] && [ -z "${!_key:-}" ]; then
          export "$_key=$_val"
          _loaded=1
        fi
        ;;
    esac
  done <"$_m2_env_file"
  if [ "$_loaded" = "1" ]; then
    echo "==> Loaded M2 credentials from drop file ($_m2_env_file)" >&2
    return 0
  fi
  return 1
}

_m2_load_cli_token() {
  if [ -n "${SUPABASE_ACCESS_TOKEN:-}" ]; then
    return 0
  fi
  if [ -f "$_m2_token_file" ]; then
    # trim whitespace/newlines without echoing contents
    _m2_tok="$(tr -d '[:space:]' <"$_m2_token_file" 2>/dev/null || true)"
    if [ -n "${_m2_tok:-}" ]; then
      export SUPABASE_ACCESS_TOKEN="$_m2_tok"
      echo "==> Loaded SUPABASE_ACCESS_TOKEN from CLI file (~/.supabase/access-token)" >&2
      unset _m2_tok
      return 0
    fi
    unset _m2_tok
  fi
  return 1
}

_m2_load() {
  _m2_load_env_file || true
  _m2_load_cli_token || true
  if [ -n "${SUPABASE_ACCESS_TOKEN:-}" ]; then
    return 0
  fi
  if [ -n "${SUPABASE_SERVICE_ROLE_KEY:-}" ] && [ -n "${DESTINY_SUPABASE_ANON_KEY:-}" ]; then
    return 0
  fi
  return 1
}

if [ "${1:-}" = "--export" ]; then
  set -euo pipefail
  if _m2_load; then
    python3 - <<'PY'
import os, shlex
for k in ("SUPABASE_ACCESS_TOKEN", "SUPABASE_SERVICE_ROLE_KEY", "DESTINY_SUPABASE_ANON_KEY"):
    v = os.environ.get(k) or ""
    if v:
        print(f"export {k}=" + shlex.quote(v))
PY
  fi
  exit 0
fi

# When sourced, just load into current shell.
_m2_load || true
unset -f _m2_load _m2_load_env_file _m2_load_cli_token
unset _m2_token_file _m2_env_file
