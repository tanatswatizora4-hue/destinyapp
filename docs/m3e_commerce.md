# M3E Commerce completion + legacy cleanup

Project: Destiny OS `xchddfpfzrzhlbbmyhyn`

## Current live state

- Travelport live search **works** (HRE↔JNB confirmed).
- GDS pricing is read from `Price` **or** `BestCombinablePrice` (and camelCase).
- M3D payment schema + `payment-commerce-api` are **live**.
- Real PSPs (Tooma / Zimswitch / Paynow) remain placeholders until official docs + credentials.
- Platform fee remains **0**.

## Customer journey

Discover → search → select outbound → select return (if needed) → trip summary →
**AirPrice/validate** → enquiry → staff quote → awaiting_payment → pay →
server verification → confirmed.

Combined round-trip totals are shown only after provider validation.

## Travel documents

Passport/travel-doc files remain on the isolated legacy bymapara SQL link.
They are **not** stored in public `destiny-media`.

A private Destiny document bucket (signed URLs, no public listing) is a
**product decision** for a later milestone. Do not weaken that by uploading
passports to a public bucket.

## Security

- Payment tables stay RLS MODEL A (no anon/authenticated policies).
- `set_updated_at` and `deny_payment_ledger_mutation` pin `search_path = public`.
- Mock payments remain fail-closed in production (`DESTINY_ENV=production`).
- Leaked-password protection is a **Supabase Auth dashboard** setting (cannot be
  flipped from this repo).
- Edge Function CORS is `POST`/`OPTIONS` with `Access-Control-Allow-Origin: *`
  for Flutter web shopping. Webhooks authenticate with provider secrets, not CORS.
- Do not log raw Travelport payloads or secrets in production.

## External still required

- Official PSP API docs + sandbox credentials
- Dashboard: leaked password protection
- Optional: private travel-docs storage design
