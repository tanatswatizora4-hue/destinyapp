import {
  assertEquals,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  planPaymentFailure,
  planPaymentSuccess,
  planRefundSuccess,
} from "./payment_apply.ts";
import { PaymentError } from "./payment_domain.ts";
import type { BookingSnapshot, IntentSnapshot } from "./payment_apply.ts";

function intent(over: Partial<IntentSnapshot> = {}): IntentSnapshot {
  return {
    id: "intent-1",
    bookingId: "book-1",
    customerUserId: "user-1",
    merchantId: "merch-1",
    currency: "USD",
    paymentStatus: "requires_action",
    grossCents: 5500,
    platformFeeCents: 0,
    providerFeeCents: 0,
    merchantNetCents: 5500,
    supplierPayableCents: 0,
    ...over,
  };
}

function booking(over: Partial<BookingSnapshot> = {}): BookingSnapshot {
  return {
    id: "book-1",
    userId: "user-1",
    status: "awaiting_payment",
    paymentStatus: "awaiting_payment",
    quotedTotalCents: 5500,
    ...over,
  };
}

Deno.test("success confirms awaiting_payment booking and writes ledger", () => {
  const plan = planPaymentSuccess({
    intent: intent(),
    booking: booking(),
    existingEventIds: new Set(),
    providerEventId: "mock:payment_succeeded:intent-1",
    capturedAmountCents: 5500,
    existingLedgerKeys: new Set(),
  });
  assertEquals(plan.confirmBooking, true);
  assertEquals(plan.bookingNextStatus, "confirmed");
  assertEquals(plan.bookingPaymentStatus, "paid");
  assertEquals(plan.ledger.length > 0, true);
  assertEquals(plan.duplicate, false);
});

Deno.test("duplicate success does not double-confirm or duplicate ledger", () => {
  const eventId = "mock:payment_succeeded:intent-1";
  const first = planPaymentSuccess({
    intent: intent(),
    booking: booking(),
    existingEventIds: new Set(),
    providerEventId: eventId,
    capturedAmountCents: 5500,
    existingLedgerKeys: new Set(),
  });
  const second = planPaymentSuccess({
    intent: intent({ paymentStatus: "succeeded" }),
    booking: booking({ status: "confirmed", paymentStatus: "paid" }),
    existingEventIds: new Set([eventId]),
    providerEventId: eventId,
    capturedAmountCents: 5500,
    existingLedgerKeys: new Set(first.ledger.map((d) => d.idempotencyKey)),
  });
  assertEquals(second.duplicate, true);
  assertEquals(second.confirmBooking, false);
  assertEquals(second.ledger.length, 0);
  assertEquals(second.bookingNextStatus, null);
});

Deno.test("duplicate success on already-succeeded intent with existing ledger keys", () => {
  const keys = new Set([
    "ledger:customer_payment:intent-1",
    "ledger:merchant_payable:intent-1",
  ]);
  const plan = planPaymentSuccess({
    intent: intent({ paymentStatus: "succeeded" }),
    booking: booking({ status: "confirmed" }),
    existingEventIds: new Set(),
    providerEventId: "other-event",
    capturedAmountCents: 5500,
    existingLedgerKeys: keys,
  });
  assertEquals(plan.confirmBooking, false);
  assertEquals(plan.ledger.length, 0);
});

Deno.test("failed payment does not confirm booking", () => {
  const plan = planPaymentFailure({
    intent: intent(),
    existingEventIds: new Set(),
    providerEventId: "mock:failed:intent-1",
  });
  assertEquals(plan.confirmBooking, false);
  assertEquals(plan.intentStatus, "failed");
});

Deno.test("client-spoofed captured amount is rejected", () => {
  assertThrows(
    () =>
      planPaymentSuccess({
        intent: intent(),
        booking: booking(),
        existingEventIds: new Set(),
        providerEventId: "evt",
        capturedAmountCents: 1,
        existingLedgerKeys: new Set(),
      }),
    PaymentError,
  );
});

Deno.test("duplicate refund callback is idempotent", () => {
  const eventId = "mock:refund_succeeded:r1";
  const first = planRefundSuccess({
    intent: intent({ paymentStatus: "succeeded" }),
    refundId: "r1",
    refundAmountCents: 2000,
    capturedCents: 5500,
    alreadyRefundedCents: 0,
    existingEventIds: new Set(),
    providerEventId: eventId,
    existingLedgerKeys: new Set(),
  });
  assertEquals(first.duplicate, false);
  assertEquals(first.intentStatus, "partially_refunded");
  const second = planRefundSuccess({
    intent: intent({ paymentStatus: "partially_refunded" }),
    refundId: "r1",
    refundAmountCents: 2000,
    capturedCents: 5500,
    alreadyRefundedCents: 2000,
    existingEventIds: new Set([eventId]),
    providerEventId: eventId,
    existingLedgerKeys: new Set(first.ledger.map((d) => d.idempotencyKey)),
  });
  assertEquals(second.duplicate, true);
  assertEquals(second.ledger.length, 0);
});
