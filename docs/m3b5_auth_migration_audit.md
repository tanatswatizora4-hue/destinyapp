# M3B.5 Auth migration audit — Firebase → Supabase Auth

Date: 2026-09-11  
Base: M3B `442ddf9`  
Target: Destiny Supabase `xchddfpfzrzhlbbmyhyn`

## 1. Runtime Firebase dependencies

| Dependency | Usage |
|------------|-------|
| `firebase_core` | `main.dart` init via `DefaultFirebaseOptions` |
| `firebase_auth` | Login/signup/signout, auth state, ID tokens for Edge Functions |
| `cloud_firestore` | `AuthService` AppUser cache (`users/{uid}`); `Promotion` model |
| `google_sign_in` | Google → Firebase credential (optional path) |
| `lib/firebase_options.dart` | Old developer project `destinytravel-1a16e` |
| `android/app/google-services.json` | Android Firebase config |
| Edge `firebase_verify.ts` | Google JWKS Firebase ID token verify |
| `FIREBASE_PROJECT_ID` | Edge Function secret/default |

## 2. DB fields tied to `firebase_uid`

- `customer_profiles.firebase_uid` (unique)
- `enquiries.firebase_uid`
- `bookings.firebase_uid` (+ indexes)
- `staff_users.firebase_uid` (unique, M3B allowlist)
- `booking_events.actor_firebase_uid`
- `enquiry_events.actor_firebase_uid`
- `bookings.assigned_staff_uid` / `quoted_by_uid` (string UID fields)

## 3. Flutter coupling

- `AuthService`, `LoginScreen`, `AuthWrapper`, dead `auth_screen.dart`
- `NavigationScreen` auth listener + legacy SQL sync
- `ProfileScreen` Firestore + bymapara profile update
- Booking sheets / Flights / My Bookings / My Trips / Staff Ops signed-in checks
- `FirebaseIdTokenProvider` → customer/staff API clients
- `main.dart` `Firebase.initializeApp` + `FirebaseAuth.authStateChanges`

## 4. Edge Function assumptions

- `customer-api` / `staff-commerce-api`: Bearer = Firebase ID token; ownership = `firebase_uid`
- `verify_jwt=false` because tokens were not Supabase JWTs

## 5. Keep vs remove

| Keep | Remove / replace |
|------|------------------|
| Publishable Supabase key + project URL | `firebase_auth`, Firebase init, `firebase_options` runtime |
| Inventory PostgREST (anon) | Firebase JWKS verify |
| Legacy `firebase_uid` columns (deprecated, non-authoritative) | Google Sign-In until OAuth reintroduced on Supabase |
| bymapara travel docs / photo upload (M3E) | Firestore as identity store |
| `cloud_firestore` only if Promotion UI still needs it | Staff allowlist keyed on Firebase UID |

**Decision (implemented):** Removed `firebase_auth`, `firebase_core`, `google_sign_in`, and `cloud_firestore` from runtime. Auth is centralized in `SupabaseAuthService` / `AuthService`. Google OAuth deferred.

## Post-migration code status

Implemented on `cursor/m3b5-supabase-auth-migration-194a`. Live cutover still requires DB migrate, function deploy, Auth URL config, first-admin seed.

## 6. Existing user risk

Old Firebase project is **not controlled**. Passwords/UIDs cannot be imported.  
**Clean identity reset:** users create Destiny accounts on Supabase Auth.  
Copy: “Create your Destiny account to continue.” No fake migration claims.

## Chosen RLS model: **MODEL A**

Client never directly reads/writes sensitive tables. Edge Functions only after verified Supabase Auth. No authenticated policies added on commerce/staff tables.
