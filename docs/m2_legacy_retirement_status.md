# M2 legacy retirement status

Classification after M2 scaffolding (credentials not yet applied to remote).

| Dependency | Classification | Notes |
|------------|----------------|-------|
| Inventory reads (`get_tours`, `get_accommodations`, `get_vehicles`, `get_awards`) | RETIRED (from live product path) | Flutter chain no longer calls bymapara for inventory. PostgREST → Storage catalog → bundled Destiny asset. `LegacyInventoryRepository` / `CompositeInventoryRepository` retained for tooling/tests only — **not** wired in `lib/main.dart`. |
| Bundled `assets/data/destiny_inventory_catalog.json` | TEMPORARILY_RETAINED (Destiny-owned interim) | Snapshot 25/36/3/6 with `uploads/` image refs until `apply_m2_remote.sh` uploads media and runs `rebuild_owned_catalog.py --sync-assets` |
| Seed `supabase/seed/destiny_inventory_catalog.json` | READY (owned paths) | 82 `destiny-media/…` + 4 residual `uploads/` (3 missing legacy files + award 2 sharing missing path) |
| Storage catalog `destiny-media/inventory/catalog.json` | BLOCKED (awaiting upload) | Uploaded by `scripts/upload_staged_media.py` / oneshot apply |
| Inventory image `uploads/...` paths | TEMPORARILY_RETAINED | Asset catalog + 3 known missing objects; migrator remaps via `media_manifest.json` for staged files |
| Home owned WebP (`destiny-media/home/...`) | RETIRED (from bymapara) | Already Destiny Storage (M0/M1) |
| Bookings create/list/delete | TEMPORARILY_RETAINED | Sensitive; no secure Firebase→Supabase RLS bridge in M2 |
| Flight enquiry create/list/delete | TEMPORARILY_RETAINED | Same — deferred to M3 auth/server bridge |
| User sync / profile / document photo uploads | TEMPORARILY_RETAINED / MOVED_TO_LATER_MILESTONE | Firebase Auth preserved; private docs = M5 |
| Travel documents list | TEMPORARILY_RETAINED | Customer data |
| `delete_booking` / `delete_flight_booking` via GET | BLOCKED (security debt) | Do not port this pattern to Supabase; fix in later milestone |
| Travelport | MOVED_TO_LATER_MILESTONE | M3 |
| Destina AI | MOVED_TO_LATER_MILESTONE | M4 |
| Firebase Auth migration | MOVED_TO_LATER_MILESTONE | Explicitly out of M2 |

## Claim

**bymapara is NOT fully retired.** Public inventory *API* no longer depends on live PHP; image `uploads/` hosts and account/booking/profile flows remain on legacy until media apply + a secure server-side auth bridge.
