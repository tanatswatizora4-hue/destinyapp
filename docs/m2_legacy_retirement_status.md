# M2 legacy retirement status

Classification after **live** Destiny inventory + media cutover (2026-09).

| Dependency | Classification | Notes |
|------------|----------------|-------|
| Inventory reads (`get_tours`, `get_accommodations`, `get_vehicles`, `get_awards`) | **RETIRED** | `main.dart` wires `SupabaseInventoryRepository` only. No bymapara inventory fallback. |
| Bundled `assets/data/destiny_inventory_catalog.json` | OFFLINE SNAPSHOT | Not used by production inventory path after cutover; kept for tooling/tests. |
| Storage `inventory/catalog.json` | **NOT a completion gate** | Optional; M2 complete without requiring this object. |
| Inventory image `uploads/...` | **RETIRED for live inventory** | Live DB storage_path values are `destiny-media/...`; 0 bymapara inventory media refs verified. Debug-only remap if `DESTINY_INVENTORY_MEDIA_LIVE=false`. |
| Home owned WebP (`destiny-media/home/...`) | RETIRED (from bymapara) | Destiny Storage (M0/M1), unchanged |
| Bookings create/list/delete | TEMPORARILY_RETAINED | Sensitive; no secure Firebase→Supabase RLS bridge in M2 |
| Flight enquiry create/list/delete | TEMPORARILY_RETAINED | Same — deferred to M3 auth/server bridge |
| User sync / profile / document photo uploads | TEMPORARILY_RETAINED / MOVED_TO_LATER_MILESTONE | Firebase Auth preserved; private docs = M5 |
| Travel documents list | TEMPORARILY_RETAINED | Customer data |
| `delete_booking` / `delete_flight_booking` via GET | BLOCKED (security debt) | Do not port this pattern to Supabase |
| Travelport | MOVED_TO_LATER_MILESTONE | M3 |
| Destina AI | MOVED_TO_LATER_MILESTONE | M4 |
| Firebase Auth migration | MOVED_TO_LATER_MILESTONE | Explicitly out of M2 |

## Claim

**Public inventory + owned media are Destiny-owned.** bymapara is **not** fully
retired: account/booking/profile/document flows remain on legacy until a secure
server-side auth bridge (M3+).
