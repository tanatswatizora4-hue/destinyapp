/**
 * Pure payment rules: fees, state machine, client-field handling, webhooks.
 */

import {
  MerchantFeeConfig,
  MoneyBreakdown,
  PAYMENT_STATUSES,
  PaymentError,
  PaymentStatus,
  ZERO_FEE_CONFIG,
  decimalToCents,
} from "./payment_domain.ts";

export const REJECTED_CLIENT_FIELDS = [
  "user_id",
  "firebase_uid",
  "legacy_user_id",
  "actor_user_id",
  "role",
  "is_active",
  "service_role",
  "payment_status",
  "settlement_status",
  "status",
  "card_number",
  "pan",
  "cvv",
  "cvc",
  "pin",
  "account_number",
  "routing_number",
] as const;

/** Client money fields are untrusted: stripped and ignored, never applied. */
export const IGNORED_CLIENT_MONEY_FIELDS = [
  "amount",
  "currency",
  "platform_fee",
  "provider_fee",
  "merchant_net",
  "merchant_amount",
  "gross_amount",
  "quoted_total",
  "total_price",
  "booking_total",
  "supplier_payable",
] as const;

const CARD_LIKE = /card|cvv|cvc|pan|pin|account_number|routing/i;

export type EnvLike = Record<string, string | undefined>;

export function isProductionEnv(env: EnvLike): boolean {
  const v = (env.DESTINY_ENV ?? env.PAYMENT_ENV ?? "").trim().toLowerCase();
  return v === "prod" || v === "production";
}

/**
 * Mock provider is fail-closed: allowed only when explicitly enabled AND
 * the environment is not production.
 */
export function isMockProviderAllowed(env: EnvLike): boolean {
  if (isProductionEnv(env)) return false;
  return (env.PAYMENT_ALLOW_MOCK ?? "").trim().toLowerCase() === "true";
}

export function assertNoRejectedClientFields(
  body: Record<string, unknown>,
): void {
  for (const key of REJECTED_CLIENT_FIELDS) {
    if (Object.prototype.hasOwnProperty.call(body, key)) {
      throw new PaymentError(
        "forbidden_field",
        `Client may not set '${key}'`,
        400,
      );
    }
  }
  for (const key of Object.keys(body)) {
    if (CARD_LIKE.test(key)) {
      throw new PaymentError(
        "forbidden_field",
        "Client may not send card or banking credentials",
        400,
      );
    }
  }
}

export function stripUntrustedMoneyFields(
  body: Record<string, unknown>,
): Record<string, unknown> {
  const out: Record<string, unknown> = { ...body };
  for (const key of IGNORED_CLIENT_MONEY_FIELDS) {
    delete out[key];
  }
  return out;
}

export function clientAttemptedMoneySpoof(
  body: Record<string, unknown>,
): boolean {
  return IGNORED_CLIENT_MONEY_FIELDS.some((k) =>
    Object.prototype.hasOwnProperty.call(body, k)
  );
}

export function computeFeeBreakdown(
  grossCents: number,
  config: MerchantFeeConfig = ZERO_FEE_CONFIG,
): MoneyBreakdown {
  if (!Number.isInteger(grossCents) || grossCents < 0) {
    throw new PaymentError("invalid_money", "Gross amount must be >= 0 cents");
  }
  if (grossCents === 0) {
    throw new PaymentError("invalid_money", "Payable amount must be greater than zero");
  }
  const platformFeeCents = feeCents(
    grossCents,
    config.platformFeePercent,
    config.platformFeeFixedCents,
  );
  const providerFeeCents = feeCents(
    grossCents,
    config.processorFeePercent,
    config.processorFeeFixedCents,
  );
  const merchantNetCents = grossCents - platformFeeCents - providerFeeCents;
  if (merchantNetCents < 0) {
    throw new PaymentError(
      "invalid_fees",
      "Fees exceed gross amount",
      409,
    );
  }
  return {
    currency: "",
    grossCents,
    platformFeeCents,
    providerFeeCents,
    merchantNetCents,
    supplierPayableCents: 0,
  };
}

