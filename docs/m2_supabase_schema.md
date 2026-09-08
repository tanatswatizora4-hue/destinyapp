# M2 Supabase schema

Target project: **destiny-os** (`xchddfpfzrzhlbbmyhyn`)  
Never target Wanzwei / `irgkeksrittimdwwxckl`.

Migration file: `supabase/migrations/20260908143000_destiny_inventory_schema.sql`

## Design principles

- UUID primary keys + integer `legacy_id` (unique) for idempotent bymapara import
- `is_published` / `is_featured` for discovery
- `created_at` / `updated_at` with trigger helper `set_updated_at()`
- Prices as `numeric(12,2)` with explicit `currency` (default `USD`)
- Image ownership via Storage path refs (`destiny-media/...`) plus `legacy_url` during cutover
- Metadata JSON only on sensitive stubs (`raw_profile`, enquiry `payload`, booking `item_image_json`)
- No destinations / editorial_content tables yet — legacy has no destination entity; Home editorial is static owned media; awards cover recognition content

## Public inventory

| Table | Key columns |
|-------|-------------|
| `tours` | `legacy_id`, `title`, `description`, `price`, `currency`, `duration`, `is_featured`, `is_published`, `primary_image_path` |
| `tour_images` | `tour_id`, `storage_path`, `legacy_url`, `sort_order` |
| `tour_amenities` | `tour_id`, `name`, `included`, `sort_order` |
| `tour_itinerary_items` | `tour_id`, `date_label`, `location`, `activity`, `description`, `sort_order` |
| `stays` | `legacy_id`, `name`, `type`, location fields, flags, `primary_image_path`, `currency` |
| `stay_images` / `stay_rooms` / `stay_amenities` | children of stays |
| `vehicles` | `legacy_id`, make/model/year/type, `price_per_day`, location, flags |
| `vehicle_images` / `vehicle_features` | children of vehicles |
| `awards` / `award_images` | recognition / editorial-adjacent |

Indexes: published+featured (tours), published+city (stays), published+type (vehicles).

## Sensitive stubs (no public access)

| Table | Purpose |
|-------|---------|
| `customer_profiles` | `firebase_uid`, `legacy_sql_id`, profile fields |
| `enquiries` | kind + payload JSON; write path deferred |
| `bookings` | booking metadata stub; writes deferred |

## Media convention

Prefer:

```
destiny-media/tours/<legacy_id>/primary.webp
destiny-media/stays/<legacy_id>/primary.webp
destiny-media/vehicles/<legacy_id>/primary.webp
destiny-media/awards/<legacy_id>/primary.webp
```

Flutter resolves via `DestinyMediaUrl` → public Storage URL.

## Apply

```bash
# Preferred: Supabase CLI linked ONLY to xchddfpfzrzhlbbmyhyn
supabase db push

# Or paste migration SQL into Destiny OS SQL Editor
```
