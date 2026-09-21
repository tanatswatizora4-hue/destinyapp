# M5 — Internal operations & private customer documents

Project: Destiny OS `xchddfpfzrzhlbbmyhyn`

## Status

Implemented in-repo (not deployed from this mission):

| Phase | Scope | Checkpoint intent |
|-------|--------|-------------------|
| M5A | Private travel documents | Build private customer travel documents |
| M5B | Customer CRM workspace | Build internal customer CRM workspace |
| M5C | Consultant work queue | Build consultant enquiry work queue |
| M5D | Ops dashboard | Build internal operations dashboard |
| M5E | Roles / audit / hardening | Harden Destiny OS internal operations |

## Architecture

```
Customer Flutter
  → customer-api (Supabase Auth)
    → customer_travel_documents + private Storage bucket

Staff Flutter (/staff-ops)
  → staff-commerce-api (Supabase Auth → staff_users)
    → CRM / queue / dashboard / document access
```

**Model A** for sensitive tables: RLS enabled, **no** anon/authenticated policies.
Edge Functions use `service_role` after verifying the access token and
(for staff) `staff_users.is_active`.

## M5A — Private travel documents

- Bucket: `customer-travel-documents` (**private**, not `destiny-media`)
- Table: `customer_travel_documents`
- Events: `customer_travel_document_events`
- Types: passport, visa, national_id, residence_permit, vaccination_certificate, other
- MIME: jpeg/png/webp/pdf · max 10 MiB
- Paths: `{user_id}/{document_id}/{token}.ext` (server-built only)
- Access: short-lived signed URLs (120s) · **never** permanent public URLs
- Customer actions: list / create upload / finalize / signed URL / archive
- Staff actions: list / signed URL / verify (audited)

### Legacy

Previous Travel Docs used bymapara PHP (`ApiService.getTravelDocuments`) and a
legacy SQL user id. New UI uses Supabase Auth + customer-api only.
Legacy PHP helpers remain in `api_service.dart` but are no longer the Travel Docs
screen path. Migrating historical binary files from bymapara requires operator
credentials → **EXTERNAL_ACTION** after M5 deploy if production files exist.

## M5B — CRM

- `search_customers` (paginated)
- `get_customer_workspace` (profile, enquiries, bookings, documents, Destina briefs, notes)
- `staff_customer_notes` — staff-only; author is server-derived

## M5C — Work queue

Expanded enquiry statuses (additive):

`received | in_review | contacted | researching | quoted | awaiting_customer | converted | closed | cancelled`

- `work_queue` filters (status / me / unassigned)
- `assign_enquiry` (consultants → self; managers/admins → any active staff)
- `set_enquiry_follow_up` (`next_follow_up_at`, note, complete)
- Destina handoffs already create `enquiries` → same queue

## M5D — Dashboard

- `ops_dashboard` attention counts from canonical enquiries (role-scoped)
- No invented revenue/PSP metrics

## M5E — Security

| Role | Can | Cannot |
|------|-----|--------|
| Customer | Own profile, bookings, enquiries, private docs, Destina | CRM, notes, queue, dashboard, other customers |
| Consultant | CRM/queue/docs for assigned+unassigned policy, notes, verify | Assign to others, secrets |
| Manager/Admin | Company-wide ops | service_role / client secrets |

Audit: `ops_audit_events` + existing enquiry/booking/document events.

## Migrations to apply (operator)

1. `20260921160000_m5a_private_travel_documents.sql`
2. `20260921170000_m5bc_crm_queue_followups.sql`

## Functions to deploy (operator)

- `customer-api`
- `staff-commerce-api`

Do **not** deploy Destina solely for M5.

## Gemini quota

M4 Gemini account quota exhaustion is **out of scope** for M5.
