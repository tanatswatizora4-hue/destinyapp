# M2 Phase 1 — Legacy backend audit (bymapara / destiny_api.php)

Factual inventory of the Destiny Flutter client’s dependency on the legacy PHP API at `https://bymapara.com/destiny_api.php`. Scope: client contracts only (`lib/`, tests, existing docs). Server-side PHP/SQL schema is **not in this repo**.

**Repo search (Phase 1):**

| Needle | Result |
|--------|--------|
| `bymapara` | **23** string occurrences across 7 files before this audit (`lib/`, `test/`, prior `docs/`); this file adds further mentions |
| `destiny_api.php` | All live API calls in `lib/services/api_service.dart` (14 action URLs) |
| `uploads/` | Legacy media path convention; resolved by `DestinyMediaUrl` to `https://bymapara.com/uploads/...` |
| `ApiService` | Single class: `lib/services/api_service.dart`; consumed by screens + `AuthService` |

---

## 1. Hardcoded URLs / hosts

| Location | Value | Role |
|----------|-------|------|
| `ApiService._baseUrl` | `https://bymapara.com` | All PHP API traffic |
| `DestinyMediaUrl.mediaHost` / `mediaOrigin` | `bymapara.com` / `https://bymapara.com` | Legacy relative media fallback |
| `DestinyMediaUrl.placeholder` | `https://placehold.co/800x600/...` | Missing image placeholder |
| `Award.mainImageUrl` fallback | `https://placehold.co/100x100/...` | Award empty gallery |
| `DestinyMediaConfig.productionSupabaseUrl` | `https://xchddfpfzrzhlbbmyhyn.supabase.co` | Owned media (M0); not PHP API |
| `app_strings.dart` | Facebook / Instagram / Twitter / LinkedIn | Marketing only |
| `contact_screen.dart` | `https://wa.me/263779770430` | WhatsApp |

No API key, Bearer token, or Firebase ID token is attached to `destiny_api.php` requests.

---

## 2. ApiService — method signatures & endpoints

Base: `GET|POST https://bymapara.com/destiny_api.php?action=<name>`

Common response envelope (client-assumed): `{ "status": "success"|"…", "message"?: string, "data"?: … }`.

### Exact Dart signatures

```dart
Future<void> createBooking({
  required int sqlId,
  required int itemId,
  required String itemType,
  required int numTravelers,
  required double totalPrice,
  DateTime? startDate,
  DateTime? endDate,
});

Future<void> createFlightBooking({
  required int userId,
  required String origin,
  required String destination,
  List<String> midPlaces = const [],
  required int numTravelers,
  required bool isEnquiry,
  required bool needsAccommodation,
  required bool needsInterchangeAssistance,
  required bool needsTaxi,
  DateTime? departureDate,
  DateTime? returnDate,
});

Future<List<Booking>> getUserBookings(int sqlId);
Future<void> deleteBooking(int bookingId);

Future<Map<String, dynamic>> syncUserWithSql(
  String firebaseUid, String fullName, String email);

Future<void> updateUserInSql({
  required int sqlId,
  required String fullName,
  required String email,
  required String phone,
  File? facePhotoFile,
  File? passportPhotoFile,
});

Future<AppUser> getUserProfile(int sqlId);

Future<List<Map<String, dynamic>>> getMyFlightBookings(int userId);
Future<void> deleteFlightBooking(int bookingId);
Future<List<Map<String, dynamic>>> getTravelDocuments(int userId);

Future<List<Tour>> getTours();
Future<List<Accommodation>> getAccommodations();
Future<List<Vehicle>> getVehicles();
Future<List<Award>> getAwards();
```

---

### Per-action audit

#### `create_booking` — WRITE

