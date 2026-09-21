# Destiny OS Roadmap

## M0 — Owned media foundation — COMPLETE
- DestinyMediaUrl + TravelNetworkImage central layer
- Live Supabase `destiny-os` / public `destiny-media` bucket
- Home hero + editorial owned WebP cutover (commit `aa59028`)
- Legacy bymapara media fallback retained

## M1 — Customer travel product — COMPLETE
- Stays list + details premium redesign (agent request flow)
- Vehicles list + details premium redesign (agent request flow)
- Flights enquiry UX (later upgraded to live Travelport shopping in M3C/M3E)
- Shared discovery primitives (`destiny_discovery.dart`)
- Destina assist entry points on Stays / Vehicles / Flights
- Loading / empty / error / retry states
- Responsive grids + desktop booking rails
- Home / Tours left intact; nav indices unchanged
- Final QA repair: web HTML-element media loading for owned Home WebP; Flights public browse (account tabs still protected)

## M2 — Destiny backend migration — COMPLETE
- Inventory + public media live on Destiny Supabase (`xchddfpfzrzhlbbmyhyn`)
- Customer commerce later moved to Edge Functions (M3A+) — no bymapara inventory fallback

## M3 — Live flight shopping (Travelport / GDS) — COMPLETE
- Provider-neutral flight domain + Travelport TripServices adapter
- **Live search works** (HRE↔JNB). GDS `BestCombinablePrice` is normalized
- Ticketing not implemented

## M3D — Payment-ready commerce — LIVE
- Provider-neutral intents, mock QA provider, ledger, refunds, staff visibility
- Real PSP adapters require official docs + credentials (`docs/m3d_payments.md`)

## M3E — Commerce completion + legacy cleanup
- Return selection UX, validated combined totals, isolated travel docs
- See `docs/m3e_commerce.md`

## M4 — Destina production assistant
- Tool-backed planning beyond preview snackbars

## M5 — Private customer documents storage
- Separate private bucket (not `destiny-media`)

## M6 — Ops / agent tooling

## M7 — Growth / personalization
