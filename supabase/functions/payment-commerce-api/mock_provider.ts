/**
 * Deterministic mock/test provider. Never usable in production.
 * Does not move real money. Does not store cards.
 */

import {
  CreatePaymentInput,
  CreatePaymentResult,
  PaymentError,
  PaymentProvider,
  ProviderPaymentStatus,
  RefundPaymentInput,
  RefundPaymentResult,
} from "./payment_domain.ts";

const store = new Map<string, ProviderPaymentStatus>();

export function resetMockPaymentStore(): void {
  store.clear();
}

export class MockPaymentProvider implements PaymentProvider {
  readonly name = "mock";
  readonly isMock = true;

  async createPayment(input: CreatePaymentInput): Promise<CreatePaymentResult> {
    const providerReference = `mock_${input.intentId.replace(/-/g, "").slice(0, 24)}`;
    store.set(providerReference, {
      provider: "mock",
      providerReference,
      status: "requires_action",
      amountCents: input.amountCents,
      currency: input.currency,
      providerEventId: `mock:created:${input.intentId}`,
      rawSafe: { checkout: "destiny-mock" },
    });
    return {
      provider: "mock",
      providerReference,
      checkoutUrl: `destiny-mock://checkout?intent=${encodeURIComponent(input.intentId)}`,
      status: "requires_action",
      isMock: true,
    };
  }

  async verifyPayment(providerReference: string): Promise<ProviderPaymentStatus> {
    return this.getPaymentStatus(providerReference);
  }

  async getPaymentStatus(providerReference: string): Promise<ProviderPaymentStatus> {
    const row = store.get(providerReference);
    if (!row) {
      throw new PaymentError("not_found", "Mock payment reference not found", 404);
    }
    return row;
  }

  /** Test/QA only: simulate an external provider callback. */
  simulateResult(
    providerReference: string,
    status: "succeeded" | "failed" | "cancelled",
    intentId: string,
  ): ProviderPaymentStatus {
    const prev = store.get(providerReference) ?? {
      provider: "mock",
      providerReference,
      status: "requires_action" as const,
      amountCents: null,
      currency: null,
      providerEventId: `mock:created:${intentId}`,
      rawSafe: { checkout: "destiny-mock" },
    };
    const next: ProviderPaymentStatus = {
      ...prev,
      status,
      providerEventId: `mock:${status}:${intentId}`,
      rawSafe: { simulated: true, result: status },
    };
    store.set(providerReference, next);
    return next;
  }

  async refundPayment(input: RefundPaymentInput): Promise<RefundPaymentResult> {
    return {
      provider: "mock",
      providerReference: `mock_rf_${input.refundId.replace(/-/g, "").slice(0, 20)}`,
      status: "succeeded",
      providerEventId: `mock:refund_succeeded:${input.refundId}`,
    };
  }
}
