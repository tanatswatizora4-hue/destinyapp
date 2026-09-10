/**
 * M3B booking / enquiry lifecycle rules (pure, unit-testable).
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

export const STAFF_ROLES = ["consultant", "manager", "admin"] as const;
export type StaffRole = (typeof STAFF_ROLES)[number];

/** Staff-allowed booking transitions (customer cancel is narrower). */
export const STAFF_BOOKING_TRANSITIONS: Record<
  BookingStatus,
  ReadonlyArray<BookingStatus>
> = {
  draft: ["submitted", "cancelled"],
  submitted: ["quoted", "cancelled"],
  quoted: ["awaiting_payment", "cancelled"],
  awaiting_payment: ["confirmed", "cancelled"],
  confirmed: ["completed", "cancelled"],
  cancelled: [],
  completed: [],
};

export const STAFF_ENQUIRY_TRANSITIONS: Record<
  EnquiryStatus,
  ReadonlyArray<EnquiryStatus>
> = {
  received: ["in_review", "closed"],
  in_review: ["quoted", "closed"],
  quoted: ["converted", "closed"],
  converted: [],
  closed: [],
};

export const CUSTOMER_CANCELABLE: ReadonlySet<BookingStatus> = new Set([
  "draft",
  "submitted",
  "quoted",
  "awaiting_payment",
]);

export function isBookingStatus(v: string): v is BookingStatus {
  return (BOOKING_STATUSES as readonly string[]).includes(v);
}

export function isEnquiryStatus(v: string): v is EnquiryStatus {
  return (ENQUIRY_STATUSES as readonly string[]).includes(v);
}

export function canStaffTransitionBooking(
  from: string,
  to: string,
): boolean {
  if (!isBookingStatus(from) || !isBookingStatus(to)) return false;
  return STAFF_BOOKING_TRANSITIONS[from].includes(to);
}

export function canStaffTransitionEnquiry(
  from: string,
  to: string,
): boolean {
  if (!isEnquiryStatus(from) || !isEnquiryStatus(to)) return false;
  return STAFF_ENQUIRY_TRANSITIONS[from].includes(to);
}

export function canCustomerCancel(status: string): boolean {
  return CUSTOMER_CANCELABLE.has(status as BookingStatus);
}

export function sanitizeQuoteInput(body: Record<string, unknown>): {
  quoted_total: number;
  currency: string;
  quote_expires_at: string | null;
  customer_quote_note: string;
  internal_note: string;
} {
  const raw = body.quoted_total;
  const n = Number(raw);
  if (!Number.isFinite(n) || n < 0) {
    throw new Error("quoted_total must be a non-negative number");
  }
  // Quoting must not set payment_status=paid.
  if (
    Object.prototype.hasOwnProperty.call(body, "payment_status") ||
    Object.prototype.hasOwnProperty.call(body, "firebase_uid") ||
    Object.prototype.hasOwnProperty.call(body, "status")
  ) {
    throw new Error("Quote payload may not set payment_status/status/firebase_uid");
  }

  let expiry: string | null = null;
  if (body.quote_expires_at != null && String(body.quote_expires_at).trim()) {
    const d = new Date(String(body.quote_expires_at));
    if (Number.isNaN(d.getTime())) {
      throw new Error("quote_expires_at invalid");
    }
    expiry = d.toISOString();
  }

  return {
    quoted_total: Math.round(n * 100) / 100,
    currency: String(body.currency ?? "USD").slice(0, 8) || "USD",
    quote_expires_at: expiry,
    customer_quote_note: String(body.customer_quote_note ?? "").slice(0, 2000),
    internal_note: String(body.internal_note ?? body.internal_notes ?? "")
      .slice(0, 4000),
  };
}

export function assertStaffBodySafe(body: Record<string, unknown>): void {
  // Staff still cannot spoof actor identity — server derives from token.
  const forbidden = ["firebase_uid", "actor_firebase_uid", "service_role"];
  for (const key of forbidden) {
    if (Object.prototype.hasOwnProperty.call(body, key)) {
      throw new Error(`Client may not set '${key}'`);
    }
  }
}
