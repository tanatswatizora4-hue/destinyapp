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

## Current: M4 Destina production assistant

Branch: `cursor/m3b5-supabase-auth-migration-194a`

- `destina-api` + Gemini 3.6 Flash (`gemini-3.6-flash`)
- Conversational-first consultant: tools only for live/authoritative data or actions
- Allowlisted tools over Travelport + Destiny catalog + commerce
- Destina chat UI wired from Home / Flights / Tours / Stays / Vehicles / Bookings
- Tool loop replays opaque Gemini thought signatures; never user-facing
- Human place names in trip state; IATA resolved only at flight-search boundary
- M4.2: request_id observability, classified failures, fewer redundant Gemini turns,
  Japan/city ambiguity clarification, one Gemini retry for transient errors
- See `docs/m4_destina.md`

## Travelport

Live search works. Confirmed HRE↔JNB (example FN8331 Economy Value Flex GBP 214.10).

The previous “NO OFFERS FOUND FOR THE CHANNEL” note was **not** the current status. The live bug was GDS pricing under `ProductBrandOffering.BestCombinablePrice` rather than `Price`. That normalizer is now in the repo.

No JFK/LAX diagnostic special-case remains.

## Payments

M3D schema + `payment-commerce-api` are live. Platform fee is 0. Mock provider is fail-closed in production. Tooma / Zimswitch / Paynow need official API docs and credentials before implementation.

## Later

- Redeploy `destina-api` for M4.2 latency/observability
- Live PSP integration after official docs + credentials
- Private travel-document bucket (product decision)
- Optional Google OAuth on Supabase Auth
