# Destiny OS architecture

## Current plane (M2 inventory cutover complete)

```
Flutter UI
  → ApiService
      → SupabaseInventoryRepository (PostgREST + publishable/anon key)
          tours / stays / vehicles / awards
  → DestinyMediaUrl → TravelNetworkImage
      → Destiny Supabase Storage bucket `destiny-media` (owned)
```

On inventory failure the UI shows loading/error/retry. There is **no** silent
fallback to bymapara inventory APIs or `catalog.json` after M2 cutover.

Optional tooling repos (`ChainedInventoryRepository`, asset/Storage catalogs,
`LegacyInventoryRepository`, `CompositeInventoryRepository`) may remain in-tree
for tests/offline tooling — they are **not** wired in `main.dart`.

Legacy bymapara PHP remains for bookings / profiles / travel documents / flight
enquiry persistence only (not inventory lists).

## Ownership

| Concern | Owner |
|---------|-------|
| Canonical public inventory (tours/stays/vehicles/awards) | Destiny Supabase (`xchddfpfzrzhlbbmyhyn`) |
| Public marketing + inventory media | `destiny-media` Storage bucket |
| Customer auth | Firebase Auth (unchanged in M2) |
| Customer bookings / profiles / documents | Legacy bymapara until secure auth bridge (M3/M5) |
| Live flights commerce | Out of scope (M3 / Travelport) |
| Destina AI | Out of scope (M4) |

## Secrets

- Flutter defaults to the **publishable** client key in `DestinySupabaseConfig`
- Overrides: `--dart-define=DESTINY_SUPABASE_ANON_KEY` / `SUPABASE_ANON_KEY`
- **Never** embed `service_role`, DB passwords, or private storage keys in the app

## Auth bridge (deferred)

Sensitive Supabase tables have RLS enabled with **no anon policies**.  
Do not invent `auth.uid()` ownership while Firebase remains the identity provider.
