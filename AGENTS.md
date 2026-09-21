# AGENTS.md — Destiny

## Active milestone: M3E Commerce completion + legacy cleanup

Branch: `cursor/m3b5-supabase-auth-migration-194a`  
Supabase: **`xchddfpfzrzhlbbmyhyn` only** (never Wanzwei).

Destiny owns auth via **Supabase Auth** (not Firebase).

- Flutter → Supabase Auth access token → `customer-api` / `staff-commerce-api` / `flight-commerce-api` (enquiry) / `payment-commerce-api`
- Canonical identity: `user_id` → `auth.users.id`
- RLS MODEL A: Edge Functions only for sensitive tables
- Flight shopping: Flutter → `flight-commerce-api` → Travelport (server-side only). Live GDS search works; normalize `Price` and `BestCombinablePrice`.
- Payments: Flutter → `payment-commerce-api` → provider adapters (mock QA; real PSPs later)
- Flutter is never authoritative for payment success, amount, fees, or refunds
- Platform technology fee **defaults to 0**
- Deploy: `docs/m3e_commerce.md`, `docs/m3d_payments.md`, `docs/m3c_flight_commerce.md`
- Status: `docs/m3_status.md`

Do **not** invent staff UUIDs. Do not implement Travelport ticketing.
Do not invent Zimswitch / Tooma / Paynow API details.
Never embed `service_role`, Travelport, or payment provider secrets in Flutter.
`devBypassAuth` is UI-only and must not bypass backend auth.
Root `supabase/config.toml` is authoritative for function `verify_jwt`.
