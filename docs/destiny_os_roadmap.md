# Destiny OS Roadmap

## M0 — Owned media foundation — COMPLETE
- DestinyMediaUrl + TravelNetworkImage central layer
- Live Supabase `destiny-os` / public `destiny-media` bucket
- Home hero + editorial owned WebP cutover (commit `aa59028`)
- Legacy bymapara media fallback retained

## M1 — Customer travel product — COMPLETE
- Stays list + details premium redesign (agent request flow)
- Vehicles list + details premium redesign (agent request flow)
- Flights honest enquiry UX (not live fare shopping)
- Shared discovery primitives (`destiny_discovery.dart`)
- Destina assist entry points on Stays / Vehicles / Flights
- Loading / empty / error / retry states
- Responsive grids + desktop booking rails
- Home / Tours left intact; nav indices unchanged
- Final QA repair: web HTML-element media loading for owned Home WebP; Flights public browse (account tabs still protected)

## M2 — Destiny backend migration — IN PROGRESS (credential-blocked)
- Legacy audit complete (`docs/m2_legacy_backend_audit.md`)
- Versioned schema + RLS migration in repo (`supabase/migrations/...`)
- Flutter inventory repository layer (PostgREST → Storage catalog → asset; no bymapara inventory API)
- Idempotent migration script ready (`scripts/migrate_inventory_to_supabase.py`)
- Seeds + staged media (81/84) + apply runbook (`docs/m2_apply_runbook.md`)
- Optional GitHub Actions applicator (`.github/workflows/m2-destiny-supabase-apply.yml`; enable on main via PR #13)
- **Blocked:** remote apply needs `SUPABASE_ACCESS_TOKEN` (PAT alone); `apply_m2_remote.sh` bootstraps `service_role` + anon. See `docs/m2_apply_runbook.md`
- Customer bookings/profiles remain on bymapara until auth bridge (intentional)
- See `docs/m2_*` reports for status

## M3 — Live flight shopping (Travelport / GDS)
- Only when real inventory APIs exist
- Replace enquiry-only Flights shopping UX where appropriate

## M4 — Destina production assistant
- Tool-backed planning beyond preview snackbars

## M5 — Private customer documents storage
- Separate private bucket (not `destiny-media`)

## M6 — Ops / agent tooling

## M7 — Growth / personalization
