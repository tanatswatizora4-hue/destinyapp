#!/usr/bin/env bash
# Offline tests for M2 credential loader + post-apply commit guardrails.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "OK    $*"; }

# --- drop file loads ACCESS_TOKEN without printing it ---
cat >"$TMP/creds.env" <<'EOF'
# comment
SUPABASE_ACCESS_TOKEN="pat_test_value_123"
DESTINY_SUPABASE_ANON_KEY=anon_test_value
EOF
# shellcheck disable=SC1091
out="$(M2_CREDENTIALS_FILE="$TMP/creds.env" bash -c "source '$ROOT/scripts/m2_load_access_token.sh'; printf '%s' \"\$SUPABASE_ACCESS_TOKEN|\$DESTINY_SUPABASE_ANON_KEY\"")"
[[ "$out" == "pat_test_value_123|anon_test_value" ]] || fail "drop file load got: $out"
pass "drop-file loads ACCESS_TOKEN + ANON"

# --- ignores unknown keys / does not execute ---
cat >"$TMP/evil.env" <<'EOF'
SUPABASE_ACCESS_TOKEN=ok_token
EVIL_KEY=should_ignore
EOF
# shellcheck disable=SC1091
out="$(M2_CREDENTIALS_FILE="$TMP/evil.env" bash -c "source '$ROOT/scripts/m2_load_access_token.sh'; echo \"token=\$SUPABASE_ACCESS_TOKEN evil=\${EVIL_KEY-}\"" )"
[[ "$out" == "token=ok_token evil=" ]] || fail "evil key leaked: $out"
pass "drop-file ignores unknown keys"

# --- CLI token file ---
mkdir -p "$TMP/home/.supabase"
printf '  cli_token_xyz  \n' >"$TMP/home/.supabase/access-token"
# shellcheck disable=SC1091
out="$(HOME="$TMP/home" env -u SUPABASE_ACCESS_TOKEN -u SUPABASE_SERVICE_ROLE_KEY -u DESTINY_SUPABASE_ANON_KEY \
  bash -c "source '$ROOT/scripts/m2_load_access_token.sh'; printf '%s' \"\$SUPABASE_ACCESS_TOKEN\"")"
[[ "$out" == "cli_token_xyz" ]] || fail "cli token load got: $out"
pass "CLI access-token file loads"

# --- post-apply commit refuses without catalog 200 ---
if bash "$ROOT/scripts/m2_post_apply_commit.sh" >/tmp/m2_post_apply_test.out 2>&1; then
  fail "post-apply commit should refuse while catalog is not 200"
else
  grep -q 'refusing commit' /tmp/m2_post_apply_test.out || fail "expected refusing commit message"
  pass "post-apply commit refuses without catalog 200"
fi

echo
echo "All credential-loader tests PASSED"
