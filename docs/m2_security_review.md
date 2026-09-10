# M2 security review

Scope: Destiny inventory + media cutover on `xchddfpfzrzhlbbmyhyn` only.

## Checks

| Check | Status | Notes |
|-------|--------|-------|
| No `service_role` in Flutter / repo | PASS | Publishable client key only; migration scripts read env |
| No DB password committed | PASS | Not present in tree |
| Anon write policies on sensitive tables | PASS (live) | `customer_profiles`, `enquiries`, `bookings`: RLS on, not publicly accessible |
| Public inventory write from anon | PASS (live) | SELECT-only policies |
| `USING (true)` on customer tables | PASS | Not used |
| Client-controlled booking price trust | OPEN / deferred | Legacy create_booking still accepts client `total_price`; not ported |
| GET deletes | OPEN / deferred | Legacy `delete_booking` still GET; not introduced on Supabase |
| Arbitrary user-id writes | OPEN / deferred | Legacy PHP still trusts `user_id`; Supabase sensitive writes disabled |
| Storage public bucket boundaries | PASS | `destiny-media` marketing/inventory media only |
| Never touch Wanzwei project | PASS | destiny-os only |

## Post-cutover notes

1. Live inventory + owned media migration verified externally (25/36/3/6; 81 files).
2. Inventory media defaults to Destiny Storage (`DESTINY_INVENTORY_MEDIA_LIVE=true`).
3. `main.dart` wires **only** `SupabaseInventoryRepository` — no bymapara inventory fallback.
4. Tooling repos (`Composite` / `Legacy` / catalog chain) may remain for tests — not production-wired.
5. Bookings/profile/docs remain on bymapara until M3+ auth bridge.
