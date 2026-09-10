/**
 * Pure helpers for M3A customer-api (unit-testable without Deno deploy).
 */

export const BOOKING_STATUSES = [
  "draft",
  "submitted",
  "quoted",
  "awaiting_payment",
  "confirmed",
  "cancelled",
  "completed",
] as const;

export type BookingStatus = (typeof BOOKING_STATUSES)[number];

export const ENQUIRY_STATUSES = [
  "received",
  "in_review",
  "quoted",
  "converted",
  "closed",
] as const;

export type EnquiryStatus = (typeof ENQUIRY_STATUSES)[number];

export const CUSTOMER_CANCELABLE_STATUSES: ReadonlySet<BookingStatus> =
  new Set(["draft", "submitted", "quoted", "awaiting_payment"]);

export function isBookingStatus(value: string): value is BookingStatus {
  return (BOOKING_STATUSES as readonly string[]).includes(value);
}

export function canCustomerCancel(status: string): boolean {
  return CUSTOMER_CANCELABLE_STATUSES.has(status as BookingStatus);
}

export function normalizeItemType(raw: string): string {
  const t = raw.trim().toLowerCase();
  if (t === "stay") return "accommodation";
  return t;
}

/** Strip client attempts to set authoritative fields. */
export function sanitizeBookingCreateInput(body: Record<string, unknown>): {
  item_type: string;
  item_legacy_id: number | null;
  item_id: string | null;
  item_name: string;
  num_travelers: number;
  requested_total: number | null;
  currency: string;
  start_date: string | null;
  end_date: string | null;
  item_image_json: unknown[];
  customer_notes: string;
} {
  const itemType = normalizeItemType(String(body.item_type ?? ""));
  if (!["tour", "accommodation", "vehicle"].includes(itemType)) {
    throw new Error("item_type must be tour, accommodation, or vehicle");
  }

  const numTravelers = Math.max(
    1,
    Math.min(50, Number(body.num_travelers ?? 1) || 1),
  );

  // Client estimate only — never accept quoted_total / status / payment_status / firebase_uid.
  const estimateRaw = body.requested_estimate ?? body.requested_total;
  let requestedTotal: number | null = null;
  if (estimateRaw != null && estimateRaw !== "") {
    const n = Number(estimateRaw);
    if (!Number.isFinite(n) || n < 0) {
      throw new Error("requested_estimate must be a non-negative number");
    }
    requestedTotal = Math.round(n * 100) / 100;
  }

  const legacyIdRaw = body.item_legacy_id ?? body.item_id;
  let itemLegacyId: number | null = null;
  if (legacyIdRaw != null && legacyIdRaw !== "") {
    const n = Number(legacyIdRaw);
    if (!Number.isFinite(n)) throw new Error("item_legacy_id invalid");
    itemLegacyId = Math.trunc(n);
  }

  const itemUuid =
    typeof body.item_uuid === "string" && body.item_uuid.length > 0
      ? body.item_uuid
      : null;

  return {
    item_type: itemType,
    item_legacy_id: itemLegacyId,
    item_id: itemUuid,
    item_name: String(body.item_name ?? "").slice(0, 200),
    num_travelers: numTravelers,
    requested_total: requestedTotal,
    currency: String(body.currency ?? "USD").slice(0, 8) || "USD",
    start_date: body.start_date ? String(body.start_date).slice(0, 10) : null,
    end_date: body.end_date ? String(body.end_date).slice(0, 10) : null,
    item_image_json: Array.isArray(body.item_image_refs)
      ? body.item_image_refs.slice(0, 20)
      : [],
    customer_notes: String(body.customer_notes ?? "").slice(0, 2000),
  };
}

export function sanitizeFlightEnquiryPayload(
  body: Record<string, unknown>,
): Record<string, unknown> {
  return {
    origin: String(body.origin ?? "").slice(0, 120),
    destination: String(body.destination ?? "").slice(0, 120),
    mid_places: Array.isArray(body.mid_places)
      ? body.mid_places.map((p) => String(p).slice(0, 80)).slice(0, 10)
      : [],
    num_travelers: Math.max(
      1,
      Math.min(50, Number(body.num_travelers ?? 1) || 1),
    ),
    needs_accommodation: Boolean(body.needs_accommodation),
    needs_interchange_assistance: Boolean(body.needs_interchange_assistance),
    needs_taxi: Boolean(body.needs_taxi),
    departure_date: body.departure_date
      ? String(body.departure_date).slice(0, 10)
      : null,
    return_date: body.return_date ? String(body.return_date).slice(0, 10) : null,
    // Explicitly omit any price/status/user fields.
  };
}

export function assertNoAuthoritativeClientFields(
  body: Record<string, unknown>,
): void {
  const forbidden = [
    "firebase_uid",
    "legacy_user_id",
    "quoted_total",
    "payment_status",
    "status",
    "total_price",
    "service_role",
  ];
  for (const key of forbidden) {
    if (Object.prototype.hasOwnProperty.call(body, key)) {
      throw new Error(`Client may not set '${key}'`);
    }
  }
}
