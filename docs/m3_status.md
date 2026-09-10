# M3 status — Booking + Travel Commerce

## M3A — Secure customer backend (THIS MILESTONE)

**Code status:** implemented on branch `cursor/m3-secure-customer-backend-194a`  
**Deploy status:** requires operator apply of migration + Edge Function (see below)

### Architecture
```
Flutter (Firebase Auth)
  → short-lived Firebase ID token (Authorization: Bearer)
  → Supabase Edge Function `customer-api` (verify_jwt=false)
  → verify token via Google JWKS (project destinytravel-1a16e)
  → derive firebase_uid from token.sub only
  → service_role DB ops on customer_profiles / enquiries / bookings
```

Client never receives `service_role`. Client cannot set `firebase_uid`, `quoted_total`, `status`, or `payment_status`.

### Delivered
- Forward migration `20260910120000_m3a_secure_customer_commerce.sql`
- Edge Function `supabase/functions/customer-api`
- Flutter `CustomerApiClient` + `CustomerRepository` / `BookingRepository` / `EnquiryRepository`
- UI wired: tour/stay/vehicle requests, flights enquiry, My Bookings, My Trips
- Tests: `test/m3a_customer_commerce_test.dart` + Deno `commerce_rules_test.ts`
- Docs: `docs/m3a_customer_backend_audit.md`, this file, deploy runbook

### External action required (destiny-os only)
1. Apply migration `supabase/migrations/20260910120000_m3a_secure_customer_commerce.sql`
2. Deploy function:
   ```bash
   supabase functions deploy customer-api --project-ref xchddfpfzrzhlbbmyhyn
   ```
3. Optional secret (defaults to public project id):
   ```bash
   supabase secrets set FIREBASE_PROJECT_ID=destinytravel-1a16e --project-ref xchddfpfzrzhlbbmyhyn
   ```
4. Confirm function config has **verify JWT disabled** (see `supabase/functions/customer-api/config.toml`)
5. Smoke: signed-in Flutter app submits a tour request → row in `bookings` with `status=submitted`, `quoted_total=null`, `firebase_uid` matching token

Do **not** add anon write policies. Do **not** touch Wanzwei.

---

## M3B — Booking lifecycle / agent operations
- Agent tooling to move bookings: submitted → quoted → awaiting_payment → confirmed
- Set authoritative `quoted_total`
- Enquiry triage (in_review / quoted / converted)

## M3C — Travelport
- Live fare shopping / ticketing — **not started**
- Flights remain enquiry-only until then

## M3D — Payments
- Capture against quoted totals only
- Never trust client `total_price`

## M3E — Legacy retirement / hardening
- Retire bymapara booking/enquiry/profile endpoints
- Secure travel documents storage
- Remove delete-via-GET debt
- Tighten `devBypassAuth` for production

## Stop
```
STOP_REASON=EXTERNAL_ACTION_REQUIRED
```
M3A application code is complete; live destiny-os migration + function deploy is the remaining gate. Do not start M3B/M3C/M3D automatically.
