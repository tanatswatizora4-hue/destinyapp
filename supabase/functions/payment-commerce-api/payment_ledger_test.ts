import {
  assertEquals,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  assertLedgerBalanced,
  filterNewDrafts,
  ledgerDraftsForCapture,
  ledgerDraftsForRefund,
} from "./payment_ledger.ts";
import { PaymentError } from "./payment_domain.ts";

Deno.test("capture ledger is balanced with zero platform fee", () => {
  const drafts = ledgerDraftsForCapture("i1", "b1", {
    currency: "USD",
    grossCents: 5500,
    platformFeeCents: 0,
    providerFeeCents: 0,
    merchantNetCents: 5500,
    supplierPayableCents: 0,
  });
  assertEquals(drafts.length, 2);
  assertLedgerBalanced(drafts);
});

Deno.test("capture ledger splits fees without double counting", () => {
  const drafts = ledgerDraftsForCapture("i1", "b1", {
    currency: "USD",
    grossCents: 10000,
    platformFeeCents: 500,
    providerFeeCents: 200,
    merchantNetCents: 9300,
    supplierPayableCents: 0,
  });
  assertLedgerBalanced(drafts);
  assertEquals(drafts.map((d) => d.idempotencyKey).every((k) => k.includes("i1")), true);
});

Deno.test("duplicate ledger keys are filtered", () => {
  const drafts = ledgerDraftsForCapture("i1", "b1", {
    currency: "USD",
    grossCents: 1000,
    platformFeeCents: 0,
    providerFeeCents: 0,
    merchantNetCents: 1000,
    supplierPayableCents: 0,
  });
  const again = filterNewDrafts(drafts, drafts.map((d) => d.idempotencyKey));
  assertEquals(again.length, 0);
});

Deno.test("refund ledger is balanced", () => {
  const drafts = ledgerDraftsForRefund({
    intentId: "i1",
    refundId: "r1",
    amountCents: 400,
    currency: "USD",
  });
  assertLedgerBalanced(drafts);
  assertThrows(
    () =>
      assertLedgerBalanced([
        {
          entryType: "refund",
          account: "customer",
          direction: "credit",
          amountCents: 100,
          currency: "USD",
          idempotencyKey: "x",
          description: "unbalanced",
        },
      ]),
    PaymentError,
  );
});
