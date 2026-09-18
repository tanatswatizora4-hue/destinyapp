/**
 * Balanced, append-oriented ledger drafts. Idempotency keys prevent duplicates.
 */

import {
  LedgerDraft,
  MoneyBreakdown,
  PaymentError,
  centsToDecimal,
} from "./payment_domain.ts";

export function assertLedgerBalanced(entries: LedgerDraft[]): void {
  const byCurrency = new Map<string, { debit: number; credit: number }>();
  for (const e of entries) {
    if (!Number.isInteger(e.amountCents) || e.amountCents <= 0) {
      throw new PaymentError("invalid_ledger", "Ledger amount must be > 0 cents");
    }
    const row = byCurrency.get(e.currency) ?? { debit: 0, credit: 0 };
    if (e.direction === "debit") row.debit += e.amountCents;
    else row.credit += e.amountCents;
    byCurrency.set(e.currency, row);
  }
  for (const [ccy, row] of byCurrency) {
    if (row.debit !== row.credit) {
      throw new PaymentError(
        "unbalanced_ledger",
        `Ledger not balanced for ${ccy}: debit ${row.debit} credit ${row.credit}`,
      );
    }
  }
}

export function ledgerDraftsForCapture(
  intentId: string,
  bookingId: string,
  breakdown: MoneyBreakdown,
): LedgerDraft[] {
  const ccy = breakdown.currency;
  const drafts: LedgerDraft[] = [
    {
      entryType: "customer_payment",
      account: "customer",
      direction: "debit",
      amountCents: breakdown.grossCents,
      currency: ccy,
      idempotencyKey: `ledger:customer_payment:${intentId}`,
      description: "Customer payment captured",
    },
  ];
  if (breakdown.platformFeeCents > 0) {
    drafts.push({
      entryType: "platform_fee",
      account: "platform",
      direction: "credit",
      amountCents: breakdown.platformFeeCents,
      currency: ccy,
      idempotencyKey: `ledger:platform_fee:${intentId}`,
      description: "Platform technology fee",
    });
  }
  if (breakdown.providerFeeCents > 0) {
    drafts.push({
      entryType: "processor_fee",
      account: "processor",
      direction: "credit",
      amountCents: breakdown.providerFeeCents,
      currency: ccy,
      idempotencyKey: `ledger:processor_fee:${intentId}`,
      description: "Payment processor fee",
    });
  }
  if (breakdown.supplierPayableCents > 0) {
    drafts.push({
      entryType: "supplier_payable",
      account: "supplier",
      direction: "credit",
      amountCents: breakdown.supplierPayableCents,
      currency: ccy,
      idempotencyKey: `ledger:supplier_payable:${intentId}`,
      description: "Supplier payable",
    });
  }
  if (breakdown.merchantNetCents > 0) {
    drafts.push({
      entryType: "merchant_payable",
      account: "merchant",
      direction: "credit",
      amountCents: breakdown.merchantNetCents,
      currency: ccy,
      idempotencyKey: `ledger:merchant_payable:${intentId}`,
      description: "Merchant proceeds",
    });
  }
  assertLedgerBalanced(drafts);
  return drafts;
}

export function ledgerDraftsForRefund(args: {
  intentId: string;
  refundId: string;
  amountCents: number;
  currency: string;
}): LedgerDraft[] {
  const drafts: LedgerDraft[] = [
    {
      entryType: "refund",
      account: "merchant",
      direction: "debit",
      amountCents: args.amountCents,
      currency: args.currency,
      idempotencyKey: `ledger:refund_merchant:${args.refundId}`,
      description: "Refund funded by merchant",
      refundId: args.refundId,
    },
    {
      entryType: "refund",
      account: "customer",
      direction: "credit",
      amountCents: args.amountCents,
      currency: args.currency,
      idempotencyKey: `ledger:refund_customer:${args.refundId}`,
      description: "Customer refund",
      refundId: args.refundId,
    },
  ];
  assertLedgerBalanced(drafts);
  return drafts;
}

export function draftsToRows(
  drafts: LedgerDraft[],
  args: {
    paymentIntentId: string;
    bookingId: string;
    merchantId: string;
  },
) {
  return drafts.map((d) => ({
    payment_intent_id: args.paymentIntentId,
    booking_id: args.bookingId,
    merchant_id: args.merchantId,
    refund_id: d.refundId ?? null,
    entry_type: d.entryType,
    account: d.account,
    direction: d.direction,
    amount: centsToDecimal(d.amountCents),
    currency: d.currency,
    idempotency_key: d.idempotencyKey,
    description: d.description,
  }));
}

export function filterNewDrafts(
  drafts: LedgerDraft[],
  existingKeys: Iterable<string>,
): LedgerDraft[] {
  const have = new Set(existingKeys);
  return drafts.filter((d) => !have.has(d.idempotencyKey));
}
