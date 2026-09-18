# M3C Flight commerce + Travelport TripServices

Project: Destiny OS `xchddfpfzrzhlbbmyhyn`  
Never put credential **values** in this file.

## Architecture

```
Flutter Flights
  → flight-commerce-api  (provider security boundary)
    → FlightProvider (Destiny domain)
      → TravelportFlightProvider
        → Travelport TripServices
```

Canonical models at the application boundary:

`FlightSearchRequest`, `FlightOffer`, `FlightItinerary`, `FlightSegment`, `Money`, `FlightOfferValidation`.

Flutter never receives raw Travelport JSON, provider access tokens, or secrets.

## Auth vs public

| Action | JWT |
|--------|-----|
| `search_flights` | optional (public shopping) |
| `next_leg_search` | optional |
| `validate_offer` | optional |
| `create_flight_enquiry` | required — identity from `auth.getUser(token)` |

Root `supabase/config.toml`:

```
[functions.flight-commerce-api]
verify_jwt = false
```

Gateway JWT is off so logged-out search works. Customer-owned writes still verify the Supabase access token inside the function. Do **not** set this to `true` or public search will 401 at the gateway.

`customer-api` and `staff-commerce-api` remain `verify_jwt = true` in the **root** config (authoritative for CLI deploy).

## Travelport (official TripServices)

