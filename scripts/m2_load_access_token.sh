#!/usr/bin/env bash
# Load SUPABASE_ACCESS_TOKEN from Supabase CLI login file when unset.
# Safe to source: never prints the token value; does not change caller shell options.
#
# Usage:
#   source scripts/m2_load_access_token.sh
#   # or: eval "$(bash scripts/m2_load_access_token.sh --export)"
#

_m2_token_file="${HOME}/.supabase/access-token"

_m2_load() {
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

if [ "${1:-}" = "--export" ]; then
  set -euo pipefail
  if _m2_load; then
    python3 -c 'import os,shlex; print("export SUPABASE_ACCESS_TOKEN="+shlex.quote(os.environ["SUPABASE_ACCESS_TOKEN"]))'
  fi
  exit 0
fi

# When sourced, just load into current shell.
_m2_load || true
unset -f _m2_load
unset _m2_token_file
