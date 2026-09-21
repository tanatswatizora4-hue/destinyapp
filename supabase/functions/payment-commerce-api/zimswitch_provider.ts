/**
 * Zimswitch adapter placeholder.
 *
 * Official API documentation and sandbox credentials are not in this repository.
 * Do not invent endpoints, signatures, or payloads.
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

function notConfigured(): never {
  throw new PaymentError(
    "provider_not_configured",
    "Zimswitch integration requires official API documentation and credentials",
    501,
  );
}

export class ZimswitchPaymentProvider implements PaymentProvider {
  readonly name = "zimswitch";
  readonly isMock = false;

  async createPayment(_input: CreatePaymentInput): Promise<CreatePaymentResult> {
    notConfigured();
  }
  async verifyPayment(_ref: string): Promise<ProviderPaymentStatus> {
    notConfigured();
  }
  async getPaymentStatus(_ref: string): Promise<ProviderPaymentStatus> {
    notConfigured();
  }
  async refundPayment(_input: RefundPaymentInput): Promise<RefundPaymentResult> {
    notConfigured();
  }
}
