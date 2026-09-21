/**
 * Pure apply-plans for payment success / failure / refund.
 * Duplicate provider events yield empty mutations (idempotent).
 */

import {
  LedgerDraft,
  MoneyBreakdown,
  PaymentError,
  PaymentStatus,
} from "./payment_domain.ts";
import {
  ledgerDraftsForCapture,
  ledgerDraftsForRefund,
} from "./payment_ledger.ts";
import {
  bookingPaymentStatusFromIntent,
  bookingTransitionOnPaymentSuccess,
  canTransitionPayment,
  refundIntentStatus,
} from "./payment_rules.ts";

export type IntentSnapshot = {
  id: string;
  bookingId: string;
  customerUserId: string;
  merchantId: string;
  currency: string;
  paymentStatus: PaymentStatus;
  grossCents: number;
  platformFeeCents: number;
  providerFeeCents: number;
  merchantNetCents: number;
  supplierPayableCents: number;
};

export type BookingSnapshot = {
  id: string;
  userId: string | null;
  status: string;
  paymentStatus: string;
  quotedTotalCents: number | null;
};

export type ApplySuccessPlan = {
  duplicate: boolean;
  intentStatus: PaymentStatus;
  bookingNextStatus: string | null;
  bookingPaymentStatus: string | null;
  ledger: LedgerDraft[];
  confirmBooking: boolean;
};

export function planPaymentSuccess(args: {
  intent: IntentSnapshot;
  booking: BookingSnapshot;
  existingEventIds: Set<string>;
  providerEventId: string;
  capturedAmountCents: number | null;
  existingLedgerKeys: Set<string>;
}): ApplySuccessPlan {
  if (args.existingEventIds.has(args.providerEventId)) {
    return {
      duplicate: true,
      intentStatus: args.intent.paymentStatus === "created" ||
          args.intent.paymentStatus === "pending" ||
          args.intent.paymentStatus === "requires_action" ||
          args.intent.paymentStatus === "processing"
        ? "succeeded"
        : args.intent.paymentStatus,
      bookingNextStatus: null,
      bookingPaymentStatus: null,
      ledger: [],
      confirmBooking: false,
    };
  }

  if (
    args.capturedAmountCents != null &&
    args.capturedAmountCents !== args.intent.grossCents
  ) {
    throw new PaymentError(
      "amount_mismatch",
      "Provider captured amount does not match authoritative intent",
      409,
    );
  }

  if (
    args.intent.paymentStatus !== "succeeded" &&
    args.intent.paymentStatus !== "refunded" &&
    args.intent.paymentStatus !== "partially_refunded" &&
    !canTransitionPayment(args.intent.paymentStatus, "succeeded")
  ) {
    throw new PaymentError(
      "illegal_payment_transition",
      `Cannot mark ${args.intent.paymentStatus} as succeeded`,
      409,
    );
  }

  const breakdown: MoneyBreakdown = {
    currency: args.intent.currency,
    grossCents: args.intent.grossCents,
    platformFeeCents: args.intent.platformFeeCents,
    providerFeeCents: args.intent.providerFeeCents,
    merchantNetCents: args.intent.merchantNetCents,
    supplierPayableCents: args.intent.supplierPayableCents,
  };
  const ledger = ledgerDraftsForCapture(
    args.intent.id,
    args.intent.bookingId,
    breakdown,
  ).filter((d) => !args.existingLedgerKeys.has(d.idempotencyKey));

  const alreadySucceeded = args.intent.paymentStatus === "succeeded" ||
    args.intent.paymentStatus === "refunded" ||
    args.intent.paymentStatus === "partially_refunded";

  const transition = bookingTransitionOnPaymentSuccess({
    bookingStatus: args.booking.status,
    paymentStatus: "succeeded",
  });

  return {
    duplicate: alreadySucceeded && ledger.length === 0,
    intentStatus: alreadySucceeded ? args.intent.paymentStatus : "succeeded",
    bookingNextStatus: transition.nextStatus,
    bookingPaymentStatus: alreadySucceeded
      ? null
      : bookingPaymentStatusFromIntent("succeeded"),
    ledger,
    confirmBooking: transition.confirm && !alreadySucceeded,
  };
}

export function planPaymentFailure(args: {
  intent: IntentSnapshot;
  existingEventIds: Set<string>;
  providerEventId: string;
}): {
  duplicate: boolean;
  intentStatus: PaymentStatus;
  bookingPaymentStatus: string | null;
  confirmBooking: false;
} {
  if (args.existingEventIds.has(args.providerEventId)) {
    return {
      duplicate: true,
      intentStatus: args.intent.paymentStatus,
      bookingPaymentStatus: null,
      confirmBooking: false,
    };
  }
  if (args.intent.paymentStatus === "succeeded") {
    throw new PaymentError(
      "illegal_payment_transition",
      "Cannot fail a succeeded payment",
      409,
    );
  }
  if (!canTransitionPayment(args.intent.paymentStatus, "failed")) {
    throw new PaymentError(
      "illegal_payment_transition",
      `Cannot mark ${args.intent.paymentStatus} as failed`,
      409,
    );
  }
  return {
    duplicate: false,
    intentStatus: "failed",
    bookingPaymentStatus: "failed",
    confirmBooking: false,
  };
}

export function planRefundSuccess(args: {
  intent: IntentSnapshot;
  refundId: string;
  refundAmountCents: number;
  capturedCents: number;
  alreadyRefundedCents: number;
  existingEventIds: Set<string>;
  providerEventId: string;
  existingLedgerKeys: Set<string>;
}): {
  duplicate: boolean;
  intentStatus: PaymentStatus;
  bookingPaymentStatus: string;
  ledger: LedgerDraft[];
} {
  if (args.existingEventIds.has(args.providerEventId)) {
    return {
      duplicate: true,
      intentStatus: args.intent.paymentStatus,
      bookingPaymentStatus: args.intent.paymentStatus === "refunded"
        ? "refunded"
        : args.intent.paymentStatus === "partially_refunded"
        ? "partially_refunded"
        : "paid",
      ledger: [],
    };
  }
  const nextRefunded = args.alreadyRefundedCents + args.refundAmountCents;
  const intentStatus = refundIntentStatus(args.capturedCents, nextRefunded);
  const ledger = ledgerDraftsForRefund({
    intentId: args.intent.id,
    refundId: args.refundId,
    amountCents: args.refundAmountCents,
    currency: args.intent.currency,
  }).filter((d) => !args.existingLedgerKeys.has(d.idempotencyKey));

  return {
    duplicate: false,
    intentStatus,
    bookingPaymentStatus: intentStatus === "refunded"
      ? "refunded"
      : "partially_refunded",
    ledger,
  };
}
