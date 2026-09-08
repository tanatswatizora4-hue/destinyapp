# Destiny OS Roadmap

## M0 — Owned media foundation — COMPLETE
- DestinyMediaUrl + TravelNetworkImage central layer
- Live Supabase `destiny-os` / public `destiny-media` bucket
- Home hero + editorial owned WebP cutover (commit `aa59028`)
- Legacy bymapara media fallback retained

## M1 — Customer travel product — COMPLETE
- Stays list + details premium redesign (agent request flow)
- Vehicles list + details premium redesign (agent request flow)
- Flights honest enquiry UX (not live fare shopping)
- Shared discovery primitives (`destiny_discovery.dart`)
- Destina assist entry points on Stays / Vehicles / Flights
- Loading / empty / error / retry states
- Responsive grids + desktop booking rails
- Home / Tours left intact; nav indices unchanged
- Final QA repair: web HTML-element media loading for owned Home WebP; Flights public browse (account tabs still protected)

## M2 — Destiny backend migration
- Migrate inventory/booking APIs off bymapara PHP
- Destiny-controlled data plane
- Preserve Flutter contracts where possible

## M3 — Live flight shopping (Travelport / GDS)
- Only when real inventory APIs exist
- Replace enquiry-only Flights shopping UX where appropriate

## M4 — Destina production assistant
- Tool-backed planning beyond preview snackbars

## M5 — Private customer documents storage
- Separate private bucket (not `destiny-media`)

## M6 — Ops / agent tooling

## M7 — Growth / personalization
