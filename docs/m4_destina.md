# M4 Destina production assistant

Project: Destiny OS `xchddfpfzrzhlbbmyhyn`

Destina is Destiny Travel & Tours’ official AI travel consultant.

**Conversational-first, tools when authoritative data/actions are required.**

The model reasons. Tools are optional capabilities, not a form to fill in.
Ordinary conversation (greetings, inspiration, packing, seasons, follow-ups,
small talk) is answered directly. Failure to update trip state never suppresses
the natural reply.

```
USER
  → GEMINI / DESTINA
    → decides whether tools are necessary
    → optional allowlisted tool call(s)
    → tool results
    → GEMINI
    → natural final answer
  → Flutter renders cards / actions (never raw JSON)
```

Flutter never calls Gemini. `DESTINA_API_KEY` stays on the Edge Function.

## Knowledge vs live data

| Source | When Destina uses it |
|--------|----------------------|
| **Model knowledge** | Destination advice, inspiration, packing, etiquette, general comparisons, ordinary chat. Frame time-sensitive claims as general, not live. |
| **Destiny catalog** | Published tours/stays/vehicles via `search_tours` / `search_stays` / `search_vehicles` / `get_*_details`. Catalog is not a live hold. |
| **Live Travelport** | Current flight inventory/fares via `search_flights` only after the customer asked to search flights. Quotes, not tickets. |
| **Customer-owned data** | Profile/bookings via JWT-gated tools. Never other customers. |
| **Actions / handoffs** | Enquiry create and consultant handoff after confirmation (or explicit “send to a consultant”). |

Never invent live availability, fares, catalog holds, booking/payment
confirmation, visas, tickets, PNRs, or staff actions.

Label sources:

- **REAL LIVE RESULT** — Travelport quotes via `search_flights`
- **DESTINY CATALOG CONTENT** — published tours/stays/vehicles (not a live hold)
- **CUSTOMER REQUEST / STAFF QUOTE / CONFIRMED BOOKING** — commerce states

## Identity

Warm, confident, conversational, concise, genuinely helpful. One useful
question at a time. Not robotic, not pushy. City names are valid; Destina
never asks customers for IATA codes.

## Tools

`update_trip_state` (optional memory), `search_flights`, `search_tours`,
`search_stays`, `search_vehicles`, `get_*_details`, `get_customer_profile`,
`list_customer_bookings`, `get_booking_status`, `create_travel_enquiry`,
`create_flight_enquiry`, `handoff_to_consultant`.

No arbitrary SQL, HTTP, or Edge Function names.

`update_trip_state` is optional supporting state. A state-only tool call is
followed by another Gemini turn so Destina can still answer naturally.

`search_flights` requires origin, destination, and departure date. Human place
names are resolved with a bounded alias list (Harare→HRE, Johannesburg→JNB,
Zanzibar→ZNZ, Cape Town→CPT, Victoria Falls→VFA, Dubai→DXB). Unknown or
ambiguous airports ask a natural clarification and never reach Travelport.
IATA validation stays at the flight-provider boundary and is never shown as
developer copy in chat.

Enquiries require customer confirmation and a signed-in user. Anonymous users
get `auth_required` — Destina does not fake a submit.

## Tool loop (Gemini 3.6)

Live model: **`gemini-3.6-flash`**. Thinking stays enabled.

Gemini 3.x function calling is a continuation protocol, not a reconstructed
chat transcript:

```
USER
  → GEMINI MODEL FUNCTION CALL + OPAQUE thoughtSignature
  → FUNCTION RESPONSE
  → GEMINI NEXT RESPONSE
```

`thoughtSignature` is opaque provider protocol metadata. Destina:

- captures the original model `Part`s on an internal `providerTurn`
- replays those parts byte-for-byte on the next generate (including
  `thoughtSignature` on the first parallel `functionCall` of each step)
- never interprets, invents, logs, or persists signatures
- never returns them in `DestinaTurnResponse`, Flutter, tool results,
  staff handoff, or enquiry summaries
- never exposes chain-of-thought / `thought: true` text

Missing continuation metadata fails closed with the friendly
`model_unavailable` copy. Destina does not synthesize a fake signature.

Signatures live only in the in-memory tool loop of the current HTTP turn.
They are not stored on `destina_messages`.

## Data

Tables (RLS MODEL A, no anon/authenticated policies):

- `destina_conversations` — `user_id` and/or `anon_session_hash` (SHA-256)
- `destina_messages`
- `destina_tool_runs` — compact summaries only
- `destina_events` — model/tool/handoff/latency; no secrets

## Environment (server-only)

```
DESTINA_MODEL_PROVIDER=gemini
DESTINA_MODEL=gemini-3.6-flash
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

Deterministic scripted model and mocked Gemini HTTP. No paid Gemini calls
in CI.

Live `destina-api` logs `destina_model_provider_error` (`http_status`,
`provider_status`, sanitized `provider_message`) and never returns Google
errors, thought signatures, or chain-of-thought to Flutter.

## Known limitations

- Live Destina replies need `DESTINA_API_KEY` on the Edge Function secrets
- Redeploy `destina-api` for conversational-first Destina (M4.1)
- Real PSPs still unimplemented (M3D)
- Travelport ticketing not implemented
- Private travel-document storage remains a product decision
