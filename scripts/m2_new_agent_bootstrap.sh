#!/usr/bin/env bash
# First command for a NEW Cloud Agent on cursor/m2-destiny-backend-migration-194a
# after SUPABASE_ACCESS_TOKEN (or service_role+anon) is available.
#
# Runs: load creds → apply → post-apply commit (if catalog 200).
# Never prints secret values.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

case "$(git branch --show-current)" in
  cursor/m2-destiny-backend-migration-194a) ;;
  *)
    echo "WARN: expected branch cursor/m2-destiny-backend-migration-194a" >&2
    ;;
esac

# shellcheck disable=SC1091
source "$ROOT/scripts/m2_load_access_token.sh"

if [[ -z "${SUPABASE_ACCESS_TOKEN:-}" && ( -z "${SUPABASE_SERVICE_ROLE_KEY:-}" || -z "${DESTINY_SUPABASE_ANON_KEY:-}" ) ]]; then
  echo "STOP_REASON=CREDENTIAL_REQUIRED" >&2
  echo "Need SUPABASE_ACCESS_TOKEN (preferred) or service_role+anon." >&2
  echo "Drop file: /tmp/destiny-m2.env  OR  CLI login (~/.supabase/access-token)" >&2
  exit 2
fi

echo "==> Running apply_m2_remote.sh"
bash "$ROOT/scripts/apply_m2_remote.sh"

echo "==> Post-apply commit (catalog must be HTTP 200)"
bash "$ROOT/scripts/m2_post_apply_commit.sh" || {
  echo "WARN: post-apply commit skipped/failed — check docs and push manually" >&2
}

echo "==> Live catalog check"
code="$(curl -s -o /dev/null -w '%{http_code}' \
  'https://xchddfpfzrzhlbbmyhyn.supabase.co/storage/v1/object/public/destiny-media/inventory/catalog.json' || true)"
echo "inventory/catalog.json HTTP $code"
if [[ "$code" == "200" ]]; then
  echo "M2_APPLY_LIVE_OK"
  echo "apply_ok" >/tmp/m2-apply-ready
  exit 0
fi
echo "M2_APPLY_INCOMPLETE catalog=$code" >&2
exit 1
