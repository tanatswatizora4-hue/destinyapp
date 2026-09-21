# Destiny OS architecture

## Inventory plane (M2 complete)

```
Flutter UI
  → ApiService
      → SupabaseInventoryRepository (PostgREST + publishable/anon key)
  → DestinyMediaUrl → destiny-media Storage
```

## Auth ownership (M3B.5)

```
Flutter
  → Supabase Auth (email/password baseline)
  → access token (Authorization: Bearer)
  → customer-api / staff-commerce-api / payment-commerce-api
  → auth.getUser(token) → user_id = auth.users.id
  → service_role DB ops scoped by user_id
```

Destiny owns authentication, sessions, password reset, email verification,
customer identity, and staff identity via Supabase Auth on project
`xchddfpfzrzhlbbmyhyn`. Firebase Auth is **removed** (old project not controlled).

Canonical identity column: `user_id uuid` → `auth.users(id)`.  
Legacy `firebase_uid` columns remain deprecated/non-authoritative.

## Customer commerce plane (M3A + M3B.5)

```
Flutter (Supabase Auth)
  → customer-api (verify_jwt=true + getUser)
  → user_id ownership on customer_profiles / enquiries / bookings
```

## Staff operations plane (M3B + M3B.5)

```
Flutter Staff Ops (/staff-ops)
  → staff-commerce-api
  → staff_users.user_id allowlist + is_active + role
  → quote / transition / enquiry ops + audit events (actor_user_id)
```

## Payment plane (M3D)

```
Flutter (customer My Bookings / staff-ops Payments)
  → payment-commerce-api (verify_jwt=false for webhooks; getUser for user actions)
  → PaymentProvider adapters (mock QA; Zimswitch/Tooma/Paynow placeholders)
  → payment_intents + append-only ledger + booking confirmation
```

Flutter never supplies authoritative amount, fees, or payment success.

## RLS model: **MODEL A**

Sensitive tables keep RLS enabled with **no** anon/authenticated policies.
Clients never touch commerce/staff tables directly. Edge Functions only.

## Ownership

| Concern | Owner |
|---------|-------|
| Public inventory + media | Destiny Supabase |
| Customer + staff auth | **Supabase Auth** |
| Booking requests / flight enquiries | customer-api |
| Authoritative quotes + lifecycle | staff-commerce-api |
| Payments / ledger / refunds | payment-commerce-api |
| Travel documents / legacy photos | Isolated bymapara SQL (not public Storage; private bucket is a product decision) |
| Live fares | flight-commerce-api (Travelport live search working) |

## Secrets

- Flutter: publishable anon + Supabase Auth access tokens only
- Edge Functions: platform-injected `SUPABASE_SERVICE_ROLE_KEY`
- Never embed `service_role` in the app
- `FIREBASE_PROJECT_ID` no longer required
