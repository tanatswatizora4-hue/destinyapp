#!/usr/bin/env bash
# One-shot M2 apply to destiny-os ONLY (never Wanzwei).
#
# Minimum required:
#   export SUPABASE_ACCESS_TOKEN=...   # PAT — can bootstrap service_role + anon
#
# Or provide keys directly:
#   export SUPABASE_SERVICE_ROLE_KEY=...
#   export DESTINY_SUPABASE_ANON_KEY=...
#   export SUPABASE_ACCESS_TOKEN=...   # still needed for schema unless DESTINY_SKIP_SCHEMA=1
#
# Optional:
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

case "$URL" in
  *xchddfpfzrzhlbbmyhyn*) ;;
  *)
    echo "ERROR: refusing to run against non-destiny-os URL: $URL" >&2
    exit 1
    ;;
esac

# If ACCESS_TOKEN is present, fill missing service_role / anon via Management API.
if [[ -n "${SUPABASE_ACCESS_TOKEN:-}" ]]; then
  if [[ -z "${SUPABASE_SERVICE_ROLE_KEY:-}" || -z "${DESTINY_SUPABASE_ANON_KEY:-}" ]]; then
    echo "==> Bootstrapping Destiny API keys from SUPABASE_ACCESS_TOKEN"
    # shellcheck disable=SC1090
    eval "$(python3 "$ROOT/scripts/m2_bootstrap_keys.py" --export)"
  fi
fi

if [[ -z "${SUPABASE_SERVICE_ROLE_KEY:-}" ]]; then
  echo "ERROR: SUPABASE_SERVICE_ROLE_KEY is required" >&2
  echo "       Provide it directly, or set SUPABASE_ACCESS_TOKEN so keys can be bootstrapped." >&2
  exit 1
fi

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
  echo "==> Ensuring media staging (extract seed tarball if needed)"
  if [[ ! -d /tmp/destiny-media-staging ]] || [[ -z "$(find /tmp/destiny-media-staging -type f 2>/dev/null | head -1)" ]]; then
    TARBALL="$ROOT/supabase/seed/destiny-inventory-media-staged.tar"
    if [[ -f "$TARBALL" ]]; then
      # Resolve Git LFS pointer if needed
      if head -1 "$TARBALL" 2>/dev/null | grep -q 'git-lfs'; then
        (cd "$ROOT" && git lfs pull --include='supabase/seed/destiny-inventory-media-staged.tar')
      fi
      mkdir -p /tmp/destiny-media-staging
      tar -xf "$TARBALL" -C /tmp/destiny-media-staging
      echo "    extracted $TARBALL"
    fi
  fi
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
  echo "==> Finalizing M2 docs from live evidence"
  python3 "$ROOT/scripts/m2_finalize_docs.py"
else
  echo "==> Skipping anon verify (DESTINY_SUPABASE_ANON_KEY unset)"
  echo "    Service-role count check:"
  python3 "$ROOT/scripts/verify_m2_remote.py" --service-role || true
fi

echo "Done. If verify passed: commit doc updates, set DESTINY_INVENTORY_MEDIA_LIVE=true for Flutter."
