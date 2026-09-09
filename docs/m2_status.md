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

Need `SUPABASE_ACCESS_TOKEN` (Supabase PAT). `apply_m2_remote.sh` / `m2_new_agent_bootstrap.sh` bootstrap `service_role` + anon via Management API when unset. Alternatives: VNC drop file `/tmp/destiny-m2.env` or raw PAT `/tmp/supabase-access-token`, CLI login, Dashboard `m2_dashboard_schema_plus_seed.sql` (schema+rows; media still needs credentials).

If the PAT is added in the Cloud Agent environment UI, **start a new agent run** on this branch so it injects into `printenv`, then run `bash scripts/m2_new_agent_bootstrap.sh`.

Last credential recheck (agent): 2026-09-09T03:57Z — still missing credentials; Dashboard LOGGED_OUT; CLI login refreshed (new session_id); watchers + VNC form `:8765` alive (5s poll + wake-on-drop); catalog HTTP 400; media staging 81 files ready.

## Resume (closes milestone when verify passes)

```bash
bash scripts/m2_new_agent_bootstrap.sh
# = load creds → apply → post-apply doc commit (catalog must be HTTP 200)
# Flutter after live:
# --dart-define=DESTINY_SUPABASE_ANON_KEY=... --dart-define=DESTINY_INVENTORY_MEDIA_LIVE=true
```
