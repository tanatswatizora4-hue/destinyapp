# M2 data migration report

**Status:** PARTIAL — seed + media staging ready; remote apply blocked on credentials  
**Date:** 2026-09-08  
**Source:** `https://bymapara.com/destiny_api.php`  
**Target:** `https://xchddfpfzrzhlbbmyhyn.supabase.co`  

## Live legacy source counts

| Entity | Source action | Count |
|--------|---------------|------:|
| Tours | `get_tours` | 25 |
| Stays | `get_accommodations` | 36 |
| Vehicles | `get_vehicles` | 3 |
| Awards | `get_awards` | 6 |

## Artifacts prepared (in repo)

| Artifact | Purpose |
|----------|---------|
| `supabase/migrations/20260908143000_destiny_inventory_schema.sql` | Schema + RLS |
| `supabase/seed/inventory_seed.sql` | Idempotent INSERT/UPSERT of all inventory + children (legacy image paths) |
| `supabase/seed/legacy_inventory_snapshot.json` | Raw API snapshot |
| `supabase/seed/media_manifest.json` | 84 image refs → destiny-media object paths |
| `scripts/migrate_inventory_to_supabase.py` | PostgREST upsert migrator |
| `scripts/upload_staged_media.py` | Upload `/tmp/destiny-media-staging` → Storage |
| `scripts/apply_m2_remote.sh` | Orchestrator once service role is present |

## Media staging / conversion

| Metric | Count |
|--------|------:|
| Manifest entries | 84 |
| Ready (bytes > 0) | 81 |
| Converted to WebP | 71 |
| Already WebP (copied) | 2 |
| Kept original after convert fail | 8 |
| Missing (legacy HTTP 404) | 3 |

Owned-path seed: `supabase/seed/inventory_seed_owned_media.sql`  
Missing list: `docs/m2_missing_media.json`

**Status:** remote Storage upload + DB apply still require `SUPABASE_SERVICE_ROLE_KEY`.

## Migrated counts on remote Supabase

| Entity | Source | Upserted | Skipped |
|--------|-------:|---------:|--------:|
| Tours | 25 | — | blocked |
| Stays | 36 | — | blocked |
| Vehicles | 3 | — | blocked |
| Awards | 6 | — | blocked |

## Required to finish remote apply

```bash
export SUPABASE_URL=https://xchddfpfzrzhlbbmyhyn.supabase.co
export SUPABASE_SERVICE_ROLE_KEY=<destiny-os service_role>
# 1) Apply schema SQL in destiny-os SQL Editor (or supabase db push)
# 2) Either paste supabase/seed/inventory_seed.sql OR:
python3 scripts/migrate_inventory_to_supabase.py
# 3) Media:
DESTINY_MIGRATE_MEDIA=1 python3 scripts/migrate_inventory_to_supabase.py
#    or from staging:
python3 scripts/upload_staged_media.py
```

Flutter cutover also needs:

```bash
--dart-define=DESTINY_SUPABASE_ANON_KEY=<publishable anon key>
```
