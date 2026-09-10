# Destiny OS architecture

## Inventory plane (M2 complete)

```
Flutter UI
  → ApiService
      → SupabaseInventoryRepository (PostgREST + publishable/anon key)
  → DestinyMediaUrl → destiny-media Storage
```

## Customer commerce plane (M3A)

```
Flutter (Firebase Auth)
  → Firebase ID token
  → customer-api
  → verify token → firebase_uid = sub
  → service_role on customer_profiles / enquiries / bookings
```

## Staff operations plane (M3B)

```
Flutter Staff Ops (/staff-ops)
  → Firebase ID token
  → staff-commerce-api
  → verify token → staff_users allowlist
  → quote / transition / enquiry ops + audit events
```

Sensitive tables and `staff_users` / `*_events` keep RLS enabled with **no**
anon/authenticated policies. Client never sets ownership, quotes, or status.

## Ownership

| Concern | Owner |
|---------|-------|
| Public inventory + media | Destiny Supabase |
| Customer auth | Firebase Auth |
| Booking requests / flight enquiries | customer-api |
| Authoritative quotes + lifecycle | staff-commerce-api |
| Travel documents | Legacy bymapara until M3E |
| Live fares / payments | M3C / M3D |

## Secrets

- Flutter: publishable anon + Firebase ID tokens only
- Edge Functions: platform-injected `SUPABASE_SERVICE_ROLE_KEY`
- Never embed `service_role` in the app
