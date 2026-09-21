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

## Current: M3E Commerce completion + legacy cleanup

Branch: `cursor/m3b5-supabase-auth-migration-194a`

- Return-flight two-step selection + provider-validated combined total
- BestCombinablePrice GDS normalization (repo matches live)
- Booking → quote → pay → server confirm
- Travel docs isolated on legacy SQL (not public storage)
- See `docs/m3e_commerce.md`

## Travelport

Live search works. Confirmed HRE↔JNB (example FN8331 Economy Value Flex GBP 214.10).

The previous “NO OFFERS FOUND FOR THE CHANNEL” note was **not** the current status. The live bug was GDS pricing under `ProductBrandOffering.BestCombinablePrice` rather than `Price`. That normalizer is now in the repo.

No JFK/LAX diagnostic special-case remains.

## Payments

M3D schema + `payment-commerce-api` are live. Platform fee is 0. Mock provider is fail-closed in production. Tooma / Zimswitch / Paynow need official API docs and credentials before implementation.

## Later

- M4 Destina production assistant
- Live PSP integration after official docs + credentials
- Private travel-document bucket (product decision)
- Optional Google OAuth on Supabase Auth
