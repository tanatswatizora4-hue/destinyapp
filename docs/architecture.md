# Destiny OS architecture

## Current plane (through M2 scaffolding)

```
Flutter UI
  → ApiService / InventoryRepository
      → ChainedInventoryRepository (first non-empty wins; never merges)
          1. SupabaseInventoryRepository (PostgREST + anon key)
          2. StorageCatalogInventoryRepository (public destiny-media/inventory/catalog.json)
          3. AssetCatalogInventoryRepository (bundled Destiny snapshot)
          4. LegacyInventoryRepository (bymapara PHP — last resort)
  → DestinyMediaUrl → TravelNetworkImage
      → Destiny Supabase Storage bucket `destiny-media` (owned)
      → temporary bymapara `uploads/` fallback for unmigrated images
```

## Ownership

| Concern | Owner |
|---------|-------|
| Canonical public inventory (tours/stays/vehicles/awards) | Destiny Supabase (`xchddfpfzrzhlbbmyhyn`) — target after M2 apply |
| Public marketing media | `destiny-media` Storage bucket |
| Customer auth | Firebase Auth (unchanged in M2) |
| Customer bookings / profiles / documents | Legacy bymapara until secure auth bridge (M3/M5) |
| Live flights commerce | Out of scope (M3 / Travelport) |
| Destina AI | Out of scope (M4) |

## Secrets

- Flutter may receive **publishable anon** key via `--dart-define=DESTINY_SUPABASE_ANON_KEY`
- **Never** embed `service_role`, DB passwords, or private storage keys in the app
- Migration tooling uses `SUPABASE_SERVICE_ROLE_KEY` from environment only

## Auth bridge (deferred)

Sensitive Supabase tables have RLS enabled with **no anon policies**.  
Do not invent `auth.uid()` ownership while Firebase remains the identity provider.
