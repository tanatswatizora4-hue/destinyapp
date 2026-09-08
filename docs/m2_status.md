# M2 status — evidence audit (2026-09-08)

Target: Destiny Supabase `xchddfpfzrzhlbbmyhyn` only.  
Objective: migrate inventory/media from bymapara PHP → Destiny Supabase (schema/RLS, Flutter repos, data+media, legacy retirement docs). **Out of scope:** Firebase Auth, Travelport.

| Criterion | Evidence | Status |
|-----------|----------|--------|
| Schema exists on destiny-os | PostgREST `/rest/v1/tours` without key → missing API key; tables not live-verified | **BLOCKED** (not applied remotely) |
| Migrations versioned in repo | `20260908143000_destiny_inventory_schema.sql` + `20260908170000_destiny_media_storage_policies.sql` | **DONE** |
| Public inventory RLS correct | SQL in migration; not live-verified | **IN REPO / NOT LIVE** |
| Sensitive tables protected | RLS on, zero anon policies in SQL | **IN REPO / NOT LIVE** |
| Tours/stays/vehicles/awards migrated to DB | Snapshot migrator + seed ready; remote upsert not run | **BLOCKED** |
| Inventory media in destiny-media | 81/84 in Git LFS tarball; Storage objects not uploaded (`catalog.json` HTTP 400) | **BLOCKED** |
| Flutter inventory reads use Supabase | Chain: PostgREST → Storage catalog → asset catalog (owned refs; inventory images prefer legacy until `DESTINY_INVENTORY_MEDIA_LIVE=true`) | **PARTIAL** (asset path live; PostgREST/Storage pending) |
| Product not depending on live bymapara for inventory API | Legacy removed from inventory chain in `main.dart`; Tours UI shows 25 journeys from Destiny catalog | **DONE** for inventory API |
| Remaining legacy documented | `docs/m2_legacy_retirement_status.md` | **DONE** |
| No secrets committed | Grep/env review | **DONE** |
| Tests / analyze / web build | 31 tests; analyze 0 errors; `flutter build web --debug` OK | **DONE** |
| Security review doc | `docs/m2_security_review.md` | **DONE** |
| One-shot remote apply + doc finalize | `apply_m2_remote.sh` → verify → `m2_finalize_docs.py` | **DONE** (repo; blocked on secrets) |
| Actions LFS media checkout | `checkout@v4` `lfs: true` + pointer guard + ≥81 files (M2 branch + PR #13) | **DONE** (repo) |
| Offline preflight | `python3 scripts/m2_preflight.py` PASS (81-file LFS tarball) | **DONE** |

## Hard blocker

```
STOP_REASON=CREDENTIAL_REQUIRED
```

Need `SUPABASE_SERVICE_ROLE_KEY` + `SUPABASE_ACCESS_TOKEN` (or Dashboard SQL) + `DESTINY_SUPABASE_ANON_KEY`.

If secrets are added in the Cloud Agent environment UI, **start a new agent run** on this branch so they inject into `printenv`.

## Resume (closes milestone when verify passes)

```bash
export SUPABASE_URL=https://xchddfpfzrzhlbbmyhyn.supabase.co
export SUPABASE_SERVICE_ROLE_KEY=...
export SUPABASE_ACCESS_TOKEN=...
export DESTINY_SUPABASE_ANON_KEY=...
bash scripts/apply_m2_remote.sh
# on success: docs auto-finalized; commit; Flutter:
# --dart-define=DESTINY_SUPABASE_ANON_KEY=... --dart-define=DESTINY_INVENTORY_MEDIA_LIVE=true
```
