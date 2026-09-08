# Destiny Media Migration

Controlled migration from legacy `bymapara.com/uploads` to Destiny-owned
Supabase Storage. This document is the developer manifest for **public
marketing media only**.

## Architecture

```
Flutter UI / models
   → DestinyMediaUrl.resolve(...)
   → TravelNetworkImage
   → Supabase public URL  OR  legacy absolute URL  OR  assets/
```

Central files:

- `lib/config/destiny_media_config.dart` — public project URL / bucket (no secrets)
- `lib/utils/destiny_media_url.dart` — resolver + object-path helpers
- `lib/widgets/travel_network_image.dart` — single network/asset image widget

Do **not** construct Supabase Storage URLs inside screens or cards.

## Bucket

| Setting | Value |
|--------|--------|
| Bucket name | `destiny-media` |
| Access | **Public read** (marketing inventory imagery) |
| Write | Dashboard / CI / admin tooling only (not from Flutter clients) |

Public object URL shape:

```
https://<PROJECT_REF>.supabase.co/storage/v1/object/public/destiny-media/<object-path>
```

## Object layout

```
destiny-media/
  home/
    hero/
    editorial/
  tours/
    <tour-id>/
      primary.webp
      gallery/
  stays/
    <stay-id>/
      primary.webp
      gallery/
  vehicles/
    <vehicle-id>/
      primary.webp
      gallery/
  branding/
  placeholders/
```

### Logical slots (helpers on `DestinyMediaUrl`)

| Slot | Helper / path |
|------|----------------|
| Home hero | `homeHeroObject()` → `home/hero/...` |
| Home editorial / travel partner | `homeEditorialObject()` → `home/editorial/...` |
| Optional Destina visual | `homeDestinaObject()` → `home/editorial/...` |
| Tour primary | `tourPrimaryObject(id)` |
| Tour gallery | `tourGalleryObject(id, file)` |
| Stay primary / gallery | `stayPrimaryObject` / `stayGalleryObject` |
| Vehicle primary / gallery | `vehiclePrimaryObject` / `vehicleGalleryObject` |
| Branding | `brandingObject(file)` |
| Placeholders | `placeholderObject(file)` |

If imagery does not exist yet, keep the intentional in-app placeholder
(`TravelNetworkImage` error/empty state). Do not invent hotlinked stock URLs.

## Naming convention

- Lowercase, hyphenated filenames where practical: `victoria-falls-primary.webp`
- Prefer stable names: `primary.webp`, `gallery-01.webp`
- Avoid spaces and parentheses in **new** uploads (legacy names still resolve)
- Include entity id in the folder, not only the filename

## Formats & dimensions

| Use | Format | Guidance |
|-----|--------|----------|
| Hero / editorial | WebP or high-quality JPEG | ~1600–2400px wide |
| Tour / stay / vehicle cards | WebP or JPEG | ~1200–1600px wide, consistent landscape |
| Thumbnails | Optimized WebP/JPEG | Smaller derivatives when needed |
| Branding | PNG/SVG/WebP as appropriate | Transparent logos as PNG/SVG |

Avoid shipping **AVIF as the only source** for critical inventory until
cross-browser compatibility is verified. WebP (+ JPEG fallback where needed)
is preferred for production inventory.

## Client configuration (public only)

Build/run with dart-defines (no service_role, no DB password):

```bash
flutter run \
  --dart-define=DESTINY_SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co \
  --dart-define=DESTINY_MEDIA_BUCKET=destiny-media
```

Obtain `DESTINY_SUPABASE_URL` from the Supabase dashboard:

**Project Settings → API → Project URL**

The anon/publishable key is **not required** for resolving public Storage object
URLs. Do not embed `service_role` in the Flutter app.

## How references resolve

| Input | Result |
|-------|--------|
| `null` / `""` | Intentional placeholder URL |
| `assets/...` | Returned unchanged (local asset) |
| `https://...` absolute | Normalized once (works for Supabase + legacy hosts) |
| `destiny-media/tours/12/primary.webp` | Supabase public URL when configured |
| `supabase:tours/12/primary.webp` | Same |
| `uploads/example.jpg` | Legacy `https://bymapara.com/uploads/example.jpg` |
| Other relative API paths | Legacy bymapara origin (temporary) |

Encoding: path segments are percent-encoded **once**. Already-encoded `%XX`
sequences are not double-encoded.

## How to add new media

1. Upload the file into the correct folder in the `destiny-media` bucket.
2. Store a Destiny reference in data when the API is ready, e.g.
   `destiny-media/tours/42/primary.webp` **or** the full public HTTPS URL.
3. Flutter models already call `DestinyMediaUrl.resolve` — no widget URL math.
4. Render with `TravelNetworkImage` (preferred) so load/error placeholders stay consistent.

Until the PHP API stores Destiny refs, you may still point CMS rows at full
Supabase HTTPS URLs; `resolve` will normalize them as absolute URLs.

## How to migrate an existing tour

1. Download the tour’s current `uploads/...` images (or re-export masters).
2. Optimize to WebP/JPEG at card/hero sizes above.
3. Upload to `destiny-media/tours/<tour-id>/primary.webp` (+ `gallery/`).
4. Update that tour’s `image_urls_json` (when API migration allows) to either:
   - `["destiny-media/tours/<id>/primary.webp", ...]` or
   - full public HTTPS URLs from Supabase.
5. Leave other tours on legacy `uploads/...` until their turn.
6. Verify in app: card + details show the new image; broken → placeholder.

Do **not** bulk-delete bymapara files until the media checklist is complete.

## What NOT to store in `destiny-media` (public)

- Passports, national IDs, visas scans
- Customer travel documents / booking attachments
- Private profile documents
- Any PII-bearing uploads

Those require a **separate private** bucket and authenticated download flow later.

## Legacy fallback

Legacy bymapara support remains until the media checklist is empty:

- Relative `uploads/...` paths continue to resolve to `https://bymapara.com/...`
- Absolute bymapara HTTPS URLs continue to work
- API host `https://bymapara.com` / `destiny_api.php` is **out of scope** for this phase

## Out of scope (later phases)

- PHP API / database migration
- Booking / auth / business logic changes
- Removing bymapara media fallback
- Generating or scraping stock photography
- Private customer document storage
