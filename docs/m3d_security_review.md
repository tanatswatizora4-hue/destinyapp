# M3D security review

Date: 2026-09-18  
Branch: `cursor/m3b5-supabase-auth-migration-194a`

| Check | Result |
|-------|--------|
| `service_role` in Flutter | **No** |
| Provider secret keys in Flutter | **No** |
| Webhook secrets in Flutter | **No** |
| Client amount/currency/fees trusted | **No** (stripped + server quote) |
| Customer ownership | **Yes** (`customer_user_id` vs `auth.getUser`) |
| Staff authorization | **Yes** (`staff_users.user_id`) |
| Webhook idempotency | **Yes** (unique `provider_event_id` + ledger keys) |
| Mock provider production guard | **Yes** (`DESTINY_ENV=production` disables mock) |
| Card / CVV / PIN storage | **No** (rejected on input; no schema columns) |
| Financial audit trail | **Yes** (ledger + `payment_events` + `booking_events`) |
| RLS MODEL A on payment tables | **Yes** (RLS on, no client policies) |
| `payment-commerce-api` `verify_jwt=false` | **Yes** (webhooks); user actions still `getUser` |

No PAN, CVV, PIN, `service_role`, or provider secrets were added to Git.
