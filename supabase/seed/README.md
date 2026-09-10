# M2 seed artifacts

Generated from live bymapara API on 2026-09-08.

| File | Notes |
|------|-------|
| `inventory_seed_owned_media.sql` | **Cutover seed** — prefers `destiny-media/...` for 81 staged images; legacy fallback for 3 missing |
| `inventory_seed.sql` | **Historical only** — legacy `uploads/` primary paths. Do **not** apply for owned-media cutover |
| `legacy_inventory_snapshot.json` | Exact API payload used for seed / migrator |
| `media_manifest.json` | Mapping + conversion status for upload tooling |
| `destiny-inventory-media-staged.tar` | Git LFS tarball (81 files) for Storage upload |

Apply order on **destiny-os only** (`xchddfpfzrzhlbbmyhyn`):

1. `supabase/migrations/20260908143000_destiny_inventory_schema.sql`
2. `supabase/migrations/20260908170000_destiny_media_storage_policies.sql`
3. Upload staged media (`scripts/upload_staged_media.py`) when service_role available
4. Prefer `scripts/migrate_inventory_to_supabase.py` (snapshot + manifest remap); optional `inventory_seed_owned_media.sql`

Do not apply to Wanzwei / any other project.