function feeCents(
  grossCents: number,
  percent: number,
  fixedCents: number,
): number {
  if (percent < 0 || fixedCents < 0) {
    throw new PaymentError("invalid_fees", "Fees cannot be negative");
  }
  if (percent > 100) {
    throw new PaymentError("invalid_fees", "Percent fee cannot exceed 100");
  }
  const pct = Math.round((grossCents * percent) / 100);
  return pct + Math.round(fixedCents);
}

export function parseFeeConfig(row: {
  platform_fee_percent?: unknown;
  platform_fee_fixed?: unknown;
  processor_fee_percent?: unknown;
  processor_fee_fixed?: unknown;
} | null | undefined): MerchantFeeConfig {
  if (!row) return { ...ZERO_FEE_CONFIG };
  return {
    platformFeePercent: Number(row.platform_fee_percent ?? 0) || 0,
    platformFeeFixedCents: row.platform_fee_fixed == null
      ? 0
      : decimalToCents(row.platform_fee_fixed),
    processorFeePercent: Number(row.processor_fee_percent ?? 0) || 0,
    processorFeeFixedCents: row.processor_fee_fixed == null
      ? 0
      : decimalToCents(row.processor_fee_fixed),
  };
}

export const PAYMENT_TRANSITIONS: Record<
  PaymentStatus,
  ReadonlyArray<PaymentStatus>
> = {
  created: [
    "pending",
    "requires_action",
    "processing",
    "succeeded",
    "failed",
    "cancelled",
    "expired",
  ],
  pending: [
    "requires_action",
    "processing",
    "succeeded",
    "failed",
    "cancelled",
    "expired",
  ],
  requires_action: [
    "pending",
    "processing",
    "succeeded",
    "failed",
    "cancelled",
    "expired",
  ],
  processing: ["succeeded", "failed", "cancelled"],
  succeeded: ["succeeded", "refunded", "partially_refunded"],
  failed: ["pending", "requires_action", "processing", "cancelled", "expired"],
  cancelled: [],
  expired: [],
  refunded: ["refunded"],
  partially_refunded: ["partially_refunded", "refunded"],
};

export function isPaymentStatus(value: string): value is PaymentStatus {
  return (PAYMENT_STATUSES as readonly string[]).includes(value);
}

export function canTransitionPayment(
  from: PaymentStatus,
  to: PaymentStatus,
): boolean {
  if (from === to && (from === "succeeded" || from === "refunded" ||
    from === "partially_refunded")) {
    return true;
  }
  return PAYMENT_TRANSITIONS[from].includes(to);
}

export function assertRefundAmount(args: {
  capturedCents: number;
  alreadyRefundedCents: number;
  requestedCents: number;
}): void {
  if (!Number.isInteger(args.requestedCents) || args.requestedCents <= 0) {
    throw new PaymentError("invalid_refund", "Refund amount must be > 0");
  }
  const remaining = args.capturedCents - args.alreadyRefundedCents;
  if (args.requestedCents > remaining) {
    throw new PaymentError(
      "refund_exceeds_captured",
      "Refund cannot exceed captured amount remaining",
      409,
    );
  }
}

export function refundIntentStatus(
  capturedCents: number,
  refundedCents: number,
): PaymentStatus {
  if (refundedCents <= 0) return "succeeded";
  if (refundedCents >= capturedCents) return "refunded";
  return "partially_refunded";
}

export function bookingPaymentStatusFromIntent(
  intentStatus: PaymentStatus,
): string | null {
  switch (intentStatus) {
    case "succeeded":
      return "paid";
    case "refunded":
      return "refunded";
    case "partially_refunded":
      return "partially_refunded";
    case "failed":
      return "failed";
    case "pending":
    case "requires_action":
    case "processing":
    case "created":
      return "awaiting_payment";
    default:
      return null;
  }
}

