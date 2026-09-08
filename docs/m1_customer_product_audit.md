# M1 Customer Travel Product — Phase 1 Audit

Factual inventory of Destiny Flutter customer stays / vehicles / flights surfaces vs Tours + Home patterns.  
Scope: redesign planning only; Tours/Home are reference patterns, not redesign targets.

---

## Shared context

### Navigation (`lib/screens/navigation_screen.dart`)

| Index | Label | Widget | Auth |
|------:|-------|--------|------|
| 0 | Home | `HomeScreen` | Public |
| 1 | Tours | `TourListScreen` | Public |
| 2 | Stays | `AccommodationListScreen` | Public |
| 3 | Vehicles | `VehicleListScreen` | Public |
| 4 | Flights | `FlightsScreen(userId:)` | **Signed-in required** (`_sqlUserId`); else placeholder / snackbar |
| 5–9 | My Trips, Bookings, Docs, Profile, Contact | — | Mostly protected |

Primary dock highlights indices 0–4 only.

### Theme (`lib/config/theme/app_theme.dart`)

- Plus Jakarta Sans, Material 3, brand blues/red (`AppColors`: primary `#0D47A1`, accent `#D32F2F`, navy `#0A2540`, cool greys).
- Content widths: `contentMaxWidth` 1240, `contentWideMaxWidth` 1440.
- Shared input/button/card radii (~14–18). Stays/vehicles/flights underuse these layout shells vs Tours/Home.

### Destina (Home — `_buildAskDestinaCompact`)

- Navy gradient panel, `_DestinaMark`, italic example prompt, accent CTA “Start planning”.
- CTA is **preview-only** (`_showPreviewMessage`: Destina coming soon).
- Pattern worth reusing for Flights / enquiry positioning: branded dark band + single CTA, not a dense form-as-page.

### API (`lib/services/api_service.dart`) — product-relevant

| Method | Endpoint action | Role |
|--------|-----------------|------|
| `getAccommodations()` | `get_accommodations` | List inventory |
| `getVehicles()` | `get_vehicles` | List inventory |
| `createBooking(...)` | `create_booking` | Agent-request booking for tour / accommodation / vehicle |
| `createFlightBooking(...)` | `create_flight_booking` | Persist trip **enquiry** (not ticket purchase) |
| `getMyFlightBookings` / `deleteFlightBooking` | read/delete user flight requests | Used outside Flights screen |

**No** `searchFlights` / flight inventory / fare quote API exists in the client.

---

## 1. Accommodation list — `lib/screens/accommodation_list_screen.dart`

### Current layout
- Body-only `Column` (no local `Scaffold`/`AppBar`; relies on `NavigationScreen`).
- Top: search `TextField` → horizontal `FilterChip` type row → `ListView.builder` of `AccommodationCard`.

### Data source / API
- `ApiService.getAccommodations()` → `get_accommodations`.
- Loaded once in `initState` into `_allAccommodations`; client-side filter only.

### Filtering / search
- Search: name + city (case-insensitive substring).
- Type chips: derived from unique `accommodation.type` values + “All”.
- **Not used:** `isFeatured`, city/country as dedicated filters, price/room price, amenities, pull-to-refresh, clear-filters UX.

### Image behavior
- Card uses `TravelNetworkImage` + `accommodation.mainImageUrl` (`DestinyMediaUrl.resolve` first gallery URL).
- **No `Hero` on card** despite details using `Hero(tag: accommodation_image_$id)` → broken/no shared-element transition.
- Card default `width: 280` inside full-width list → cards stay narrow, not edge-to-edge.

### Loading / empty / error
- Loading: centered `CircularProgressIndicator` if waiting and empty.
- Error: raw `Text('Error: ${snapshot.error}')`.
- Empty filter: `No matching accommodations found.`
- No retry, no empty-catalog vs empty-filter distinction, no result count.

### Details / CTA flow
- Tap → `Navigator.push` → `AccommodationDetailsScreen(accommodation:)`.

### Responsiveness
- None: no `LayoutBuilder`, no max-width shell, no multi-column grid, no tablet/desktop breakpoints (Tours: 1/2/3 cols at 700/1024).

### Legacy visual issues
- Default Material search + chips; no discovery intro / controls band.
- Fixed-width cards in a vertical list look unfinished on wide screens.
- Nested under nav chrome only; no section headline.

### Duplication vs Tours / Home
- Same FutureBuilder + local filter pattern as pre-redesign lists; Tours already has intro, filter band, grid, message states, refresh.

### Premium UI data support
**Yes, list-level fields available:**

