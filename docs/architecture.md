# Destiny OS architecture

## Inventory plane (M2 complete)

```
Flutter UI
  → ApiService
      → SupabaseInventoryRepository (PostgREST + publishable/anon key)
          tours / stays / vehicles / awards
  → DestinyMediaUrl → TravelNetworkImage
      → Destiny Supabase Storage bucket `destiny-media` (owned)
```

## Customer commerce plane (M3A)

```
Flutter UI (Firebase Auth)
  → Firebase ID token (short-lived)
  → Edge Function customer-api (verify_jwt=false)
      → verify Firebase JWT via Google JWKS
      → firebase_uid = token.sub only
      → service_role writes to customer_profiles / enquiries / bookings
```

Sensitive tables keep RLS enabled with **no** anon/authenticated policies.
Client never sets ownership, quoted totals, payment status, or lifecycle status.

Legacy bymapara remains for travel documents and some profile photo flows until M3E.

## Ownership

| Concern | Owner |
|---------|-------|
| Canonical public inventory | Destiny Supabase (`xchddfpfzrzhlbbmyhyn`) |
| Public marketing + inventory media | `destiny-media` Storage bucket |
| Customer auth | Firebase Auth |
| Booking requests / flight enquiries / customer profiles | Destiny Edge Function + protected tables (M3A) |
| Travel documents | Legacy bymapara until secure docs (M3E) |
| Live flights commerce | Out of scope (M3C / Travelport) |
| Destina AI | Out of scope (M4) |

## Secrets

- Flutter: publishable anon key + Firebase ID tokens only
- Edge Function runtime: `SUPABASE_SERVICE_ROLE_KEY` (platform-injected)
- **Never** embed `service_role` in the app