Documented at [Authentication](https://developer.travelport.com/docs/getting-started/authentication) and [Flights API Endpoints](https://developer.travelport.com/docs/flights/general/flights-api-endpoints).

| Step | Detail |
|------|--------|
| Grant | OAuth2 `grant_type=password` |
| Credentials | `username`, `password`, `client_id`, `client_secret` |
| Encoding | `application/x-www-form-urlencoded` |
| Pre-prod token | `https://auth.pp.travelport.net/oauth/token` |
| Prod token | `https://auth.travelport.net/oauth/token` |
| Token TTL | 86,400 seconds — cache and reuse; do not auth per search |
| Pre-prod air | `https://api.pp.travelport.net/11/air/` |
| Prod air | `https://api.travelport.net/11/air/` |
| Search | `POST catalog/search/catalogproductofferings` |
| Next leg | `POST catalog/search/catalogproductofferings/buildnext` |
| Reprice | `POST price/offers/buildfromcatalogproductofferings` |
| Headers | `Authorization: Bearer`, `XAUTH_TRAVELPORT_ACCESSGROUP` and/or `TVP-PCC-CORE`, `Accept-Version` / `Content-Version`, `Accept-Encoding: gzip, deflate`, `TraceId` |

Safe live progression implemented:

**AUTH → SEARCH → NORMALIZE → SELECT → NEXT LEG (return) → AIRPRICE**

Not implemented (financial / ticketing):

- reservation workbench commit
- form of payment
- ticketing
- void/refund

Do not create a paid/ticketed booking to prove integration.

## Secret names only

Set in Destiny Supabase (never in Git, Flutter, docs values, or tests):

```
TRAVELPORT_CLIENT_ID
TRAVELPORT_CLIENT_SECRET
TRAVELPORT_USERNAME
TRAVELPORT_PASSWORD
TRAVELPORT_ACCESS_GROUP
TRAVELPORT_PCC_CORE          # optional alternative/addition to access group
TRAVELPORT_ENV               # pp (default) or prod
TRAVELPORT_API_VERSION       # default 11
```

At least one of `TRAVELPORT_ACCESS_GROUP` or `TRAVELPORT_PCC_CORE` is required for shopping calls.

### Operator commands (type values locally)

```bat
npx.cmd supabase secrets set TRAVELPORT_CLIENT_ID="<SET LOCALLY>" --project-ref xchddfpfzrzhlbbmyhyn
npx.cmd supabase secrets set TRAVELPORT_CLIENT_SECRET="<SET LOCALLY>" --project-ref xchddfpfzrzhlbbmyhyn
npx.cmd supabase secrets set TRAVELPORT_USERNAME="<SET LOCALLY>" --project-ref xchddfpfzrzhlbbmyhyn
npx.cmd supabase secrets set TRAVELPORT_PASSWORD="<SET LOCALLY>" --project-ref xchddfpfzrzhlbbmyhyn
npx.cmd supabase secrets set TRAVELPORT_ACCESS_GROUP="<SET LOCALLY>" --project-ref xchddfpfzrzhlbbmyhyn
npx.cmd supabase secrets set TRAVELPORT_ENV="pp" --project-ref xchddfpfzrzhlbbmyhyn
```

Before production: **rotate** the previously exposed Travelport Client Secret (and password if it was exposed). Update secrets. Confirm old values are absent from source, Git history, logs, docs, fixtures, and build artifacts.

## Deploy

```bat
npx.cmd supabase db push --project-ref xchddfpfzrzhlbbmyhyn
npx.cmd supabase functions deploy flight-commerce-api --project-ref xchddfpfzrzhlbbmyhyn
```

Re-deploy `customer-api` / `staff-commerce-api` only if those bundles changed.

## Live smoke (no secrets in the output)

After secrets are set:

```bat
curl -s -X POST https://xchddfpfzrzhlbbmyhyn.supabase.co/functions/v1/flight-commerce-api ^
  -H "Content-Type: application/json" ^
  -H "apikey: <DESTINY_PUBLISHABLE_KEY>" ^
  -d "{\"action\":\"search_flights\",\"origin\":\"HRE\",\"destination\":\"JNB\",\"departure_date\":\"2026-11-20\",\"trip_type\":\"one_way\",\"adults\":1,\"cabin_class\":\"economy\"}"
```

Success: JSON `status=success` with `data.offers` (possibly empty if the route has no inventory — empty is valid, not fake fares).  
`not_configured` / 503: secrets missing.  
Auth/provider errors: check environment (`pp` vs `prod`) and access group.

Never log or paste access tokens, passwords, or client secrets.

## Database

Migration `20260917120000_m3c_flight_commerce.sql` adds provider-neutral columns on existing `enquiries` and `bookings`:

- `provider`, `provider_offer_ref`, `provider_order_ref`
- `itinerary_snapshot`, `passenger_summary`
- `validated_amount`, `validated_currency`, `offer_expires_at`, `provider_status`

RLS MODEL A unchanged (no client policies). `validated_amount` is a server-side provider snapshot, **not** `quoted_total`. Staff still quote and confirm. No second booking system.

## Flutter

Flights screen: IATA search, cabin, adults/children/infants, results, next-leg for return, AirPrice validation, explicit price-change copy, sign-in to continue, enquiry extras (stay / interchange / taxi). Search state is kept across LoginScreen.

## Staff ops

Product type chips: Tour / Stay / Vehicle / Flight. Flight rows show route, dates, passengers, airline, flights, validated amount, provider reference — not raw Travelport JSON.

## Tests

```bat
deno test supabase/functions/flight-commerce-api
deno test supabase/functions/customer-api
deno test supabase/functions/staff-commerce-api
flutter test
flutter analyze
flutter build web --debug
```

## Known limitations

- Live shopping requires operator-set Travelport secrets (access group included).
- Default environment is pre-production (`TRAVELPORT_ENV=pp`).
- **EXTERNAL BLOCKER — Travelport PP inventory/channel:** Authentication, JWT acquisition, and request processing succeed. The provider’s official pre-production control example (JFK→LAX, 2026-10-18, 1 ADT, AA NDC) still returns `NO OFFERS FOUND FOR THE CHANNEL`. This is a Travelport PP inventory/channel provisioning issue, not a Destiny search bug. No hardcoded JFK/LAX diagnostic special-case remains in the repo. Do not block M3D payments on this.
- No ticketing / PNR commit (later). Payments are M3D (`docs/m3d_payments.md`).
- Airport input is IATA codes, not city-name lookup.
- Google OAuth still deferred (M3B.5).
- Travel Documents remain on legacy bymapara (M3E). M3C adds no new bymapara dependency.
