# M2 status — evidence audit (2026-09-08)

Target: Destiny Supabase `xchddfpfzrzhlbbmyhyn` only.

| Criterion | Evidence | Status |
|-----------|----------|--------|
| Schema exists on destiny-os | PostgREST `/rest/v1/tours` without key → missing API key; tables not live-verified | **BLOCKED** (not applied remotely) |
| Migrations versioned in repo | `20260908143000_destiny_inventory_schema.sql` + `20260908170000_destiny_media_storage_policies.sql` | **DONE** |
| Public inventory RLS correct | SQL in migration; not live-verified | **IN REPO / NOT LIVE** |
| Sensitive tables protected | RLS on, zero anon policies in SQL | **IN REPO / NOT LIVE** |
| Tours/stays/vehicles/awards migrated to DB | Snapshot migrator + seed ready; remote upsert not run | **BLOCKED** |
| Inventory media in destiny-media | 81/84 in Git LFS tarball `supabase/seed/destiny-inventory-media-staged.tar`; Storage objects not uploaded (`catalog.json` HTTP 400) | **BLOCKED** |
| Flutter inventory reads use Supabase | Chain: PostgREST → Storage catalog → asset catalog (owned `destiny-media/` refs + legacy image fallback) | **PARTIAL** (asset owned paths active; PostgREST/Storage pending credentials) |
| Product not depending on live bymapara for inventory API | Legacy removed from inventory chain in `main.dart` | **DONE** for inventory API (image `uploads/` host may remain until media migrate) |
| Remaining legacy documented | `docs/m2_legacy_retirement_status.md` | **DONE** |
| No secrets committed | Grep/env review | **DONE** |
| Tests / analyze / web build | 31 tests pass; analyze 0 errors (baseline infos/warnings); `flutter build web --debug` OK at `f5238ba` | **DONE** |
| Security review doc | `docs/m2_security_review.md` | **DONE** |
| One-shot remote apply | `scripts/apply_m2_remote.sh` (schema + snapshot upsert with manifest remap + staged media + catalog + optional asset sync + verify) | **DONE** (repo; blocked on secrets) |
| Migrator remaps to destiny-media via manifest | `scripts/migrate_inventory_to_supabase.py` + unit tests | **DONE** (repo) |
| Primary image path patched on upload | `scripts/upload_staged_media.py` patches parent `primary_image_path` | **DONE** (repo) |

## Hard blocker

```
STOP_REASON=CREDENTIAL_REQUIRED
```

Need `SUPABASE_SERVICE_ROLE_KEY` + `SUPABASE_ACCESS_TOKEN` (or Dashboard SQL) + `DESTINY_SUPABASE_ANON_KEY`.

If secrets are added in the Cloud Agent environment UI, **start a new agent run** on this branch so they inject into `printenv`.

Supabase Dashboard on the agent VM is **not logged in** (login page ready for human VNC).

## Resume

Follow `docs/m2_apply_runbook.md` Option A:

```bash
bash scripts/apply_m2_remote.sh
```
