# Agent instructions — Destiny M2 branch

Branch: `cursor/m2-destiny-backend-migration-194a`  
Target: Supabase project **`xchddfpfzrzhlbbmyhyn` only** (never Wanzwei).

## Status — M2 COMPLETE

Live inventory + owned-media migration is verified. Flutter cutover uses Destiny
Supabase as the **only** inventory source:

- Default URL: `https://xchddfpfzrzhlbbmyhyn.supabase.co`
- Default publishable key in `DestinySupabaseConfig` (not `service_role`)
- `ApiService.inventoryRepository = SupabaseInventoryRepository()` in `main.dart`
- Failures → loading/error/retry (no silent bymapara inventory fallback)
- Media: `destiny-media/...` via `DestinyMediaUrl` (inventory live by default)

Do **not** poll Supabase auth, SSO, credentials, or `catalog.json`.  
Do **not** reseed DB, upload media, or touch Wanzwei.

Legacy bymapara remains **only** for bookings / profile / documents / flight
enquiry APIs until M3+.

Never paste `service_role` into the app or chat. Preserve `devBypassAuth` and
Firebase Auth. Do not weaken RLS. Do not start M3 from this branch checkpoint.
