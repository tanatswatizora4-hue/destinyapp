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
| Tests / analyze / web build | 32 Flutter tests PASS; preflight PASS; analyze/build previously OK | **DONE** (re-verified tests 2026-09-08) |
| Security review doc | `docs/m2_security_review.md` | **DONE** |
| One-shot remote apply + doc finalize | `apply_m2_remote.sh` → verify → `m2_finalize_docs.py` | **DONE** (repo; blocked on secrets) |
| Actions LFS media checkout | `checkout@v4` `lfs: true` + pointer guard + ≥81 files (M2 branch + PR #13) | **DONE** (repo; PR #13 ready/MERGEABLE, awaiting human merge to main) |
| Apply hardening | verify catalog counts + ≥90% owned paths; finalize rewrites migration report + media inventory; Actions defaults to staged upload (no live re-download); owned seed LF-only | **DONE** (repo) |
| Offline preflight | `python3 scripts/m2_preflight.py` PASS (81-file LFS tarball; asset==seed catalog) | **DONE** |

## Hard blocker

```
STOP_REASON=CREDENTIAL_REQUIRED
```

Need `SUPABASE_ACCESS_TOKEN` (Supabase PAT). `apply_m2_remote.sh` bootstraps `service_role` + anon via Management API when unset. Dashboard SQL remains an alternative for schema (`supabase/seed/m2_dashboard_one_paste.sql`).

If the PAT is added in the Cloud Agent environment UI, **start a new agent run** on this branch so it injects into `printenv`.

Last credential recheck (agent): 2026-09-09T00:25Z — still missing credentials; ChatGPT/GitHub SSO expired/logged out; CLI awaiting code; watcher armed; added Dashboard schema+seed one-paste; catalog HTTP 400.

## Resume (closes milestone when verify passes)

```bash
export SUPABASE_URL=https://xchddfpfzrzhlbbmyhyn.supabase.co
export SUPABASE_ACCESS_TOKEN=...   # sufficient alone
bash scripts/apply_m2_remote.sh
# on success: docs auto-finalized; commit; Flutter:
# --dart-define=DESTINY_SUPABASE_ANON_KEY=... --dart-define=DESTINY_INVENTORY_MEDIA_LIVE=true
```