| | |
|--|--|
| **HTTP** | `POST` JSON |
| **Body fields** | `user_id`, `item_id`, `item_type`, `num_travelers`, `total_price`, `start_date` (YYYY-MM-DD), `end_date` (YYYY-MM-DD) |
| **`item_type` values used** | `'tour'`, `'accommodation'`, `'vehicle'` |
| **UI** | `tour_details_screen.dart`, `accommodation_details_screen.dart`, `vehicle_details_screen.dart` booking sheets |
| **R/W** | Write |
| **Security** | No auth header; trusts client-supplied `user_id` (sqlId) and `total_price` (client-computed). IDOR / price-tamper risk. |
| **Supabase dest** | `bookings` (+ optional `booking_items`); FK to inventory tables |
| **Unknowns** | Server validation of price/availability; payment pipeline; whether `status` defaults server-side |

#### `create_flight_booking` — WRITE

| | |
|--|--|
| **HTTP** | `POST` JSON |
| **Body fields** | `user_id`, `origin`, `destination`, `mid_places` (comma-joined string), `num_travelers`, `is_enquiry`, `needs_accommodation`, `needs_interchange_assistance`, `needs_taxi`, `departure_date`, `return_date` |
| **UI** | `flights_screen.dart` (enquiry-only; `isEnquiry: true`) |
| **R/W** | Write |
| **Security** | Same unauthenticated `user_id` trust; spam/enquiry flood possible |
| **Supabase dest** | `flight_enquiries` (or `flight_bookings` with `is_enquiry` flag) |
| **Unknowns** | Whether non-enquiry rows exist server-side; agent workflow columns |

#### `get_user_bookings` — READ

| | |
|--|--|
| **HTTP** | `GET` `user_id=` |
| **Maps to** | `Booking.fromJson` |
| **UI** | `my_bookings_screen.dart` |
| **Security** | Query-param `user_id` only → IDOR if API unauthenticated |
| **Supabase dest** | `bookings` (RLS by `auth.uid()` / profile link) |
| **Unknowns** | Join source for `item_name` / `item_image_json` (server join vs denormalized) |

#### `delete_booking` — WRITE

| | |
|--|--|
| **HTTP** | **`GET`** `id=` (mutating via GET) |
| **UI** | `my_bookings_screen.dart` |
| **Security** | No ownership proof; CSRF-friendly GET delete; IDOR |
| **Supabase dest** | `bookings` delete/soft-delete with RLS |
| **Unknowns** | Soft vs hard delete; cascade |

#### `sync_firebase_user` — WRITE (upsert)

| | |
|--|--|
| **HTTP** | `POST` JSON |
| **Body fields** | `firebase_uid`, `full_name`, `email` |
| **Returns** | `data` map; client reads `data['id']` as SQL int |
| **UI / callers** | `AuthService._syncAndupdateUser`; `NavigationScreen` auth listener |
| **Security** | Anyone who knows/guesses a Firebase UID+email can upsert; no Firebase token verified by PHP |
| **Supabase dest** | `profiles` (or `users`) keyed by `auth.users.id`; sync may become unnecessary if Supabase Auth replaces dual-store |
| **Unknowns** | Conflict rules (email vs uid); returned field set beyond `id` |

#### `update_user_profile` — WRITE (multipart)

| | |
|--|--|
| **HTTP** | `POST` multipart |
| **Fields** | `id`, `full_name`, `email`, `phone` |
| **Files** | `face_photo`, `passport_photo` (optional JPEG) |
| **UI** | `profile_screen.dart` → `AuthService.updateUserProfile` |
| **Security** | Unauthenticated profile + PII photo upload by numeric `id`; sensitive docs |
| **Supabase dest** | `profiles` columns + **private** Storage bucket (M5) for face/passport |
| **Unknowns** | Where PHP stores files (`uploads/`?); URL format returned later |

#### `get_user_profile` — READ

| | |
|--|--|
| **HTTP** | `GET` `id=` |
| **Response fields used** | `firebase_uid`, `email`, `full_name`, `phone`, `id`, `face_photo_url`, `passport_photo_url` |
| **UI** | **None** — defined but unused in `lib/` |
| **Security** | Unauthenticated PII + document URLs by id |
| **Supabase dest** | `profiles` |
| **Unknowns** | Dead client path; whether ops tools use it |

