# M3 status — Booking + Travel Commerce

## M3A — Secure customer backend — COMPLETE (live)

Flutter Firebase Auth → `customer-api` → verified UID → protected tables.

## M3B — Booking lifecycle + staff operations — THIS MILESTONE

**Code status:** implemented on `cursor/m3b-booking-operations-194a`  
**Deploy status:** migration + `staff-commerce-api` + first `staff_users` row required

### Architecture
```
Staff Flutter (Firebase Auth)
  → Firebase ID token
  → staff-commerce-api (verify_jwt=false)
  → verify token + staff_users allowlist (is_active)
  → service_role ops + booking_events / enquiry_events
```

Customers continue through `customer-api` only. Staff privileges are never mixed into customer actions.

### Delivered
- Migration `20260910140000_m3b_staff_ops_and_audit.sql`
- Edge Function `staff-commerce-api`
- Lifecycle rules + Deno tests
- Minimal Staff Ops UI (`/staff-ops`, gated server-side)
- Customer My Bookings quote/status panels
- Flutter tests `test/m3b_staff_commerce_test.dart`
- Docs: `m3b_agent_operations_audit.md`, `m3b_deploy_runbook.md`

### Booking transition matrix
| From | To |
|------|-----|
| draft | submitted, cancelled |
| submitted | quoted, cancelled |
| quoted | awaiting_payment, cancelled |
| awaiting_payment | confirmed, cancelled |
| confirmed | completed, cancelled |
| cancelled / completed | terminal |

Quote sets `quoted_total` and moves `submitted → quoted` without marking paid.

### External action required
1. Apply M3B migration
2. Deploy `staff-commerce-api` (+ redeploy `customer-api` for audit events)
3. Insert first `staff_users` row with a real Firebase UID

See `docs/m3b_deploy_runbook.md`.

---

## M3C — Travelport — not started
## M3D — Payments — not started
## M3E — Legacy retirement — not started

## Stop
```
STOP_REASON=EXTERNAL_ACTION_REQUIRED
```
Do not start M3C/M3D automatically.
