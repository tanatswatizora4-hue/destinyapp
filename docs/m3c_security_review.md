# M3C security review

Date: 2026-09-17  
Branch: `cursor/m3b5-supabase-auth-migration-194a`

| Check | Result |
|-------|--------|
| Travelport Client Secret in Git | **No** |
| Travelport password in Git | **No** |
| Travelport access token in Flutter | **No** |
| Provider credentials in Flutter | **No** |
| Provider credentials in logs | **No** (auth failures mapped; tokens not logged) |
| Supabase `service_role` in Flutter | **No** |
| `customer-api` `verify_jwt=true` | **Yes** (root `supabase/config.toml`) |
| `staff-commerce-api` `verify_jwt=true` | **Yes** (root `supabase/config.toml`) |
| Root function config committed | **Yes** |
| Server derives authenticated user identity | **Yes** (`getUser`) |
| Staff role server-authorized | **Yes** (`staff_users.user_id`) |
| Client cannot dictate authoritative price | **Yes** (AirPrice server-side; forbidden fields rejected) |
| Fake provider availability | **No** (empty offers if none; no invented fares) |
| Fake booking confirmation | **No** (enquiry only; not ticketed) |
| Fake payment success | **No** |
| Firebase Auth runtime path | **No** |
| New bymapara flight dependency | **No** |
| `flight-commerce-api` public search | `verify_jwt=false` by design; enquiry requires JWT |

## Production credential rotation

The Travelport Client Secret was previously visible in a screenshot. Use current credentials only for controlled development. Before production, rotate Client Secret (and password if exposed) and update Supabase secrets.
