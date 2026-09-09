# M2 status — operator handoff (2026-09-09)

Target: Destiny Supabase `xchddfpfzrzhlbbmyhyn` only.  
Mode: **EXTERNAL_ACTION_REQUIRED** (no agent auth / SSO / credential polling).

| Criterion | Evidence | Status |
|-----------|----------|--------|
| Schema on destiny-os | External operator reports applied; PostgREST asks for API key (not missing relation) | **OPERATOR** |
| Seed SQL for inventory | `scripts/generated/m2_inventory_seed.sql` (idempotent upsert on `legacy_id`) | **READY** |
| Media transfer map | `scripts/generated/m2_media_manifest.json` | **READY** |
| Source audit | Live bymapara == 25/36/3/6; `scripts/generated/m2_source_audit.json` | **DONE** |
| Flutter public client | `DestinySupabaseConfig` + PostgREST repo; dart-define publishable/anon key | **WIRED** |
| Supabase primary read | Chain: PostgREST → Storage catalog → asset catalog | **DONE** |
| Legacy fallback | Inventory images via legacy map until `DESTINY_INVENTORY_MEDIA_LIVE=true`; no bymapara inventory API | **DONE** |

## Stop

```
STOP_REASON=EXTERNAL_ACTION_REQUIRED
```

External Supabase operator must execute `scripts/generated/m2_inventory_seed.sql` and upload media per `scripts/generated/m2_media_manifest.json`.

Regenerate artifacts:

```bash
python3 scripts/generate_m2_operator_artifacts.py
```
