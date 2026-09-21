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

`update_trip_state` is optional supporting state. When Gemini returns useful
natural text **and** only `update_trip_state`, Destina executes the state
update and returns that text — it does **not** call Gemini again solely to
rephrase. A state-only call with no usable text still gets a continuation
turn.

`search_flights` should be called directly for complete flight requests (no
redundant `update_trip_state` round trip). The flight tool updates trip state
from validated arguments. Human place names are resolved with a bounded alias
list (Harare→HRE, Johannesburg→JNB, Zanzibar→ZNZ, Cape Town→CPT, Victoria
Falls→VFA, Dubai→DXB). Countries / multi-airport cities (Japan, Tokyo) stay
ambiguous until the customer names a city/airport — Destina asks naturally and
never invents NRT/HND/KIX. Unknown airports never reach Travelport. IATA
validation stays at the flight-provider boundary and is never shown as
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
Per-model-call timeout 20s; soft request budget 45s.
One bounded Gemini retry for 429 / transient 5xx / network only.
Do not raise timeouts to hide latency.

## Observability (M4.2)

Every Destina chat request gets a `request_id` and emits sanitized structured
events (no customer text, prompts, thought signatures, JWTs, or secrets):

- `destina_request_started`
- `destina_model_call_completed` / `destina_model_retry`
- `destina_tool_started` / `destina_tool_completed`
- `destina_travelport_search_completed`
- `destina_request_completed`
- `destina_request_failed` — **required** for any customer-visible generic
  fallback (`couldn't finish…`, `couldn't reach Destina's language model…`)

Failure stages: `model` | `tool` | `travelport` | `orchestration` |
`persistence` | `airport_resolution` | `unknown_internal`.

Safe error codes include `model_timeout`, `model_429`, `model_5xx`,
`model_invalid_argument`, `model_network_error`, `model_auth_error`,
`airport_ambiguous`, `travelport_timeout`, `travelport_auth`,
`travelport_provider_error`, `orchestration_limit`, `persistence_error`.

## Expected request paths (post M4.2)

### NORMAL CHAT

model calls: 1  
tool calls: 0  
DB operations: load/create conversation, insert user + assistant messages,
turn event  
expected sequential external network hops: Flutter → destina-api → Gemini →
Flutter

### FLIGHT SEARCH (complete explicit request)

model calls: typically 2 (tool call + final synthesis)  
tool calls: 1× `search_flights` (updates trip state from args)  
Travelport calls: 1  
DB operations: same persistence as chat + tool_run row  
expected sequential external network hops: Flutter → destina-api → Gemini →
Travelport → Gemini → Flutter

### CATALOG SEARCH

model calls: typically 2  
tool calls: 1× catalog search  
DB operations: published catalog read + message persistence  
expected sequential external network hops: Flutter → destina-api → Gemini →
Supabase catalog → Gemini → Flutter

### MULTI-TURN INCOMPLETE FLIGHT REQUEST

model calls: 1 per turn (clarification turns stay lightweight)  
tool calls: `update_trip_state` and/or `search_flights` when enough fields exist  
clarification behavior: keep destination (e.g. Japan); ask origin/date; if
destination airport is ambiguous, ask city (Tokyo / Osaka / …) — never call
Travelport until airports resolve

### Token streaming

Not in this checkpoint. Would need SSE/WebSocket from destina-api plus Flutter
stream consumer; defer to a later enhancement.

## Human handoff

Creates a real enquiry with a short Destina brief (summary, trip state,
reason) — not a full transcript. Staff ops shows that brief.

## Testing

```
npx deno@2.1.4 test supabase/functions/destina-api
```

Deterministic scripted model and mocked Gemini HTTP. No paid Gemini calls
in CI.

Live `destina-api` logs structured `destina_*` timing/failure events plus
`destina_model_provider_error` (`http_status`, `provider_status`, sanitized
`provider_message`) and never returns Google errors, thought signatures, or
chain-of-thought to Flutter.

## Known limitations

- Live Destina replies need `DESTINA_API_KEY` on the Edge Function secrets
- Redeploy `destina-api` for M4.2 latency/observability
- Real PSPs still unimplemented (M3D)
- Travelport ticketing not implemented
- Private travel-document storage remains a product decision
- Token streaming deferred (see above)