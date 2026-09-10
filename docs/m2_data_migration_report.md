# M2 data migration report

**Status:** COMPLETE (live destiny-os verified by external operator)  
**Flutter cutover:** COMPLETE  
**Target:** `https://xchddfpfzrzhlbbmyhyn.supabase.co`  
**Bucket:** `destiny-media`

## Verified live counts

| Entity | Count |
|--------|------:|
| Tours | 25 |
| Stays | 36 |
| Vehicles | 3 |
| Awards | 6 |
| tour_images | 34 |
| stay_images | 41 |
| vehicle_images | 5 |
| award_images | 6 |
| Canonical inventory objects in `destiny-media` | 81 |

Legacy inventory media refs on bymapara: **0** (parent + child).

Corrected converted objects (committed in seed/manifest/catalog artifacts):

- `destiny-media/tours/14/gallery-01.webp`
- `destiny-media/vehicles/2/primary.webp`
- `destiny-media/vehicles/3/primary.webp`

## Artifacts (historical + parity)

| Artifact | Purpose |
|----------|---------|
| `supabase/migrations/20260908143000_destiny_inventory_schema.sql` | Schema + RLS + inventory `set_*_updated_at` triggers |
| `supabase/migrations/20260910103000_align_inventory_updated_at_triggers.sql` | Align trigger names with live production |
| `scripts/generated/m2_inventory_seed.sql` | Idempotent inventory upsert |
| `scripts/generated/m2_media_manifest.json` | Legacy → destiny-media map (incl. WebP corrections) |
| Bundled/asset catalogs | Offline snapshots — **not** required for live inventory |

## Not claimed complete

- Bookings / profiles / travel documents / flight enquiry APIs (still bymapara)
- `inventory/catalog.json` is **not** a completion requirement
- Auth / Travelport / Destina (M3+)
