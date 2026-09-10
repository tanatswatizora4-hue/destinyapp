# M2 status — COMPLETE (Flutter cutover checkpoint)

Target: Destiny Supabase `xchddfpfzrzhlbbmyhyn` (`destiny-os`)  
Bucket: `destiny-media`  
Mode: **MILESTONE_COMPLETE** (external DB/media work verified; Flutter cutover done)

| Criterion | Evidence | Status |
|-----------|----------|--------|
| Live inventory migration | tours 25 / stays 36 / vehicles 3 / awards 6 | **DONE** |
| Live image rows | tour_images 34 / stay_images 41 / vehicle_images 5 / award_images 6 | **DONE** |
| Owned media in `destiny-media` | 81 canonical inventory files; 0 bymapara parent/child inventory media refs | **DONE** |
| Converted WebP corrections | `tours/14/gallery-01.webp`, `vehicles/2/primary.webp`, `vehicles/3/primary.webp` | **DONE** |
| RLS | Public inventory SELECT-only; profiles/enquiries/bookings not public | **DONE** |
| `updated_at` triggers | `set_{tours,stays,vehicles,awards}_updated_at` → `set_updated_at` (repo + live) | **DONE** |
| Flutter default client | Production URL + publishable key baked in; dart-define overrides kept | **DONE** |
| Inventory reads | `SupabaseInventoryRepository` only — **no** bymapara / catalog silent fallback | **DONE** |
| Media resolution | `DestinyMediaUrl` → public `destiny-media` Storage | **DONE** |

## Explicit non-goals / not falsely claimed

- **Bookings / profile / travel documents / flight enquiry persistence** still use bymapara PHP via `ApiService` (intentional until M3+ auth bridge).
- **`inventory/catalog.json` is NOT a completion requirement** (optional Storage snapshot only).
- **No credential / SSO / auth polling** required for M2.
- Firebase Auth unchanged; `devBypassAuth` preserved for UI preview.
- Destina remains preview-only (M4). Travelport/flights commerce (M3).

## Stop

```
STOP_REASON=MILESTONE_COMPLETE
```

Do not start M3 from this checkpoint.