/** Confirm booking only from trusted payment success while awaiting payment. */
export function bookingTransitionOnPaymentSuccess(args: {
  bookingStatus: string;
  paymentStatus: PaymentStatus;
}): { nextStatus: string | null; confirm: boolean } {
  if (args.paymentStatus !== "succeeded") {
    return { nextStatus: null, confirm: false };
  }
  if (args.bookingStatus === "awaiting_payment") {
    return { nextStatus: "confirmed", confirm: true };
  }
  if (args.bookingStatus === "confirmed" || args.bookingStatus === "completed") {
    return { nextStatus: null, confirm: false };
  }
  return { nextStatus: null, confirm: false };
}

export type WebhookEnvelope = {
  provider: string;
  eventType: string;
  providerEventId: string | null;
  providerReference: string | null;
  intentId: string | null;
  result: PaymentStatus | null;
  amountCents: number | null;
  currency: string | null;
};

export function parseWebhookEnvelope(
  body: unknown,
): WebhookEnvelope {
  if (!body || typeof body !== "object" || Array.isArray(body)) {
    throw new PaymentError("malformed_webhook", "Webhook body must be a JSON object", 400);
  }
  const src = body as Record<string, unknown>;
  const provider = String(src.provider ?? "").trim().toLowerCase();
  if (!provider) {
    throw new PaymentError("malformed_webhook", "provider is required", 400);
  }
  const eventType = String(src.event_type ?? src.type ?? "").trim();
  if (!eventType) {
    throw new PaymentError("malformed_webhook", "event_type is required", 400);
  }
  const providerEventId = src.provider_event_id == null
    ? (src.id == null ? null : String(src.id))
    : String(src.provider_event_id);
  const providerReference = src.provider_reference == null
    ? (src.reference == null ? null : String(src.reference))
    : String(src.provider_reference);
  const intentId = src.payment_intent_id == null
    ? (src.intent_id == null ? null : String(src.intent_id))
    : String(src.payment_intent_id);
  let result: PaymentStatus | null = null;
  const rawResult = src.result ?? src.status ?? src.payment_status;
  if (rawResult != null) {
    const s = String(rawResult);
    if (!isPaymentStatus(s)) {
      throw new PaymentError("malformed_webhook", `Unknown payment status '${s}'`, 400);
    }
    result = s;
  }
  let amountCents: number | null = null;
  if (src.amount_cents != null) {
    const n = Number(src.amount_cents);
    if (!Number.isInteger(n) || n < 0) {
      throw new PaymentError("malformed_webhook", "amount_cents must be a non-negative integer", 400);
    }
    amountCents = n;
  }
  const currency = src.currency == null ? null : String(src.currency);
  return {
    provider,
    eventType,
    providerEventId,
    providerReference,
    intentId,
    result,
    amountCents,
    currency,
  };
}

export function timingSafeEqual(a: string, b: string): boolean {
  const enc = new TextEncoder();
  const aa = enc.encode(a);
  const bb = enc.encode(b);
  const len = Math.max(aa.length, bb.length);
  let diff = aa.length ^ bb.length;
  for (let i = 0; i < len; i++) {
    diff |= (aa[i] ?? 0) ^ (bb[i] ?? 0);
  }
  return diff === 0;
}

export function redactForLog(value: unknown): unknown {
  if (value == null) return value;
  if (typeof value === "string") {
    if (value.length > 12 && /secret|key|token|password/i.test(value)) {
      return "[redacted]";
    }
    return value;
  }
  if (Array.isArray(value)) return value.map(redactForLog);
  if (typeof value === "object") {
    const out: Record<string, unknown> = {};
    for (const [k, v] of Object.entries(value as Record<string, unknown>)) {
      if (CARD_LIKE.test(k) || /secret|password|service_role|authorization/i.test(k)) {
        out[k] = "[redacted]";
      } else {
        out[k] = redactForLog(v);
      }
    }
    return out;
  }
  return value;
}

export function intentIdempotencyKey(
  bookingId: string,
  grossCents: number,
  currency: string,
): string {
  return `payintent:${bookingId}:${grossCents}:${currency.toUpperCase()}`;
}

export function successEventId(provider: string, intentId: string): string {
  return `${provider}:payment_succeeded:${intentId}`;
}

export function refundEventId(provider: string, refundId: string): string {
  return `${provider}:refund_succeeded:${refundId}`;
}