#### `get_my_flight_bookings` — READ

| | |
|--|--|
| **HTTP** | `GET` `user_id=` |
| **UI fields used** | `id`, `origin`, `destination`, `mid_places`, `departure_date`, `return_date`, `num_travelers`, `created_at`, `status` |
| **UI** | `my_trips_screen.dart` |
| **Security** | IDOR via `user_id` |
| **Supabase dest** | `flight_enquiries` / `flight_bookings` |
| **Unknowns** | Full column set (needs_* flags not shown in UI); status enum values |

#### `delete_flight_booking` — WRITE

| | |
|--|--|
| **HTTP** | **`GET`** `id=` |
| **UI** | `my_trips_screen.dart` cancel |
| **Security** | Same as `delete_booking` |
| **Supabase dest** | soft-delete / status=`Cancelled` preferred |
| **Unknowns** | Whether cancel is status update vs row delete |

#### `get_travel_documents` — READ

| | |
|--|--|
| **HTTP** | `GET` `user_id=` |
| **UI fields used** | `title`, `notes`, `doc_url` |
| **UI** | `travel_documents_screen.dart` (opens `doc_url` via `url_launcher`) |
| **Security** | IDOR; `doc_url` may be public/guessable |
| **Supabase dest** | `travel_documents` + private Storage (M5); signed URLs |
| **Unknowns** | Upload path (no client upload API); who creates docs (ops only?) |

#### `get_tours` — READ (public catalog)

| | |
|--|--|
| **HTTP** | `GET` |
| **Maps to** | `Tour.fromJson` |
| **UI** | `home_screen.dart`, `tour_list_screen.dart` |
| **Security** | Public read OK; confirm no private fields |
| **Supabase dest** | `tours` (+ JSON/jsonb for amenities/itinerary/images or child tables) |
| **Unknowns** | Soft-delete / draft flags; sort order |

#### `get_accommodations` — READ

| | |
|--|--|
| **HTTP** | `GET` |
| **Maps to** | `Accommodation.fromJson` |
| **UI** | `home_screen.dart`, `accommodation_list_screen.dart` |
| **Supabase dest** | `accommodations` / `stays` |
| **Unknowns** | Same as tours |

#### `get_vehicles` — READ

| | |
|--|--|
| **HTTP** | `GET` |
| **Maps to** | `Vehicle.fromJson` |
| **UI** | `home_screen.dart`, `vehicle_list_screen.dart` |
| **Supabase dest** | `vehicles` |
| **Unknowns** | Same as tours |

#### `get_awards` — READ

| | |
|--|--|
| **HTTP** | `GET` |
| **Maps to** | `Award.fromJson` |
| **UI** | **None** — Home awards are hardcoded `AwardCard`s; method unused |
| **Supabase dest** | `awards` (optional; may stay CMS/static) |
| **Unknowns** | Whether production PHP still returns data |

---

## 3. Models — JSON field names

### Tour (`lib/models/tour.dart`)

| Dart property | JSON key | Notes |
|---------------|----------|-------|
| `id` | `id` | int |
| `title` | `title` | |
| `description` | `description` | |
| `price` | `price` | |
| `duration` | `duration` | string |
| `isFeatured` | `is_featured` | `'1'` → true |
| `imageUrls` | `image_urls_json` | **stringified JSON array** |
| `amenities` | `amenities_json` | stringified `[{name, included}]` |
| `itinerary` | `itinerary_json` | stringified `[{date, location, activity, description}]` |

Media: `mainImageUrl` / `resolvedImageUrls` via `DestinyMediaUrl.resolve`.

### Accommodation (`lib/models/accommodation.dart`)

| Dart property | JSON key |
|---------------|----------|
| `id` | `id` |
| `name` | `name` |
| `type` | `type` |
| `description` | `description` |
| `address` | `address` |
| `city` | `city` |
| `country` | `country` |
| `isFeatured` | `is_featured` |
| `imageUrls` | `image_urls_json` |
| `amenities` | `amenities_json` |
| `roomTypes` | `room_types_json` → `[{name, price, capacity}]` |