| Field | Notes |
|-------|--------|
| `id`, `name`, `type` | Shown (type as eyebrow on card) |
| `description` | List unused |
| `address`, `city`, `country` | Card shows city/country; address unused |
| `isFeatured` | Unused in list UI |
| `imageUrls` / `mainImageUrl` / `resolvedImageUrls` | First image only on card |
| `amenities[]` (`name`, `included`) | Unused on card |
| `roomTypes[]` (`name`, `price`, `capacity`) | Unused on card (no “from $X”) |

Enough for photography-first cards + type/location + from-price + Destiny Pick badge.

---

## 2. Accommodation details — `lib/screens/accommodation_details_screen.dart`

### Current layout
- Own `Scaffold` + `AppBar(title: name)`.
- Auto-play `CarouselSlider` (250px) → location line → About → Room Types (`Card`/`ListTile`) → Amenities (`Chip` wrap).
- Bottom bar: full-width `ElevatedButton.icon` “Book Now”.

### Data source / API
- Receives full `Accommodation` from list (no refetch).
- Booking: `createBooking(itemType: 'accommodation', …)` after resolving Firebase → `AuthService.getAppUser` → `sqlId`.

### Filtering / search
- N/A (detail).

### Image behavior
- `resolvedImageUrls` via `CachedNetworkImage` (not `TravelNetworkImage`).
- `Hero` wrapper; list side missing matching Hero.
- AutoPlay carousel; no thumbnails / index dots / desktop gallery strip (Tours has both).

### Loading / empty / error
- No detail fetch loading.
- Booking: spinner on confirm; orange snack if dates/room missing; red if not logged in / API fail; green agent-contact success.
- Empty `roomTypes` → `_selectedRoom` null → booking blocked by validation.
- Empty gallery → empty carousel items (edge case).

### Details / CTA flow
1. Book Now → blurred modal bottom sheet `_BookingSheetContent`.
2. Date range picker + room dropdown → total = `room.price * nights`.
3. `numTravelers` sent as **room capacity** (not guest count picker).
4. Success copy: agent will contact; complete profile.

### Responsiveness
- Single mobile scroll column; no desktop split / sticky booking rail.

### Legacy visual issues
- Material `Card`/`Chip`/`ListTile` density vs Tours sections (`_AboutSection`, `_InclusionsSection`, meta pills).
- Backdrop blur booking sheet; Tours sheet has no blur.
- AppBar elevation 1 vs Tours immersive `SliverAppBar` / desktop back link.
- Address never shown; only city/country.

### Duplication vs Tours
- Parallel booking sheet + `createBooking` + sqlId resolution (nearly copy-paste of vehicle details and older tour booking).
- Missing Tours patterns: desktop rail, mobile price+CTA bar, gallery thumbs, featured badge, content max-width.

### Premium UI data support
Same model as list; **roomTypes** and **amenities** are rich enough for room comparison UI and inclusion chips. Gaps for “hotel shopping”: no ratings, lat/lng, check-in rules, policies, star class beyond free-text `type`.

---

## 3. Vehicle list — `lib/screens/vehicle_list_screen.dart`

### Current layout
- Same shell as stays: search field + vertical `ListView` of `VehicleCard` (no type chips).

### Data source / API
- `ApiService.getVehicles()` → `get_vehicles`.
- One-shot `initState` load; client filter.

### Filtering / search
- Make + model substring only.
- **Unused filters:** `type`, `city`/`country`, `isFeatured`, `pricePerDay` bands, year.

### Image behavior
- `TravelNetworkImage` + `mainImageUrl`.
- Card defaults `width: 260` (or 340 landscape) — list does not pass width → narrow bordered tiles.
- No Hero on card; details use `Hero(tag: vehicle_image_$id)`.

### Loading / empty / error
- Waiting → spinner (always while waiting, even after data).
- Error → raw error text.
- Empty → `No matching vehicles found.`
- No retry / refresh / clear.

### Details / CTA flow
- Tap → `VehicleDetailsScreen(vehicle:)`.

### Responsiveness
- None (no grid / max-width / breakpoints). `VehicleCard.landscape` exists but unused here.

### Legacy visual issues
- Bordered filled card vs stay card’s borderless photo+text (inconsistent product language).
- No intro / filters / result count.

### Duplication vs Tours / Home
- Same list boilerplate as stays; Tours already solved discovery chrome.

### Premium UI data support
**Fields available:**

| Field | Notes |
|-------|--------|
| `id`, `make`, `model`, `year` | Name on card; year only on details |
| `type` | Badge on card |
| `pricePerDay` | Shown on card |
| `address`, `city`, `country` | Unused on list |
| `isFeatured` | Unused |
| `imageUrls` / resolved helpers | First image |
| `amenities[]` | Unused on list |

Supports premium tiles (photo, type, price/day, location, featured). No seats/transmission/fuel in model.

---

## 4. Vehicle details — `lib/screens/vehicle_details_screen.dart`

