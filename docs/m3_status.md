# M3 status

## Complete

| Milestone | Notes |
|-----------|-------|
| M0 | Inventory + media foundation |
| M1 | Customer travel product composition |
| M2 | Destiny Supabase inventory cutover |
| M3A | Secure customer commerce backend (`customer-api`) |
| M3B | Staff ops + booking lifecycle (`staff-commerce-api`) |

## Current: M3B.5 Auth Ownership Migration

**Code complete on branch** `cursor/m3b5-supabase-auth-migration-194a`.

- Firebase Auth removed from Flutter runtime
- Supabase Auth email/password + session restore + password reset UX
- DB: `user_id` columns added; `firebase_uid` legacy retained
- Edge: Supabase `getUser` + `verify_jwt=true`; ownership via `user_id`
- Staff allowlist: `staff_users.user_id`
- RLS: MODEL A (no authenticated policies on sensitive tables)

### Live follow-ups (operators)

1. Apply `20260911090000_m3b5_supabase_auth_identity.sql`
2. Deploy `customer-api` + `staff-commerce-api`
3. Configure Auth redirect URLs / email confirmation
4. Seed first admin with real `auth.users` UUID

See `docs/m3b5_supabase_auth_migration_runbook.md`.

## Not started

- M3C Travelport / live fares
- M3D payments
- M3E travel docs migration off bymapara