### Vehicle (`lib/models/vehicle.dart`)

| Dart property | JSON key |
|---------------|----------|
| `id` | `id` |
| `make` | `make` |
| `model` | `model` |
| `year` | `year` |
| `type` | `type` |
| `pricePerDay` | `price_per_day` |
| `address` | `address` |
| `city` | `city` |
| `country` | `country` |
| `isFeatured` | `is_featured` |
| `imageUrls` | `image_urls_json` |
| `amenities` | `amenities_json` |

No `description` field on vehicle model.

### Award (`lib/models/award.dart`)

| Dart property | JSON key |
|---------------|----------|
| `id` | `id` |
| `name` | `name` |
| `description` | `description` |
| `year` | `year` |
| `imageUrls` | `image_url_json` (**singular `url`** — inconsistent with `image_urls_json`) |

### Booking (`lib/models/booking.dart`)

| Dart property | JSON key |
|---------------|----------|
| `id` | `id` |
| `userId` | `user_id` |
| `itemName` | `item_name` |
| `itemType` | `item_type` |
| `itemImageUrl` | from `item_image_json` (stringified URL array → first → resolve) |
| `startDate` | `start_date` |
| `endDate` | `end_date` |
| `numberOfTravelers` | `num_travelers` |
| `totalPrice` | `total_price` |
| `paymentStatus` | `status` |

### AppUser (`lib/models/user.dart`)

Not from PHP list endpoints. Dual source:

| Field | Firestore | PHP `get_user_profile` / sync |
|-------|-----------|-------------------------------|
| `uid` | doc id | `firebase_uid` |
| `email` | `email` | `email` |
| `displayName` | `displayName` | `full_name` |
| `phone` | `phone` | `phone` |
| `isSubscribed` | `isSubscribed` | — |
| `sqlId` | `sqlId` | `id` |
| `facePhotoUrl` | `facePhotoUrl` | `face_photo_url` |
| `passportPhotoUrl` | `passportPhotoUrl` | `passport_photo_url` |

Profile load uses **Firestore only**. After `updateUserInSql`, Firestore merge updates name/email/phone but **not** photo URL fields.

### Travel documents (untyped `Map`)

Client uses: `title`, `notes`, `doc_url`. No dedicated Dart model.

### Flight bookings (untyped `Map`)

**Write:** see `createFlightBooking` body.  
**Read UI:** `id`, `origin`, `destination`, `mid_places`, `departure_date`, `return_date`, `num_travelers`, `created_at`, `status`.

### Non-API models (out of PHP path)

- `TourPackage` — hardcoded mock assets only.
- `Promotion` — Firestore only.

---

## 4. Media paths (`DestinyMediaUrl` / `image_urls_json`)

Resolution order (`lib/utils/destiny_media_url.dart`):

1. null/empty → placehold.co placeholder  
2. `assets/...` → unchanged (asset load)  
3. absolute `http(s)://` → normalize/encode  
4. `destiny-media/...` or `supabase:...` → Supabase public Storage when configured  
5. else (incl. `uploads/...`) → `https://bymapara.com/<relative>`

Catalog models store **stringified** JSON arrays in `image_urls_json` (Award: `image_url_json`). Values observed in inventory docs are mostly legacy `uploads/<file>` paths. Home surfaces already use Destiny-owned refs; stay/vehicle/tour inventory media largely still legacy until cutover.

PII photos / travel docs are separate URL fields (`face_photo_url`, `passport_photo_url`, `doc_url`) — not through `image_urls_json`.

---

## 5. Auth assumptions (Firebase + sqlId)

```
Firebase Auth (email/Google)
    → AuthService.syncUserWithSql(firebase_uid, full_name, email)
    → PHP returns SQL users.id
    → stored as AppUser.sqlId in Firestore users/{uid}
    → NavigationScreen also re-syncs on authStateChanges → _sqlUserId
```