### Current layout
- Mirror of accommodation details: AppBar, 250px autoplay carousel, type chip + `/day` price, Details cards (year, pickup address), Features chips, Book Now bar.

### Data source / API
- Passed-in `Vehicle`.
- Booking: `createBooking(itemType: 'vehicle', numTravelers: 1, totalPrice: pricePerDay * days)`.

### Filtering / search
- N/A.

### Image behavior
- Same as stays: `CachedNetworkImage` carousel + Hero; list Hero missing; not `TravelNetworkImage`.

### Loading / empty / error
- Booking validation for dates + login; same agent snackbars as stays.
- Empty amenities → empty wrap.

### Details / CTA flow
- Book Now → date-range sheet → Confirm → `create_booking`.
- No driver/options extras; no pickup time.

### Responsiveness
- Mobile-only single column; no desktop rail.

### Legacy visual issues
- Card/`ListTile` stacking; country omitted on pickup subtitle (`address, city` only).
- Near-duplicate of accommodation details structure (~identical booking sheet scaffolding).

### Duplication vs Tours
- Same gaps: no `_DesktopBookingRail`, no `_MobileBookingBar` with price, no gallery chrome, duplicated `_BookingSheetContent` private classes across three detail screens.

### Premium UI data support
Adequate for editorial detail + price CTA. Missing: description text field (vehicles have **no** `description`), specs beyond year/type/amenities.

---

## 5. Flights — `lib/screens/flights_screen.dart`

### Current layout
- **Own nested `Scaffold`** (white background) inside `NavigationScreen` scaffold — double chrome risk.
- Long scroll form: headline + Journey Details (from/to) + date range + Mid-Places (dynamic fields) + travelers + Additional Services switches/checkboxes + Submit + optional post-submit profile prompt card.
- Hard-coded `fontFamily: 'Poppins'` in places vs app theme Plus Jakarta Sans.

### Data source / API
- **Only write path:** `ApiService.createFlightBooking(...)` → `POST destiny_api.php?action=create_flight_booking`.
- Payload: `user_id`, `origin`, `destination`, `mid_places` (joined string), `num_travelers`, `is_enquiry`, `needs_accommodation`, `needs_interchange_assistance`, `needs_taxi`, `departure_date`, `return_date`.
- Requires constructor `userId` (SQL id from nav when signed in).
- Related elsewhere: `getMyFlightBookings`, `deleteFlightBooking` — not used on this screen.
- **There is no flight search, inventory, GDS, seats, or fare API in the Flutter client.**

### Filtering / search
- Not a catalog. Free-text origin/destination/stopovers. No airport codes, no calendar inventory, no results list.

### Image behavior
- None (form-only).

### Loading / empty / error
- Submit sets `_isLoading`; button shows spinner.
- Success snack → 4s delay → `_showProfilePrompt`; form cleared.
- Failure snack with exception string.
- No client-side required-field validation before submit (empty origin/destination can still POST).
- Profile “Update Profile” button only clears prompt local state — comment admits navigation to Profile is unimplemented.

### Details / CTA flow
- Single CTA: “Submit My Request” → agent enquiry persistence.
- Copy frames custom itinerary design, not ticket checkout.

### Responsiveness
- Single padded column; no desktop split; nested Scaffold ignores shared content max-width.

### Legacy visual issues
- Heavy card shadows + Poppins; denser than Home/Tours.
- Marketing headline over a logistics form.
- Auth gate at nav (index 4) while stays/vehicles are public.

### Duplication vs Tours / Home
- Does not reuse Destina compact band (closest product metaphor for “plan with us”).
- Booking success/profile nudge overlaps stay/vehicle agent messaging but UX is unique.

### Is Flights real shopping or fake/mock?

**Neither live OTA shopping nor a client-side mock catalog.**

| Capability | Reality |
|------------|---------|
| Browse/search flights | **Does not exist** — no search method, no results UI |
| Fares / airlines / seats | **Not present** |
| `create_flight_booking` | **Real HTTP POST** storing a **trip/flight enquiry** for agents |
| “Search” in product sense | User types free-text places; nothing is searched against an inventory |

Precision: **agent-assisted enquiry form backed by a real create API**, not flight shopping and not a fake results list.

### Premium UI data support
No flight product model. Enquiry fields only (above). Premium UI would be Destina-like planning / enquiry — not fare cards — unless new APIs are added.

---

## Models & cards (skim)

### `Accommodation` / `Vehicle`
- JSON: stringified `image_urls_json`, `amenities_json`, (+ `room_types_json` for stays).
- Shared `Amenity` from `tour.dart`.
- Media: `DestinyMediaUrl.resolve` via `mainImageUrl` / `resolvedImageUrls`.

