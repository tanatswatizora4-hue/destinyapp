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
| M3C | Flight commerce architecture + Travelport adapter (live PP inventory blocked externally) |

## Current: M3D Payment-ready commerce

Branch: `cursor/m3b5-supabase-auth-migration-194a`

- `payment-commerce-api` + provider-neutral payment domain
- Mock/test provider (fail-closed in production)
- Intents, ledger, refunds, webhooks, reconciliation model
- Customer pay UX on `awaiting_payment` bookings
- Staff ops Payments tab
- Platform fee defaults to **0**
- Real Zimswitch / Tooma / Paynow adapters are placeholders pending official docs

See `docs/m3d_payments.md`.

## M3C note

Travelport auth/JWT/API processing work. Official PP control (JFK→LAX) returns
`NO OFFERS FOUND FOR THE CHANNEL` — external inventory/channel provisioning.
No hardcoded diagnostic special-case remains. Does not block M3D.

## M3B.5 final

- Root `supabase/config.toml` commits `verify_jwt=true` for `customer-api` and `staff-commerce-api`
- `devBypassAuth = false` (UI only; never bypasses APIs)
- Identity: Flutter Bearer = Supabase access token; server `getUser` → `auth.users.id`
- Staff: `staff_users.user_id` — seed with a **real** UUID (`docs/m3b5_staff_seed.sql`)
- Firebase Auth runtime remains removed

## Not started / later

- M3E travel docs migration off bymapara + commerce completion / legacy cleanup
- Live PSP integration (Tooma / Zimswitch / Paynow) after official docs + credentials
- Travelport PP inventory/channel provisioning (external)
- Optional Google OAuth on Supabase Auth
