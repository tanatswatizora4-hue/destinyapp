# M2 status — evidence audit (2026-09-08)

Target: Destiny Supabase `xchddfpfzrzhlbbmyhyn` only.

| Criterion | Evidence | Status |
|-----------|----------|--------|
| Schema exists on destiny-os | PostgREST `/rest/v1/tours` without key → no API key; with invalid key → Invalid API key; tables not verifiable | **BLOCKED** (not applied remotely) |
| Migrations versioned in repo | `supabase/migrations/20260908143000_destiny_inventory_schema.sql` | **DONE** |
| Public inventory RLS correct | SQL in migration; not live-verified | **IN REPO / NOT LIVE** |
| Sensitive tables protected | RLS on, zero anon policies in SQL | **IN REPO / NOT LIVE** |
| Tours/stays/vehicles/awards migrated to DB | Seed + migrator ready; remote upsert not run | **BLOCKED** |
| Inventory media in destiny-media | 81/84 staged locally; Storage objects not uploaded (catalog HTTP 400) | **BLOCKED** |
| Flutter inventory reads use Supabase | Chain: PostgREST → Storage catalog → **asset catalog** → legacy | **PARTIAL** (asset Destiny snapshot active; PostgREST/Storage pending) |
| Product not depending on live bymapara for inventory | Asset catalog precedes legacy in `ChainedInventoryRepository` | **MOSTLY** (legacy last-resort only; images may still use `uploads/`) |
| Remaining legacy documented | `docs/m2_legacy_retirement_status.md` | **DONE** |
| No secrets committed | Grep/env review | **DONE** |
| Tests / analyze / web build | 28 tests, 0 analyze errors, web debug OK at `ef9ab83` | **DONE** |
| Security review doc | `docs/m2_security_review.md` | **DONE** |

## Hard blocker

`SUPABASE_SERVICE_ROLE_KEY` and/or Dashboard SQL apply + `DESTINY_SUPABASE_ANON_KEY` (and optionally `SUPABASE_ACCESS_TOKEN`).

If secrets are added in the Cloud Agent environment UI, **start a new agent run** (or reboot this environment) so they are injected into `printenv` — this long-running pod may not receive newly saved secrets until restart.

## Resume

Follow `docs/m2_apply_runbook.md`.
