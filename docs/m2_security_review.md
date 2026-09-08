# M2 security review

Scope: Destiny backend migration scaffolding + intended remote apply to `xchddfpfzrzhlbbmyhyn` only.

## Checks

| Check | Status | Notes |
|-------|--------|-------|
| No `service_role` in Flutter / repo | PASS | Migration script reads env only |
| No DB password committed | PASS | Not present in tree |
| Anon write policies on sensitive tables | PASS (by design) | `customer_profiles`, `enquiries`, `bookings`: RLS on, zero policies |
| Public inventory write from anon | PASS (by design) | SELECT-only policies |
| `USING (true)` on customer tables | PASS | Not used |
| Client-controlled booking price trust | OPEN / deferred | Legacy create_booking still accepts client `total_price`; not ported to Supabase writes |
| GET deletes | OPEN / deferred | Legacy `delete_booking` still GET; not introduced on Supabase |
| Arbitrary user-id writes | OPEN / deferred | Legacy PHP still trusts `user_id` query/body; Supabase sensitive writes disabled |
| Storage public bucket boundaries | PASS guidance | `destiny-media` marketing only; passports/IDs must not use it |
| Never touch Wanzwei project | PASS | Migrations/docs target destiny-os only |

## Residual risks until credentials applied

1. Schema/RLS not yet live on remote — cannot verify policies in production until apply.
2. Until media migration, inventory may still resolve `uploads/` via bymapara (temporary).
3. Composite fallback means a misconfigured empty Supabase table silently serves legacy data (documented; prefer fail-closed only after cutover verification).

## Required follow-up after apply

- Confirm PostgREST rejects anon INSERT on inventory and all sensitive tables
- Confirm published SELECT works with anon key
- Confirm unpublished rows are invisible to anon
- Rotate any key if accidentally pasted into chat/logs
