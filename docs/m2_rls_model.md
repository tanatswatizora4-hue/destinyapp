# M2 RLS model

Project: `xchddfpfzrzhlbbmyhyn` (destiny-os only)

## Public inventory

RLS **enabled** on:

`tours`, `tour_images`, `tour_amenities`, `tour_itinerary_items`,  
`stays`, `stay_images`, `stay_rooms`, `stay_amenities`,  
`vehicles`, `vehicle_images`, `vehicle_features`,  
`awards`, `award_images`

Policies:

- **SELECT** for roles `anon` and `authenticated`
- Parent tables: `using (is_published = true)`
- Child tables: parent must be published (EXISTS subquery)
- **No** INSERT / UPDATE / DELETE policies for client roles

Flutter inventory is **read-only** against Supabase.

## Sensitive tables

`customer_profiles`, `enquiries`, `bookings`:

- RLS **enabled**
- **Zero** policies for `anon` / `authenticated`
- Default deny for Data API clients
- `service_role` (migrations / future Edge Functions) bypasses RLS

Explicitly **not** used: `USING (true)` on sensitive tables.

## Firebase Auth implication

Identity remains Firebase. Inventing Supabase `auth.uid()` ownership without a verified JWT bridge would be insecure.

M2 choice:

- keep sensitive tables server-only
- retain bymapara for customer writes until M3/M5 auth bridge
- document required bridge rather than fake client ownership

## Storage

Public bucket `destiny-media` (see `supabase/migrations/20260908170000_destiny_media_storage_policies.sql`):

- Prefixes: `home/`, `tours/`, `stays/`, `vehicles/`, `awards/`, `inventory/`, `branding/`, `placeholders/`
- Policy: **SELECT** for `anon` + `authenticated` on those prefixes only
- **No** client write policies — uploads use `service_role` migration scripts only
- Private customer documents must use a separate private bucket (M5) with authenticated policies
