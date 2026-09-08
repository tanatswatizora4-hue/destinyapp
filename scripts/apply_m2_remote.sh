#!/usr/bin/env bash
# Apply M2 schema + inventory seed + optional media upload to destiny-os ONLY.
# Never points at Wanzwei.
#
# Required:
#   export SUPABASE_URL=https://xchddfpfzrzhlbbmyhyn.supabase.co
#   export SUPABASE_SERVICE_ROLE_KEY=...
#
# Optional:
#   export DESTINY_MIGRATE_MEDIA=1
#   export DESTINY_SUPABASE_ANON_KEY=...   # verify public reads after apply
#
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
URL="${SUPABASE_URL:-https://xchddfpfzrzhlbbmyhyn.supabase.co}"
URL="${URL%/}"

if [[ -z "${SUPABASE_SERVICE_ROLE_KEY:-}" ]]; then
  echo "ERROR: SUPABASE_SERVICE_ROLE_KEY is required" >&2
  exit 1
fi

case "$URL" in
  *xchddfpfzrzhlbbmyhyn*) ;;
  *)
    echo "ERROR: refusing to run against non-destiny-os URL: $URL" >&2
    exit 1
    ;;
esac

echo "==> Applying schema migration via PostgREST SQL is not available."
echo "    Prefer: paste supabase/migrations/20260908143000_destiny_inventory_schema.sql"
echo "            into the destiny-os SQL Editor, OR use supabase db push linked to that project."
echo ""

if [[ "${DESTINY_APPLY_SEED_VIA_RPC:-0}" == "1" ]]; then
  echo "Seed via RPC not configured; use scripts/migrate_inventory_to_supabase.py instead."
fi

echo "==> Migrating inventory via PostgREST (service role)"
python3 "$ROOT/scripts/migrate_inventory_to_supabase.py"

if [[ "${DESTINY_MIGRATE_MEDIA:-0}" == "1" ]]; then
  echo "==> Media migrate enabled inside Python script (DESTINY_MIGRATE_MEDIA=1)"
fi

if [[ -n "${DESTINY_SUPABASE_ANON_KEY:-}" ]]; then
  echo "==> Verifying anon reads"
  for table in tours stays vehicles awards; do
    code=$(curl -sS -o /tmp/m2_verify.json -w '%{http_code}' \
      "$URL/rest/v1/$table?select=id&is_published=eq.true&limit=1" \
      -H "apikey: $DESTINY_SUPABASE_ANON_KEY" \
      -H "Authorization: Bearer $DESTINY_SUPABASE_ANON_KEY")
    echo "  $table HTTP $code"
  done
fi

echo "Done."
