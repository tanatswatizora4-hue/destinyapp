# M3B security review

| Check | Status | Notes |
|-------|--------|-------|
| No `service_role` in Flutter | PASS | Comments/docs only |
| No public write policies on sensitive/staff/events | PASS | Migration enables RLS, zero policies |
| Staff auth not client boolean/role string | PASS | `staff_users` allowlist after Firebase verify |
| Customer cannot set quoted_total/status | PASS | customer-api rejects; staff API separate |
| Quote does not mark paid | PASS | quote_booking keeps/non-sets paid |
| Fake Pay now | PASS | Customer UI shows instructions only |
| Delete-via-GET in new flows | PASS | POST actions only |
| Migrated screens call bymapara booking | PASS | tour/stay/vehicle/flights/my bookings/trips use Destiny APIs |
| Unguarded staff route | PASS | UI route open, API returns 403 without allowlist |

Residual: first staff UID must be seeded by operator (EXTERNAL_ACTION_REQUIRED).
