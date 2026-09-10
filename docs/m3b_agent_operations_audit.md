# M3B agent operations audit

Date: 2026-09-10  
Base: M3A `0e95986` on `cursor/m3-secure-customer-backend-194a`  
Target: Destiny Supabase `xchddfpfzrzhlbbmyhyn`

## 1. Authoritative fields already present (M3A)

| Table | Field | Authority |
|-------|-------|-----------|
| `bookings` | `status` | Server-only lifecycle |
| `bookings` | `quoted_total` | Intended staff/server (unused until M3B) |
| `bookings` | `requested_total` | Customer estimate only |
| `bookings` | `payment_status` | Server-only (`none` on create) |
| `bookings` | `firebase_uid` | Derived from verified Firebase token |
| `enquiries` | `status` | Server-only (`received` on create) |
| `enquiries` | `firebase_uid` | Token-derived |

Missing for M3B: quote expiry, customer quote note, internal notes, staff identity table, immutable audit events, enquiry↔booking linkage.

## 2. Legal transitions (baseline adopted)

**Bookings**
```
draft → submitted
submitted → quoted | cancelled
quoted → awaiting_payment | cancelled
awaiting_payment → confirmed | cancelled
confirmed → completed | cancelled
cancelled / completed → terminal
```
Staff quoting from `submitted` sets `quoted_total` and moves to `quoted`.  
Customer cancel: draft|submitted|quoted|awaiting_payment only.  
Staff cancel: any non-terminal state.

**Enquiries**
```
received → in_review | closed
in_review → quoted | closed
quoted → converted | closed
converted / closed → terminal
```

## 3. Staff/admin identity today

**None.** No `staff_users`, no role claims, no internal admin app. Firebase Auth is customer-facing only. No n8n staff workflow wired into this repo for commerce.

## 4. Internal UI to extend

**None worth extending.** M5 is full Internal Destiny OS. M3B adds a minimal, gated staff ops screen (bookings + enquiries queues) outside public nav.

## 5. Must remain server-only

- `quoted_total`, `quote_expires_at`, `customer_quote_note`
- lifecycle `status` / `payment_status`
- `firebase_uid` ownership
- staff role / `is_active`
- audit event writes
- enquiry conversion identity linkage

## 6. bymapara booking ops

| Method | Migrated screens | Status |
|--------|------------------|--------|
| `createBooking` / `createFlightBooking` | unused | legacy residual |
| `getUserBookings` / `deleteBooking` | unused | legacy residual |
| `getMyFlightBookings` / `deleteFlightBooking` | unused | legacy residual |
| Travel docs / profile photo / `syncUserWithSql` | still active | intentional until M3E |

Inventory remains Supabase-only (M2).
