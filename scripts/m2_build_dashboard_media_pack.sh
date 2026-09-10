#!/usr/bin/env bash
# Build a Dashboard-ready media pack for Option C (no PAT required for the agent).
# Output: /tmp/m2-dashboard-media-pack.tar
# Contents (bucket-relative keys for destiny-media):
#   inventory/catalog.json
#   tours/... stays/... vehicles/... awards/...  (81 files)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAGING="${DESTINY_MEDIA_STAGING:-/tmp/destiny-media-staging}"
TARBALL="$ROOT/supabase/seed/destiny-inventory-media-staged.tar"
CATALOG="$ROOT/supabase/seed/destiny_inventory_catalog.json"
OUT="${M2_DASHBOARD_MEDIA_PACK:-/tmp/m2-dashboard-media-pack.tar}"
WORK="$(mktemp -d /tmp/m2-dash-pack.XXXXXX)"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

if [[ ! -f "$CATALOG" ]]; then
  echo "ERROR: missing $CATALOG" >&2
  exit 1
fi

if [[ ! -d "$STAGING" ]] || [[ -z "$(find "$STAGING" -type f 2>/dev/null | head -1)" ]]; then
  if [[ -f "$TARBALL" ]] && ! head -1 "$TARBALL" | grep -q 'git-lfs'; then
    mkdir -p "$STAGING"
    tar -xf "$TARBALL" -C "$STAGING"
  else
    echo "ERROR: no staging media at $STAGING (and LFS tarball missing/unresolved)" >&2
    exit 1
  fi
fi

files="$(find "$STAGING" -type f | wc -l | tr -d ' ')"
if [[ "$files" -lt 81 ]]; then
  echo "ERROR: expected ≥81 staged files, got $files" >&2
  exit 1
fi

mkdir -p "$WORK/inventory"
cp "$CATALOG" "$WORK/inventory/catalog.json"
# Staging members are already tours|stays|vehicles|awards/...
for kind in tours stays vehicles awards; do
  if [[ -d "$STAGING/$kind" ]]; then
    cp -a "$STAGING/$kind" "$WORK/$kind"
  fi
done

tar -cf "$OUT" -C "$WORK" .
count="$(tar -tf "$OUT" | grep -c . || true)"
echo "Wrote $OUT ($count members; staging files=$files + inventory/catalog.json)"
echo "Upload all members into Storage bucket destiny-media (preserve paths)."
