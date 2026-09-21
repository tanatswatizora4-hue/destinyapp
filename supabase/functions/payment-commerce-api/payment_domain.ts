/**
 * Destiny payment domain — provider-neutral primitives.
 * Amounts are integer cents. Never use IEEE floats as money authority.
 */

export const PAYMENT_STATUSES = [
  "created",
  "pending",
  "requires_action",
  "processing",
  "succeeded",
  "failed",
  "cancelled",
  "expired",
  "refunded",
  "partially_refunded",
] as const;

export type PaymentStatus = (typeof PAYMENT_STATUSES)[number];

export const SETTLEMENT_STATUSES = [
  "unsettled",
  "pending",
  "reconciled",
  "discrepancy",
] as const;

export type SettlementStatus = (typeof SETTLEMENT_STATUSES)[number];

export const REFUND_STATUSES = [
  "requested",
  "processing",
  "succeeded",
  "failed",
  "cancelled",
] as const;

export type RefundStatus = (typeof REFUND_STATUSES)[number];

export const LEDGER_ENTRY_TYPES = [
  "customer_payment",
  "processor_fee",
  "platform_fee",
  "merchant_payable",
  "supplier_payable",
  "refund",
  "adjustment",
] as const;

export type LedgerEntryType = (typeof LEDGER_ENTRY_TYPES)[number];

export const LEDGER_ACCOUNTS = [
  "customer",
  "processor",
  "platform",
  "merchant",
  "supplier",
] as const;

export type LedgerAccount = (typeof LEDGER_ACCOUNTS)[number];

export type LedgerDirection = "debit" | "credit";

export type MoneyBreakdown = {
  currency: string;
  grossCents: number;
  platformFeeCents: number;
  providerFeeCents: number;
  merchantNetCents: number;
  supplierPayableCents: number;
};

export type LedgerDraft = {
  entryType: LedgerEntryType;
  account: LedgerAccount;
  direction: LedgerDirection;
  amountCents: number;
  currency: string;
  idempotencyKey: string;
  description: string;
  refundId?: string | null;
};

export type MerchantFeeConfig = {
  platformFeePercent: number;
  platformFeeFixedCents: number;
  processorFeePercent: number;
  processorFeeFixedCents: number;
};

export const ZERO_FEE_CONFIG: MerchantFeeConfig = {
  platformFeePercent: 0,
  platformFeeFixedCents: 0,
  processorFeePercent: 0,
  processorFeeFixedCents: 0,
};

export const DESTINY_TRAVEL_MERCHANT_SLUG = "destiny-travel";

export class PaymentError extends Error {
  readonly code: string;
  readonly httpStatus: number;

  constructor(code: string, message: string, httpStatus = 400) {
    super(message);
    this.name = "PaymentError";
    this.code = code;
    this.httpStatus = httpStatus;
  }
}

export type CreatePaymentInput = {
  intentId: string;
  bookingId: string;
  currency: string;
  amountCents: number;
  returnUrl?: string | null;
  metadata?: Record<string, unknown>;
};

export type CreatePaymentResult = {
  provider: string;
  providerReference: string;
  checkoutUrl: string | null;
  status: PaymentStatus;
  isMock: boolean;
};

export type ProviderPaymentStatus = {
  provider: string;
  providerReference: string;
  status: PaymentStatus;
  amountCents: number | null;
  currency: string | null;
  providerEventId: string;
  rawSafe: Record<string, unknown>;
};

export type RefundPaymentInput = {
  intentId: string;
  refundId: string;
  providerReference: string;
  amountCents: number;
  currency: string;
  reason: string;
};

export type RefundPaymentResult = {
  provider: string;
  providerReference: string;
  status: RefundStatus;
  providerEventId: string;
};

export interface PaymentProvider {
  readonly name: string;
  readonly isMock: boolean;
  createPayment(input: CreatePaymentInput): Promise<CreatePaymentResult>;
  verifyPayment(providerReference: string): Promise<ProviderPaymentStatus>;
  getPaymentStatus(providerReference: string): Promise<ProviderPaymentStatus>;
  refundPayment(input: RefundPaymentInput): Promise<RefundPaymentResult>;
}

export function centsToDecimal(cents: number): string {
  if (!Number.isInteger(cents)) {
    throw new PaymentError("invalid_money", "Cents must be an integer");
  }
  const sign = cents < 0 ? "-" : "";
  const abs = Math.abs(cents);
  const whole = Math.floor(abs / 100);
  const frac = (abs % 100).toString().padStart(2, "0");
  return `${sign}${whole}.${frac}`;
}

export function decimalToCents(raw: unknown): number {
  if (raw == null || raw === "") {
    throw new PaymentError("invalid_money", "Amount is required");
  }
  if (typeof raw === "number") {
    if (!Number.isFinite(raw)) {
      throw new PaymentError("invalid_money", "Amount is not finite");
    }
    // Quotes arrive as numeric(12,2). Round only after scaling via string
    // to avoid binary float residue (e.g. 19.99).
    return decimalToCents(raw.toFixed(2));
  }
  const s = String(raw).trim();
  const m = s.match(/^(-)?(\d+)(?:\.(\d{1,2}))?$/);
  if (!m) {
    throw new PaymentError(
      "invalid_money",
      "Amount must be a decimal with at most 2 fractional digits",
    );
  }
  const sign = m[1] ? -1 : 1;
  const whole = parseInt(m[2], 10);
  const frac = (m[3] ?? "00").padEnd(2, "0");
  return sign * (whole * 100 + parseInt(frac, 10));
}

export function publicMoney(cents: number): number {
  return Number(centsToDecimal(cents));
}
