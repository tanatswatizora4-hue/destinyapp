# M3A customer backend audit

Date: 2026-09-10  
Base: M2 checkpoint `559fb4a` (`cursor/m2-destiny-backend-migration-194a`)  
Target: Destiny Supabase `xchddfpfzrzhlbbmyhyn`

## Current (pre-M3A) flows

### Authentication
- Firebase Auth (email/password + Google) via `AuthService` / `LoginScreen`
- `devBypassAuth = true` in `main.dart` skips login gate for UI preview
- Dual identity: Firebase UID + legacy bymapara integer `sqlId` (Firestore + PHP sync)

### Legacy bymapara customer commerce (`ApiService` → `https://bymapara.com`)
| Operation | Risk |
|-----------|------|
| `createBooking` | Client supplies `user_id` + **`total_price`** |
| `createFlightBooking` | Client supplies `user_id` |
| `getUserBookings` / `getMyFlightBookings` / `getTravelDocuments` | IDOR via `user_id` query |
| `deleteBooking` / `deleteFlightBooking` | **Mutating GET**, no ownership proof |
| `syncUserWithSql` | Client-supplied `firebase_uid` |
| `updateUserInSql` / profile | Trusts numeric `id` |

Inventory reads are already Supabase-only (M2) and must stay that way.

### Supabase sensitive stubs (pre-M3A)
Tables `customer_profiles`, `enquiries`, `bookings` existed with RLS enabled and **zero** anon/authenticated policies (correct deny-default). No Edge Functions.

## Security risks addressed by M3A
1. Client-chosen UID / SQL user id for commerce writes
2. Client-authoritative booking totals / payment status / lifecycle status
3. Delete-via-GET
4. No verified server bridge between Firebase and Destiny DB

## Remaining intentionally legacy (not M3A)
- Travel documents list/upload (needs private storage + secure bridge — M3 follow-on)
- Profile photo multipart to bymapara
- Legacy `sqlId` sync still best-effort for Travel Docs / older profile fields
- Agent quoting / payment capture (M3B / M3D)
- Travelport live fares (M3C)

## Navigation / UI notes
- Protected nav indices remain `[5,6,7,8]`
- Flights (4) public browse; submit requires Firebase sign-in
- Booking sheets use “Request submitted” language (not false confirmation)
