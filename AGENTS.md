# AGENTS.md — Destiny

## Active milestone: M3C Real flight commerce

Branch: `cursor/m3b5-supabase-auth-migration-194a`  
Supabase: **`xchddfpfzrzhlbbmyhyn` only** (never Wanzwei).

Destiny owns auth via **Supabase Auth** (not Firebase).

- Flutter → Supabase Auth access token → `customer-api` / `staff-commerce-api` / `flight-commerce-api` (enquiry)
- Canonical identity: `user_id` → `auth.users.id`
- RLS MODEL A: Edge Functions only for sensitive tables
- Flight shopping: Flutter → `flight-commerce-api` → Travelport (server-side only)
- Deploy: `docs/m3c_flight_commerce.md` and `docs/m3b5_supabase_auth_migration_runbook.md`
- Status: `docs/m3_status.md`

Do **not** invent staff UUIDs. Do not implement Travelport ticketing or payments.
Never embed `service_role` or Travelport secrets in Flutter.
`devBypassAuth` is UI-only and must not bypass backend auth.
Root `supabase/config.toml` is authoritative for function `verify_jwt`.
