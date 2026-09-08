#!/usr/bin/env bash
# One-shot M2 apply to destiny-os ONLY (never Wanzwei).
#
# Required:
#   export SUPABASE_URL=https://xchddfpfzrzhlbbmyhyn.supabase.co
#   export SUPABASE_SERVICE_ROLE_KEY=...
#   export SUPABASE_ACCESS_TOKEN=...   # schema via Management API
#
# Optional:
#   export DESTINY_SUPABASE_ANON_KEY=...   # verify public reads
#   export DESTINY_SKIP_SCHEMA=1          # schema already applied in SQL Editor
#   export DESTINY_SKIP_MEDIA=1           # skip Storage upload
#   export DESTINY_MIGRATE_MEDIA=0        # default 0 — prefer staged upload
#   export DESTINY_MIGRATE_FROM_SNAPSHOT=1  # default
#
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
URL="${SUPABASE_URL:-https://xchddfpfzrzhlbbmyhyn.supabase.co}"
URL="${URL%/}"
export SUPABASE_URL="$URL"
export SUPABASE_PROJECT_REF="${SUPABASE_PROJECT_REF:-xchddfpfzrzhlbbmyhyn}"
export DESTINY_MIGRATE_FROM_SNAPSHOT="${DESTINY_MIGRATE_FROM_SNAPSHOT:-1}"
export DESTINY_MIGRATE_MEDIA="${DESTINY_MIGRATE_MEDIA:-0}"

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

if [[ "${DESTINY_SKIP_SCHEMA:-0}" != "1" ]]; then
  if [[ -z "${SUPABASE_ACCESS_TOKEN:-}" ]]; then
    echo "ERROR: SUPABASE_ACCESS_TOKEN required to apply schema." >&2
    echo "       Or set DESTINY_SKIP_SCHEMA=1 after pasting the migration in SQL Editor." >&2
    exit 1
  fi
  echo "==> Applying schema + RLS + storage policies via Management API"
  python3 "$ROOT/scripts/apply_sql_management_api.py" \
    "$ROOT/supabase/migrations/20260908143000_destiny_inventory_schema.sql" \
    "$ROOT/supabase/migrations/20260908170000_destiny_media_storage_policies.sql"
else
  echo "==> Skipping schema (DESTINY_SKIP_SCHEMA=1)"
fi

echo "==> Upserting inventory (snapshot → PostgREST)"
python3 "$ROOT/scripts/migrate_inventory_to_supabase.py"

if [[ "${DESTINY_SKIP_MEDIA:-0}" != "1" ]]; then
  echo "==> Uploading staged media + inventory/catalog.json"
  python3 "$ROOT/scripts/upload_staged_media.py"
  echo "==> Rebuilding owned catalog from snapshot + manifest"
  python3 "$ROOT/scripts/rebuild_owned_catalog.py"
  # Re-upload catalog after rebuild (owned paths for awards bare strings, etc.)
  DESTINY_CATALOG_ONLY=1 python3 "$ROOT/scripts/upload_staged_media.py"
  if [[ "${DESTINY_SYNC_ASSET_CATALOG:-1}" == "1" ]]; then
    echo "==> Syncing assets/data catalog to owned media paths"
    python3 "$ROOT/scripts/rebuild_owned_catalog.py" --sync-assets
  fi
else
  echo "==> Skipping media upload (DESTINY_SKIP_MEDIA=1)"
fi

if [[ "${DESTINY_APPLY_OWNED_SEED:-0}" == "1" ]]; then
  if [[ -z "${SUPABASE_ACCESS_TOKEN:-}" ]]; then
    echo "WARN: DESTINY_APPLY_OWNED_SEED=1 but SUPABASE_ACCESS_TOKEN unset" >&2
  else
    echo "==> Applying owned-media seed SQL"
    python3 "$ROOT/scripts/apply_sql_management_api.py" \
      "$ROOT/supabase/seed/inventory_seed_owned_media.sql"
  fi
fi

if [[ -n "${DESTINY_SUPABASE_ANON_KEY:-}" ]]; then
  echo "==> Verifying anon reads + counts"
  python3 "$ROOT/scripts/verify_m2_remote.py"
else
  echo "==> Skipping anon verify (DESTINY_SUPABASE_ANON_KEY unset)"
  echo "    Service-role count check:"
  python3 "$ROOT/scripts/verify_m2_remote.py" --service-role || true
fi

echo "Done. Update docs/m2_status.md after confirming remote evidence."
