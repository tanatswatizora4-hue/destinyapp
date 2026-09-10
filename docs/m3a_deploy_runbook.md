# M3A deploy runbook (destiny-os only)

Project ref: **xchddfpfzrzhlbbmyhyn**  
Never target Wanzwei. Never put `service_role` in Flutter.

## 1. Apply SQL migration

In Destiny SQL editor (privileged) run:

`supabase/migrations/20260910120000_m3a_secure_customer_commerce.sql`

Confirm:
- `bookings.status` check includes submitted/quoted/…/completed
- `bookings.requested_total` / `quoted_total` exist
- `enquiries.status` check includes received/in_review/quoted/converted/closed
- RLS still enabled with **no** new anon/authenticated policies on sensitive tables

## 2. Deploy Edge Function

```bash
supabase login   # or SUPABASE_ACCESS_TOKEN
supabase functions deploy customer-api --project-ref xchddfpfzrzhlbbmyhyn
supabase secrets set FIREBASE_PROJECT_ID=destinytravel-1a16e --project-ref xchddfpfzrzhlbbmyhyn
```

Ensure JWT verification at the gateway is **off** for this function (`verify_jwt = false`).  
The function verifies Firebase ID tokens itself.

`SUPABASE_URL` + `SUPABASE_SERVICE_ROLE_KEY` are injected by Supabase for Edge Functions — do not commit them.

## 3. Flutter

No dart-defines required for production defaults:

- Customer API: `https://xchddfpfzrzhlbbmyhyn.supabase.co/functions/v1/customer-api`
- Publishable anon key already defaults in `DestinySupabaseConfig` (gateway `apikey` header only)

Emergency rollback:

```bash
flutter run --dart-define=DESTINY_CUSTOMER_API_ENABLED=false
```

(That disables the new client; do not re-enable unsafe bymapara writes without an explicit product decision.)

## 4. Smoke checks

1. Sign in with Firebase
2. Submit tour/stay/vehicle request → My Bookings shows **Request submitted**
3. Submit flight enquiry → My Trips shows enquiry
4. Cancel eligible booking → status cancelled
5. Confirm DB: `firebase_uid` matches Auth user; `quoted_total` is null; `payment_status` is `none`
6. Confirm PostgREST anon cannot INSERT into `bookings` / `enquiries` / `customer_profiles`
