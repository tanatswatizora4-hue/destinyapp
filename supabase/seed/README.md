# M2 seed artifacts

Generated from live bymapara API on 2026-09-08.

| File | Notes |
|------|-------|
| `inventory_seed.sql` | Legacy image paths — safe after schema alone |
| `inventory_seed_owned_media.sql` | Prefers `destiny-media/...` for 81 staged images; legacy fallback for 3 missing |
| `legacy_inventory_snapshot.json` | Exact API payload used for seed |
| `media_manifest.json` | Mapping + WebP conversion status for upload tooling |

Apply order on **destiny-os only** (`xchddfpfzrzhlbbmyhyn`):

1. `supabase/migrations/20260908143000_destiny_inventory_schema.sql`
2. Upload staged media (`scripts/upload_staged_media.py`) when service_role available
3. `inventory_seed_owned_media.sql` (or run PostgREST migrator)

Do not apply to Wanzwei / any other project.
