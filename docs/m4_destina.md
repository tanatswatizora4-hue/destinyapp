# M4 Destina production assistant

Project: Destiny OS `xchddfpfzrzhlbbmyhyn`

Destina is Destiny Travel & Tours’ official AI travel consultant.

The model reasons. The backend is authoritative. Allowlisted tools act.

```
Customer
  → Destina chat UI
    → destina-api
      → DestinaModelProvider (Gemini Flash, or mock in non-prod tests)
        → allowlisted tools
          → flight-commerce-api domain / Travelport
          → published Destiny catalog
          → customer-api-equivalent enquiry/booking reads
        → structured DestinaTurn
  → Flutter renders cards / actions (never raw JSON)
```

Flutter never calls Gemini. `DESTINA_API_KEY` stays on the Edge Function.

## Identity

Warm, confident, concise, professional. One useful question at a time.

Never invent: live availability, fares, booking/payment confirmation, visas,
tickets, PNRs, or staff actions.

Label sources:

- **REAL LIVE RESULT** — Travelport quotes via `search_flights`
- **DESTINY CATALOG CONTENT** — published tours/stays/vehicles (not a live hold)
- **CUSTOMER REQUEST / STAFF QUOTE / CONFIRMED BOOKING** — commerce states

## Tools

`update_trip_state`, `search_flights`, `search_tours`, `search_stays`,
`search_vehicles`, `get_*_details`, `get_customer_profile`,
`list_customer_bookings`, `get_booking_status`, `create_travel_enquiry`,
`create_flight_enquiry`, `handoff_to_consultant`.

No arbitrary SQL, HTTP, or Edge Function names.

`search_flights` requires origin, destination, departure date (IATA + ISO date)
and reuses Travelport normalization (`Price` / `BestCombinablePrice`).

Enquiries require customer confirmation and a signed-in user. Anonymous users
get `auth_required` — Destina does not fake a submit.

## Data

Tables (RLS MODEL A, no anon/authenticated policies):

- `destina_conversations` — `user_id` and/or `anon_session_hash` (SHA-256)
- `destina_messages`
- `destina_tool_runs` — compact summaries only
- `destina_events` — model/tool/handoff/latency; no secrets

## Environment (server-only)

```
DESTINA_MODEL_PROVIDER=gemini
DESTINA_MODEL=gemini-2.5-flash
DESTINA_API_KEY=<server secret>
DESTINA_ALLOW_MOCK=true          # tests/non-prod only
DESTINY_ENV=production           # mock fail-closed
```

Root `supabase/config.toml`:

```
[functions.destina-api]
verify_jwt = false
```

Logged-out discovery works. Customer-owned tools still call `auth.getUser`.

## Limits

4 model iterations / 6 tools / 2 live flight searches per turn.
Catalog results capped at 5. History truncated to 16 messages.

## Human handoff

Creates a real enquiry with a short Destina brief (summary, trip state,
reason) — not a full transcript. Staff ops shows that brief.

## Testing

```
npx deno@2.1.4 test supabase/functions/destina-api
```

Deterministic scripted model. No paid Gemini calls in CI.

## Known limitations

- Live Destina replies need `DESTINA_API_KEY` on the Edge Function secrets
- Real PSPs still unimplemented (M3D)
- Travelport ticketing not implemented
- Private travel-document storage remains a product decision
