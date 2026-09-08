# M2 legacy retirement status

Classification after M2 scaffolding (credentials not yet applied to remote).

| Dependency | Classification | Notes |
|------------|----------------|-------|
| Inventory reads (`get_tours`, `get_accommodations`, `get_vehicles`, `get_awards`) | TEMPORARILY_RETAINED (legacy last-resort only) | Flutter chain: PostgREST → Storage `catalog.json` → **bundled Destiny asset catalog** → legacy PHP. Live bymapara is no longer the primary inventory source. |
| Bundled `assets/data/destiny_inventory_catalog.json` | MOVED_TO_DESTINY (interim) | Destiny-owned snapshot (25/36/3/6); images may still use legacy `uploads/` paths until Storage media upload |
| Storage catalog `destiny-media/inventory/catalog.json` | BLOCKED (awaiting Dashboard upload or service_role) | Upload `supabase/seed/destiny_inventory_catalog.json` to that object path |
| Inventory image `uploads/...` paths | TEMPORARILY_RETAINED | Resolver still supports legacy host; media copy pending service role |
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

**bymapara is NOT fully retired.** Public inventory *will* leave bymapara once migration + cutover complete; account/booking/profile flows remain on legacy until a secure server-side bridge exists.
