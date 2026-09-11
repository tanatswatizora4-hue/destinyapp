# AGENTS.md — Destiny

## Active milestone: M3B.5 Auth Ownership Migration

Branch: `cursor/m3b5-supabase-auth-migration-194a`  
Supabase: **`xchddfpfzrzhlbbmyhyn` only** (never Wanzwei).

Destiny owns auth via **Supabase Auth** (not Firebase).

- Flutter → Supabase Auth access token → `customer-api` / `staff-commerce-api`
- Canonical identity: `user_id` → `auth.users.id`
- RLS MODEL A: Edge Functions only for sensitive tables
- Deploy: `docs/m3b5_supabase_auth_migration_runbook.md`
- Audit: `docs/m3b5_auth_migration_audit.md`
- Status: `docs/m3_status.md`

Do **not** invent staff UUIDs. Do not start Travelport/payments.
Never embed `service_role` in Flutter.
`devBypassAuth` is UI-only and must not bypass backend auth.
