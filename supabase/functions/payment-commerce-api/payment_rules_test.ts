import {
  assertEquals,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  centsToDecimal,
  decimalToCents,
  ZERO_FEE_CONFIG,
} from "./payment_domain.ts";
import {
  assertNoRejectedClientFields,
  assertRefundAmount,
  bookingTransitionOnPaymentSuccess,
  canTransitionPayment,
  clientAttemptedMoneySpoof,
  computeFeeBreakdown,
  isMockProviderAllowed,
  parseWebhookEnvelope,
  stripUntrustedMoneyFields,
} from "./payment_rules.ts";
import { PaymentError } from "./payment_domain.ts";

Deno.test("decimal money uses integer cents (no float residue)", () => {
  assertEquals(decimalToCents("19.99"), 1999);
  assertEquals(decimalToCents("10.10"), 1010);
  assertEquals(decimalToCents("10.1"), 1010);
  assertEquals(decimalToCents(10.1), 1010);
  assertEquals(centsToDecimal(1999), "19.99");
  assertEquals(centsToDecimal(1), "0.01");
  assertThrows(() => decimalToCents("10.999"), PaymentError);
  assertThrows(() => decimalToCents("abc"), PaymentError);
});

Deno.test("authoritative amount comes from quote cents, not client spoof", () => {
  const quoted = decimalToCents("120.50");
  const body = {
    action: "create_payment_intent",
    booking_id: "b1",
    amount: 1,
    currency: "ZAR",
    platform_fee: 99,
    quoted_total: 1,
  };
  assertEquals(clientAttemptedMoneySpoof(body), true);
  const stripped = stripUntrustedMoneyFields(body);
  assertEquals(stripped.amount, undefined);
  assertEquals(stripped.currency, undefined);
  assertEquals(stripped.platform_fee, undefined);
  assertEquals(quoted, 12050);
});

Deno.test("rejected identity/status/card fields", () => {
  assertThrows(
    () => assertNoRejectedClientFields({ payment_status: "paid" }),
    PaymentError,
  );
  assertThrows(
    () => assertNoRejectedClientFields({ user_id: "x" }),
    PaymentError,
  );
  assertThrows(
    () => assertNoRejectedClientFields({ cvv: "123" }),
    PaymentError,
  );
  assertThrows(
    () => assertNoRejectedClientFields({ card_number: "4111111111111111" }),
    PaymentError,
  );
});

Deno.test("platform fee defaults to zero", () => {
  const b = computeFeeBreakdown(10000, ZERO_FEE_CONFIG);
  assertEquals(b.platformFeeCents, 0);
  assertEquals(b.providerFeeCents, 0);
  assertEquals(b.merchantNetCents, 10000);
});

Deno.test("fee calculations are deterministic", () => {
  const a = computeFeeBreakdown(10000, {
    platformFeePercent: 10,
    platformFeeFixedCents: 50,
    processorFeePercent: 2,
    processorFeeFixedCents: 0,
  });
  const b = computeFeeBreakdown(10000, {
    platformFeePercent: 10,
    platformFeeFixedCents: 50,
    processorFeePercent: 2,
    processorFeeFixedCents: 0,
  });
  assertEquals(a, b);
  assertEquals(a.platformFeeCents, 1050);
  assertEquals(a.providerFeeCents, 200);
  assertEquals(a.merchantNetCents, 8750);
});

Deno.test("failed and pending payments do not confirm bookings", () => {
  assertEquals(
    bookingTransitionOnPaymentSuccess({
      bookingStatus: "awaiting_payment",
      paymentStatus: "failed",
    }).confirm,
    false,
  );
  assertEquals(
    bookingTransitionOnPaymentSuccess({
      bookingStatus: "awaiting_payment",
      paymentStatus: "pending",
    }).confirm,
    false,
  );
  assertEquals(
    bookingTransitionOnPaymentSuccess({
      bookingStatus: "awaiting_payment",
      paymentStatus: "succeeded",
    }),
    { nextStatus: "confirmed", confirm: true },
  );
});

Deno.test("booking confirmation is not driven by Flutter status", () => {
  assertEquals(canTransitionPayment("pending", "succeeded"), true);
  assertEquals(
    bookingTransitionOnPaymentSuccess({
      bookingStatus: "draft",
      paymentStatus: "succeeded",
    }).confirm,
    false,
  );
});

Deno.test("refund cannot exceed captured amount", () => {
  assertThrows(
    () =>
      assertRefundAmount({
        capturedCents: 10000,
        alreadyRefundedCents: 3000,
        requestedCents: 8000,
      }),
    PaymentError,
  );
  assertRefundAmount({
    capturedCents: 10000,
    alreadyRefundedCents: 3000,
    requestedCents: 7000,
  });
});

Deno.test("malformed webhook rejected", () => {
  assertThrows(() => parseWebhookEnvelope(null), PaymentError);
  assertThrows(() => parseWebhookEnvelope("x"), PaymentError);
  assertThrows(() => parseWebhookEnvelope({}), PaymentError);
  assertThrows(
    () => parseWebhookEnvelope({ provider: "mock" }),
    PaymentError,
  );
  const ok = parseWebhookEnvelope({
    provider: "mock",
    event_type: "payment.succeeded",
    payment_intent_id: "i1",
    result: "succeeded",
    amount_cents: 1000,
  });
  assertEquals(ok.provider, "mock");
  assertEquals(ok.result, "succeeded");
});

Deno.test("mock provider disabled in production even if flag set", () => {
  assertEquals(
    isMockProviderAllowed({
      DESTINY_ENV: "production",
      PAYMENT_ALLOW_MOCK: "true",
    }),
    false,
  );
  assertEquals(
    isMockProviderAllowed({
      DESTINY_ENV: "prod",
      PAYMENT_ALLOW_MOCK: "true",
    }),
    false,
  );
  assertEquals(
    isMockProviderAllowed({
      DESTINY_ENV: "development",
      PAYMENT_ALLOW_MOCK: "true",
    }),
    true,
  );
  assertEquals(
    isMockProviderAllowed({
      DESTINY_ENV: "development",
      PAYMENT_ALLOW_MOCK: "false",
    }),
    false,
  );
});
