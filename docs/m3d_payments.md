# M3D Payment-ready commerce

Project: Destiny OS `xchddfpfzrzhlbbmyhyn`  
Never put credential **values** in this file.

Destiny orchestrates payments. It is not a card processor. Flutter is never
authoritative for payment success, amount, currency, fees, or refunds.

## Architecture

```
Flutter (customer / staff-ops)
  → payment-commerce-api  (provider security boundary)
    → PaymentProvider
      → MockPaymentProvider        (QA only)
      → ZimswitchPaymentProvider   (placeholder)
      → ToomaPaymentProvider       (placeholder)
      → PaynowPaymentProvider      (placeholder)
    → Postgres payment_* tables + booking lifecycle
```

Canonical primitives: `payment_intents`, `payment_attempts`, `payment_events`,
`payment_refunds`, `payment_ledger_entries`, `merchants`, `payment_merchant_config`.

Amounts are `numeric(12,2)` in Postgres and integer **cents** in Edge Functions.

## Auth

| Action | Who | JWT |
|--------|-----|-----|
| `create_payment_intent` | booking owner | required |
| `get_payment_intent` / `list_my_payments` | owner | required |
| `verify_payment` | owner | required |
| `request_refund` | owner | required |
| `mock_simulate_result` | owner, mock only | required |
| `staff_*` | `staff_users` | required |
| provider webhook | none | `verify_jwt=false` + provider secret |

Root `supabase/config.toml`:

```
[functions.payment-commerce-api]
verify_jwt = false
```

Gateway JWT is off so webhooks work. User actions still call `auth.getUser(token)`.

## Payment state machine

`created → pending|requires_action|processing → succeeded|failed|cancelled|expired`

After capture: `succeeded → partially_refunded → refunded`.

Booking confirmation:

- Only trusted server-side payment **success** may move `awaiting_payment → confirmed`.
- Failed / pending / cancelled payments do **not** confirm.
- Duplicate provider events are idempotent (unique `provider_event_id` + ledger keys).
- Staff operational confirm still exists for ops, but does not record a payment.

## Authoritative amounts

On `create_payment_intent` the server loads `bookings.quoted_total` and
`bookings.currency`. Client `amount` / `currency` / `platform_fee` /
`merchant_net` / `payment_status` are ignored or rejected.

Platform technology fee **defaults to 0** via `payment_merchant_config`.
No personal percentages or payout destinations are hardcoded.

## Ledger

Append-only `payment_ledger_entries` (update/delete forbidden). Balanced
debit/credit drafts for:

- customer payment
- processor fee
- platform fee
- merchant payable
- supplier payable
- refund

Unique `idempotency_key` prevents double counting.

## Refunds

Customers/staff may **request** a refund. Amount is capped at captured minus
already-refunded. Status becomes `succeeded` only after provider/server
verification (`staff_process_refund` or a verified webhook). Bookings are not
auto-cancelled on refund.

## Webhook security

- Malformed JSON / missing provider / missing event type → 400
- Mock webhooks require `PAYMENT_MOCK_WEBHOOK_SECRET` header `x-destiny-webhook-secret`
- Mock webhooks refused when mock is disabled
- Real providers return `501 provider_not_configured` until official docs exist
- Do not invent signatures for Zimswitch / Tooma / Paynow
- Never log secrets, PAN, CVV, PIN

## Mock provider safety

`MockPaymentProvider` is fail-closed:

- Allowed only when `PAYMENT_ALLOW_MOCK=true` **and** `DESTINY_ENV` is not `prod`/`production`
- Checkout URL is `destiny-mock://…` (in-app QA dialog)
- Must never be the production processor

QA secrets (operator-set, never commit values):

```
PAYMENT_ALLOW_MOCK=true
DESTINY_ENV=development
PAYMENT_MOCK_WEBHOOK_SECRET=<random>
PAYMENT_PROVIDER=mock
```

Production:

```
DESTINY_ENV=production
# do not set PAYMENT_ALLOW_MOCK
```

## PCI

Destiny OS must never store full card numbers, CVV, PIN, or raw banking
credentials. Prefer hosted/provider checkout. Mock QA does not collect cards.

## Travelport PP (does not block M3D)

Travelport authentication works. The official PP control example still returns
`NO OFFERS FOUND FOR THE CHANNEL`. That is an external inventory/channel
provisioning issue. See `docs/m3c_flight_commerce.md`. No JFK/LAX diagnostic
special-case remains in the repo.

## Real provider integration checklist

Official docs and sandbox credentials are **not** in this repository. Do not
invent endpoints. Before choosing Tooma Pay, Zimswitch, or Paynow, obtain:

1. Official API documentation (checkout, status/verify, refunds, settlement)
2. Sandbox credentials and merchant/account identifiers
3. Supported currencies
4. Hosted checkout or redirect/callback URLs
5. Webhook specification (event IDs, timestamps, signature/shared-secret rules)
6. How processor fees are reported
7. Reconciliation / payout reports
8. PCI / hosted-fields requirements

Then implement the existing `PaymentProvider` adapter (do not scatter provider
calls through Flutter).

## Deploy

```
supabase db push --project-ref xchddfpfzrzhlbbmyhyn
supabase functions deploy payment-commerce-api --project-ref xchddfpfzrzhlbbmyhyn
```

Migration: `supabase/migrations/20260918120000_m3d_payment_commerce.sql`

## Known limitations

- No live Zimswitch / Tooma / Paynow calls until official docs + credentials
- Mock checkout is in-app, not an external PSP page
- Settlement APIs are not integrated; staff can mark reconciled / discrepancy
- Staff operational `awaiting_payment → confirmed` remains for ops override
- Travelport PP inventory remains an external blocker for live flight offers
