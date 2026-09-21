# M3 status

## Complete

| Milestone | Notes |
|-----------|-------|
| M0 | Inventory + media foundation |
| M1 | Customer travel product composition |
| M2 | Destiny Supabase inventory cutover |
| M3A | Secure customer commerce backend (`customer-api`) — **LIVE** |
| M3B | Staff ops + booking lifecycle (`staff-commerce-api`) — **LIVE** |
| M3B.5 | Supabase Auth ownership — **LIVE** |
| M3C | Travelport flight shopping — **LIVE and working** |
| M3D | Payment-ready architecture — **LIVE** (mock QA; real PSPs pending docs) |
| M3E | Commerce completion + legacy cleanup — **LIVE** |

## Current: M5 Internal operations (in repo)

- M4 Destina remains live; Gemini quota is an external M4 concern (not M5)
- M5A–E implemented in repository — apply migrations + redeploy customer-api / staff-commerce-api
- See `docs/m5_internal_ops.md`

## Travelport

Live search works. Confirmed HRE↔JNB (example FN8331 Economy Value Flex GBP 214.10).

The previous “NO OFFERS FOUND FOR THE CHANNEL” note was **not** the current status. The live bug was GDS pricing under `ProductBrandOffering.BestCombinablePrice` rather than `Price`. That normalizer is now in the repo.

No JFK/LAX diagnostic special-case remains.

## Payments

M3D schema + `payment-commerce-api` are live. Platform fee is 0. Mock provider is fail-closed in production. Tooma / Zimswitch / Paynow need official API docs and credentials before implementation.

## Later

- Apply M5 migrations + deploy `customer-api` / `staff-commerce-api`
- Optional: migrate legacy bymapara travel-doc binaries (requires operator credentials)
- Live PSP integration after official docs + credentials
- Optional Google OAuth on Supabase Auth