### Cards
- `AccommodationCard`: borderless photo stack; optional width/imageHeight; no price/Hero/featured.
- `VehicleCard`: bordered surface; portrait or `landscape` row; shows type + price; no location/Hero/featured.
- Home already consumes these cards in carousels; list screens pass defaults that fight full-width layout.

---

## Reusable Tours patterns worth extracting

From `tour_list_screen.dart` / `tour_details_screen.dart` (do not redesign Tours; extract for Stays/Vehicles):

1. **Discovery intro** — accent bar + product label + headline + one supporting line + search field (`_DiscoveryIntro`).
2. **Controls band** — filter chips + clear + result count on `surfaceAlt` (`_ControlsBand` / `_FilterChip`).
3. **Responsive grid shell** — `LayoutBuilder` breakpoints (700 / 1024), column counts, `ConstrainedBox` max width, dock bottom spacer.
4. **Message states** — loading / error+retry / empty+clear (`_ToursMessageState`) + `RefreshIndicator`.
5. **Photography card + Hero** — `TourCard` Hero → details gallery tag contract.
6. **Details gallery** — height, index, thumbs on desktop (`_TourGallery`).
7. **Mobile booking bar** — price “From” + compact Book (`_MobileBookingBar`).
8. **Desktop booking rail** — sticky-style side column with price, meta, agent disclaimer, CTA (`_DesktopBookingRail`).
9. **Section primitives** — about block, inclusions list, meta pills, featured badge.
10. **Content width constants** — `AppTheme.contentMaxWidth` / `contentWideMaxWidth`.

Home Destina (`_buildAskDestinaCompact` / `_DestinaMark`): navy gradient panel + mark + sample prompt + accent CTA — best fit for **Flights / plan-with-us**, not for stay/vehicle catalog grids.

---

## Cross-cutting gaps for M1

| Gap | Stays | Vehicles | Flights |
|-----|-------|----------|---------|
| Behind Tours visual system | Yes | Yes | Yes |
| Responsive grid / rail | Missing | Missing | Missing |
| Hero list↔detail | Broken | Broken | N/A |
| Featured / price filters | Data unused | Data unused | N/A |
| Shared booking sheet | Duplicated | Duplicated | Separate enquiry API |
| Nested Scaffold | No | No | Yes (issue) |
| Auth | Public browse; login to book | Same | Browse gated |

---

## Verdict (Phase 1)

- **Stays & Vehicles:** real inventory APIs + agent `create_booking`; UI is pre-Tours list/detail. Data is sufficient for a Tours-parity premium catalog (images, type, location, amenities; stays add room types/prices; vehicles add daily rate/year).
- **Flights:** real **enquiry** write (`create_flight_booking`); **not** shopping; **no search**. Redesign should treat it as planning/enquiry (Destina-adjacent), not a faux results marketplace, unless backend flight search is added later.

---

## Phase 2+ — Implemented in M1

### Shared primitives (`lib/widgets/destiny_discovery.dart`)
- `DestinyDiscoveryIntro`, `DestinyControlsBand`, `DestinyFilterChip`
- `DestinyMessageState`, `DestinyDestinaAssist`
- `DestinyMediaGallery`, `DestinyMobileCtaBar`, `DestinyDesktopBookingRail`
- `DestinyContentShell`, `showDestinyPreviewMessage`

### Stays
- Responsive discovery grid (1/2/3 cols), search + type + Destiny Picks filters
- Cards: Hero, featured badge, location, from-price / night
- Details: gallery, rooms, amenities, Destina assist, mobile CTA + desktop rail
- CTA labeled **Request stay** (agent `create_booking`, not live hotel confirmation)

### Vehicles
- Same discovery shell; type + Destiny Picks filters; price/day cards with Hero
- Details: gallery, year/pickup/features, Destina assist, request booking sheet

### Flights
- Nested Scaffold removed
- Honest enquiry form with validation, round-trip/one-way, stopovers, assist options
- Copy clarifies **no live fares / inventory search**
- Destina entry + `create_flight_booking` with `isEnquiry: true`

### Known limitations (carry to M2/M3)
- Stay/vehicle imagery still mostly legacy `uploads/` until media migration
- No real-time hotel/vehicle availability
- Flights remains enquiry-only until Travelport/GDS (M3)
- Destina CTAs are preview snackbars until Destina production (M4)
- Seat/transmission/fuel specs not in vehicle model — not invented

### Final integration repair
- **Home media:** Flutter web `TravelNetworkImage` now prefers HTML `<img>` (`WebHtmlElementStrategy.prefer`) so public Supabase Storage WebP renders without CORS byte-fetch failures; empty dart-defines no longer wipe production Supabase defaults.
- **Flights auth:** Index 4 removed from `protectedNavIndices`; logged-out users see the enquiry UI. Submit still requires sign-in. Account tabs 5–8 remain protected.