- Bookings / flights / documents APIs take **numeric SQL id**, not Firebase UID.
- Protected nav indices `[5,6,7,8]` (trips, bookings, documents, profile) require sign-in; Flights public browse allowed without sqlId (submit requires it).
- If SQL sync fails, `sqlId` may be null → booking/profile writes blocked or crash on `!`.
- **No** Firebase ID token sent to PHP → SQL id is the only “auth” claim (spoofable).

---

## 6. Security concerns (cross-cutting)

1. **No API authentication** — all actions callable with guessed/forged ids.  
2. **IDOR** on bookings, flights, documents, profiles by `user_id` / `id`.  
3. **Mutating GET** deletes (`delete_booking`, `delete_flight_booking`).  
4. **Client-trusted `total_price`** on create booking.  
5. **PII / passport uploads** over unauthenticated multipart.  
6. **Travel doc URLs** likely long-lived public links.  
7. **Dual user store** (Firebase + SQL + Firestore) can diverge (esp. photo URLs).  
8. Hardcoded production API host — no env switch for staging.

---

## 7. Summary table — entities → proposed Supabase destination

| Entity | Legacy source | Flutter model / fields | Proposed Supabase |
|--------|---------------|------------------------|-------------------|
| Tours | `get_tours` | `Tour` + `image_urls_json` | Table `tours`; media → `destiny-media/tours/{id}/…` |
| Accommodations | `get_accommodations` | `Accommodation` | Table `accommodations` (or `stays`); media → `destiny-media/stays/{id}/…` |
| Vehicles | `get_vehicles` | `Vehicle` | Table `vehicles`; media → `destiny-media/vehicles/{id}/…` |
| Awards | `get_awards` (unused UI) | `Award` / `image_url_json` | Optional `awards` or static CMS |
| Bookings (tour/stay/vehicle) | create/get/delete_booking | `Booking` | Table `bookings` + RLS |
| Flight enquiries | create/get/delete_flight_booking | untyped Map | Table `flight_enquiries` (+ status) |
| Travel documents | `get_travel_documents` | `title`/`notes`/`doc_url` | Table `travel_documents` + **private** Storage |
| Users / profiles | sync / update / get profile | `AppUser` + SQL id | Table `profiles` linked to `auth.users`; deprecate sqlId bridge |
| Face / passport photos | multipart update | URL fields | Private bucket (M5), not `destiny-media` |
| Promotions | Firestore | `Promotion` | Keep Firestore or move to `promotions` |
| TourPackage mock | local const | — | N/A (retire or seed real tours) |

---

## 8. Unknowns (server not in repo)

- Exact MySQL table/column definitions and constraints.  
- PHP auth middleware (if any) beyond what the client sends.  
- Payment / confirmation state machine for `bookings.status`.  
- Who uploads travel documents and how URLs are minted.  
- Whether `get_awards` / `get_user_profile` are used by non-Flutter clients.  
- Rate limits, CORS, HTTPS-only cookie assumptions on bymapara.com.

---

## 9. ApiService consumer map (quick)

| Method | Consumers |
|--------|-----------|
| `createBooking` | tour / accommodation / vehicle details |
| `createFlightBooking` | `flights_screen.dart` |
| `getUserBookings` / `deleteBooking` | `my_bookings_screen.dart` |
| `syncUserWithSql` | `auth_service.dart`, `navigation_screen.dart` |
| `updateUserInSql` | `auth_service.dart` ← `profile_screen.dart` |
| `getUserProfile` | **none** |
| `getMyFlightBookings` / `deleteFlightBooking` | `my_trips_screen.dart` |
| `getTravelDocuments` | `travel_documents_screen.dart` |
| `getTours` | `home_screen.dart`, `tour_list_screen.dart` |
| `getAccommodations` | `home_screen.dart`, `accommodation_list_screen.dart` |
| `getVehicles` | `home_screen.dart`, `vehicle_list_screen.dart` |
| `getAwards` | **none** |
