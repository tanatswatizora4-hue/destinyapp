# M3 status

## Complete

| Milestone | Notes |
|-----------|-------|
| M0 | Inventory + media foundation |
| M1 | Customer travel product composition |
| M2 | Destiny Supabase inventory cutover |
| M3A | Secure customer commerce backend (`customer-api`) |
| M3B | Staff ops + booking lifecycle (`staff-commerce-api`) |
| M3B.5 | Supabase Auth ownership — **human live QA passed** |

## Current: M3C Real flight commerce

Branch: `cursor/m3b5-supabase-auth-migration-194a`

- `flight-commerce-api` + Travelport TripServices adapter
- Provider-neutral Destiny flight domain
- Flutter Flights upgraded from enquiry-only to live shopping
- Existing `enquiries` / `bookings` carry flight snapshots (no second CRM)
- Ticketing / paid booking **not** implemented

Live shopping is blocked only on operator-set Travelport **secret names** in Destiny Supabase. See `docs/m3c_flight_commerce.md`.

## M3B.5 final

- Root `supabase/config.toml` commits `verify_jwt=true` for `customer-api` and `staff-commerce-api`
- `devBypassAuth = false` (UI only; never bypasses APIs)
- Identity: Flutter Bearer = Supabase access token; server `getUser` → `auth.users.id`
- Staff: `staff_users.user_id` — seed with a **real** UUID (`docs/m3b5_staff_seed.sql`)
- Firebase Auth runtime remains removed

## Not started / later

- M3D payments
- M3E travel docs migration off bymapara
- Travelport credential rotation before production
- Optional Google OAuth on Supabase Auth
