/**
 * Payment persistence workflows. Identity and amounts are server-derived.
 */

import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import {
  planPaymentFailure,
  planPaymentSuccess,
  planRefundSuccess,
  type BookingSnapshot,
  type IntentSnapshot,
} from "./payment_apply.ts";
import {
  DESTINY_TRAVEL_MERCHANT_SLUG,
  PaymentError,
  PaymentStatus,
  centsToDecimal,
  decimalToCents,
  publicMoney,
} from "./payment_domain.ts";
import { draftsToRows } from "./payment_ledger.ts";
import { MockPaymentProvider } from "./mock_provider.ts";
import { resolvePaymentProvider } from "./payment_provider.ts";
import {
  EnvLike,
  assertRefundAmount,
  bookingPaymentStatusFromIntent,
  computeFeeBreakdown,
  intentIdempotencyKey,
  isMockProviderAllowed,
  parseFeeConfig,
  redactForLog,
  refundEventId,
  successEventId,
} from "./payment_rules.ts";

export type StaffRow = {
  id: string;
  user_id: string;
  email: string;
  display_name: string;
  role: string;
  is_active: boolean;
};

type BookingRow = {
  id: string;
  user_id: string | null;
  status: string;
  payment_status: string;
  quoted_total: unknown;
  currency: string;
  item_name: string;
  item_type: string;
};

type IntentRow = Record<string, unknown>;

function envFromDeno(): EnvLike {
  return {
    DESTINY_ENV: Deno.env.get("DESTINY_ENV") ?? undefined,
    PAYMENT_ENV: Deno.env.get("PAYMENT_ENV") ?? undefined,
    PAYMENT_ALLOW_MOCK: Deno.env.get("PAYMENT_ALLOW_MOCK") ?? undefined,
    PAYMENT_PROVIDER: Deno.env.get("PAYMENT_PROVIDER") ?? undefined,
    PAYMENT_MOCK_WEBHOOK_SECRET: Deno.env.get("PAYMENT_MOCK_WEBHOOK_SECRET") ??
      undefined,
  };
}

function asIntent(row: IntentRow): IntentSnapshot {
  return {
    id: String(row.id),
    bookingId: String(row.booking_id),
    customerUserId: String(row.customer_user_id),
    merchantId: String(row.merchant_id),
    currency: String(row.currency),
    paymentStatus: String(row.payment_status) as PaymentStatus,
    grossCents: decimalToCents(row.gross_amount),
    platformFeeCents: decimalToCents(row.platform_fee),
    providerFeeCents: decimalToCents(row.provider_fee),
    merchantNetCents: decimalToCents(row.merchant_net),
    supplierPayableCents: decimalToCents(row.supplier_payable ?? 0),
  };
}

function asBooking(row: BookingRow): BookingSnapshot {
  return {
    id: row.id,
    userId: row.user_id,
    status: row.status,
    paymentStatus: row.payment_status,
    quotedTotalCents: row.quoted_total == null ? null : decimalToCents(row.quoted_total),
  };
}

export function publicIntent(row: IntentRow): Record<string, unknown> {
  return {
    id: row.id,
    booking_id: row.booking_id,
    merchant_id: row.merchant_id,
    customer_user_id: row.customer_user_id,
    currency: row.currency,
    gross_amount: publicMoney(decimalToCents(row.gross_amount)),
    platform_fee: publicMoney(decimalToCents(row.platform_fee)),
    provider_fee: publicMoney(decimalToCents(row.provider_fee)),
    merchant_net: publicMoney(decimalToCents(row.merchant_net)),
    supplier_payable: publicMoney(decimalToCents(row.supplier_payable ?? 0)),
    provider: row.provider,
    provider_reference: row.provider_reference,
    checkout_url: row.checkout_url,
    payment_status: row.payment_status,
    settlement_status: row.settlement_status,
    is_mock: row.provider === "mock",
    expires_at: row.expires_at,
    confirmed_at: row.confirmed_at,
    created_at: row.created_at,
    updated_at: row.updated_at,
    reconciliation_note: row.reconciliation_note ?? "",
    reconciled_at: row.reconciled_at,
  };
}

async function loadMerchant(db: SupabaseClient) {
  const { data: merchant, error } = await db
    .from("merchants")
    .select("id, slug, display_name, default_currency, is_active")
    .eq("slug", DESTINY_TRAVEL_MERCHANT_SLUG)
    .maybeSingle();
  if (error) throw error;
  if (!merchant || merchant.is_active !== true) {
    throw new PaymentError("merchant_unavailable", "Merchant is not active", 409);
  }
  const { data: cfg, error: cfgErr } = await db
    .from("payment_merchant_config")
    .select("*")
    .eq("merchant_id", merchant.id)
    .maybeSingle();
  if (cfgErr) throw cfgErr;
  return { merchant, feeConfig: parseFeeConfig(cfg), defaultProvider: String(cfg?.default_provider ?? "mock") };
}

async function loadBooking(db: SupabaseClient, bookingId: string): Promise<BookingRow> {
  const { data, error } = await db
    .from("bookings")
    .select("id, user_id, status, payment_status, quoted_total, currency, item_name, item_type")
    .eq("id", bookingId)
    .maybeSingle();
  if (error) throw error;
  if (!data) throw new PaymentError("not_found", "Booking not found", 404);
  return data as BookingRow;
}

async function loadIntent(db: SupabaseClient, id: string): Promise<IntentRow> {
  const { data, error } = await db
    .from("payment_intents")
    .select("*")
    .eq("id", id)
    .maybeSingle();
  if (error) throw error;
  if (!data) throw new PaymentError("not_found", "Payment intent not found", 404);
  return data as IntentRow;
}

async function existingEventIds(
  db: SupabaseClient,
  provider: string,
): Promise<Set<string>> {
  const { data, error } = await db
    .from("payment_events")
    .select("provider_event_id")
    .eq("provider", provider)
    .not("provider_event_id", "is", null)
    .limit(5000);
  if (error) throw error;
  return new Set(
    (data ?? []).map((r) => String((r as { provider_event_id: string }).provider_event_id)),
  );
}

async function existingLedgerKeys(
  db: SupabaseClient,
  intentId: string,
): Promise<Set<string>> {
  const { data, error } = await db
    .from("payment_ledger_entries")
    .select("idempotency_key")
    .eq("payment_intent_id", intentId);
  if (error) throw error;
  return new Set((data ?? []).map((r) => String((r as { idempotency_key: string }).idempotency_key)));
}

async function insertEvent(db: SupabaseClient, row: Record<string, unknown>) {
  const { error } = await db.from("payment_events").insert(row);
  if (error) {
    if (String(error.code) === "23505") return { duplicate: true };
    throw error;
  }
  return { duplicate: false };
}

async function insertLedger(db: SupabaseClient, rows: Record<string, unknown>[]) {
  if (rows.length === 0) return;
  const { error } = await db.from("payment_ledger_entries").insert(rows);
  if (error && String(error.code) !== "23505") throw error;
}

async function recordBookingEvent(
  db: SupabaseClient,
  args: {
    booking_id: string;
    event_type: string;
    previous_status?: string | null;
    new_status?: string | null;
    actor_type: "customer" | "staff" | "system";
    actor_user_id?: string | null;
    metadata?: Record<string, unknown>;
  },
) {
  const { error } = await db.from("booking_events").insert({
    booking_id: args.booking_id,
    event_type: args.event_type,
    previous_status: args.previous_status ?? null,
    new_status: args.new_status ?? null,
    actor_type: args.actor_type,
    actor_user_id: args.actor_user_id ?? null,
    metadata: redactForLog(args.metadata ?? {}),
  });
  if (error) throw error;
}

export async function requireStaff(
  db: SupabaseClient,
  userId: string,
): Promise<StaffRow> {
  const { data, error } = await db
    .from("staff_users")
    .select("id, user_id, email, display_name, role, is_active")
    .eq("user_id", userId)
    .maybeSingle();
  if (error) throw error;
  if (!data) {
    throw new PaymentError("forbidden", "Not authorized as Destiny staff", 403);
  }
  if (!data.is_active) {
    throw new PaymentError("forbidden", "Staff account inactive", 403);
  }
  return data as StaffRow;
}

export async function createPaymentIntent(
  db: SupabaseClient,
  args: { userId: string; bookingId: string },
): Promise<Record<string, unknown>> {
  const booking = await loadBooking(db, args.bookingId);
  if (booking.user_id !== args.userId) {
    throw new PaymentError("forbidden", "Cannot pay another customer's booking", 403);
  }
  if (booking.status !== "awaiting_payment") {
    throw new PaymentError(
      "not_payable",
      "Booking is not awaiting payment",
      409,
    );
  }
  if (booking.quoted_total == null) {
    throw new PaymentError("not_payable", "Booking has no authoritative quote", 409);
  }
  const grossCents = decimalToCents(booking.quoted_total);
  const currency = String(booking.currency || "USD").toUpperCase();
  const { merchant, feeConfig, defaultProvider } = await loadMerchant(db);
  const env = envFromDeno();
  const breakdown = computeFeeBreakdown(grossCents, feeConfig);
  breakdown.currency = currency;
  const providerName = (env.PAYMENT_PROVIDER || defaultProvider || "mock").toLowerCase();
  const provider = resolvePaymentProvider(providerName, env);

  const key = intentIdempotencyKey(booking.id, grossCents, currency);
  const { data: existing } = await db
    .from("payment_intents")
    .select("*")
    .eq("idempotency_key", key)
    .maybeSingle();
  if (existing) {
    return publicIntent(existing as IntentRow);
  }

  const { data: open } = await db
    .from("payment_intents")
    .select("id")
    .eq("booking_id", booking.id)
    .in("payment_status", ["created", "pending", "requires_action", "processing"]);
  if (open && open.length > 0) {
    await db
      .from("payment_intents")
      .update({ payment_status: "expired" })
      .in("id", open.map((r) => r.id));
  }

  const expires = new Date(Date.now() + 30 * 60 * 1000).toISOString();
  const insertRow = {
    merchant_id: merchant.id,
    booking_id: booking.id,
    customer_user_id: args.userId,
    currency,
    gross_amount: centsToDecimal(breakdown.grossCents),
    platform_fee: centsToDecimal(breakdown.platformFeeCents),
    provider_fee: centsToDecimal(breakdown.providerFeeCents),
    merchant_net: centsToDecimal(breakdown.merchantNetCents),
    supplier_payable: centsToDecimal(breakdown.supplierPayableCents),
    provider: provider.name,
    idempotency_key: key,
    payment_status: "created",
    settlement_status: "unsettled",
    expires_at: expires,
    metadata: { item_name: booking.item_name, item_type: booking.item_type },
  };
  const { data: created, error } = await db
    .from("payment_intents")
    .insert(insertRow)
    .select("*")
    .single();
  if (error) {
    if (String(error.code) === "23505") {
      const { data: raced } = await db
        .from("payment_intents")
        .select("*")
        .eq("idempotency_key", key)
        .maybeSingle();
      if (raced) return publicIntent(raced as IntentRow);
    }
    throw error;
  }

  const checkout = await provider.createPayment({
    intentId: String(created.id),
    bookingId: booking.id,
    currency,
    amountCents: breakdown.grossCents,
  });

  const { data: updated, error: upErr } = await db
    .from("payment_intents")
    .update({
      provider_reference: checkout.providerReference,
      checkout_url: checkout.checkoutUrl,
      payment_status: checkout.status,
    })
    .eq("id", created.id)
    .select("*")
    .single();
  if (upErr) throw upErr;

  await db.from("payment_attempts").insert({
    payment_intent_id: created.id,
    provider: provider.name,
    provider_reference: checkout.providerReference,
    status: checkout.status,
    result_safe: { checkout: true, is_mock: checkout.isMock },
  });

  await recordBookingEvent(db, {
    booking_id: booking.id,
    event_type: "payment_intent_created",
    previous_status: booking.status,
    new_status: booking.status,
    actor_type: "customer",
    actor_user_id: args.userId,
    metadata: {
      payment_intent_id: created.id,
      provider: provider.name,
      gross_amount: centsToDecimal(breakdown.grossCents),
      currency,
    },
  });

  return publicIntent((updated ?? created) as IntentRow);
}

export async function getOwnedIntent(
  db: SupabaseClient,
  args: { userId: string; intentId: string; staff?: boolean },
): Promise<Record<string, unknown>> {
  const row = await loadIntent(db, args.intentId);
  if (!args.staff && String(row.customer_user_id) !== args.userId) {
    throw new PaymentError("forbidden", "Cannot read another customer's payment", 403);
  }
  return publicIntent(row);
}

export async function listMyPayments(
  db: SupabaseClient,
  userId: string,
): Promise<Record<string, unknown>[]> {
  const { data, error } = await db
    .from("payment_intents")
    .select("*")
    .eq("customer_user_id", userId)
    .order("created_at", { ascending: false })
    .limit(100);
  if (error) throw error;
  return (data ?? []).map((r) => publicIntent(r as IntentRow));
}

async function applyProviderOutcome(
  db: SupabaseClient,
  args: {
    intent: IntentRow;
    booking: BookingRow;
    result: PaymentStatus;
    providerEventId: string;
    capturedAmountCents: number | null;
    actorUserId?: string | null;
    actorType: "customer" | "staff" | "system";
  },
): Promise<{ intent: Record<string, unknown>; duplicate: boolean }> {
  const snap = asIntent(args.intent);
  const bookingSnap = asBooking(args.booking);
  const events = await existingEventIds(db, String(args.intent.provider));
  const keys = await existingLedgerKeys(db, snap.id);

  if (args.result === "succeeded") {
    const plan = planPaymentSuccess({
      intent: snap,
      booking: bookingSnap,
      existingEventIds: events,
      providerEventId: args.providerEventId,
      capturedAmountCents: args.capturedAmountCents,
      existingLedgerKeys: keys,
    });
    const ev = await insertEvent(db, {
      payment_intent_id: snap.id,
      provider: args.intent.provider,
      event_type: "payment_succeeded",
      provider_event_id: args.providerEventId,
      payload_safe: { result: "succeeded" },
      verification_status: "verified",
    });
    if (ev.duplicate || plan.duplicate) {
      const latest = await loadIntent(db, snap.id);
      return { intent: publicIntent(latest), duplicate: true };
    }
    await insertLedger(
      db,
      draftsToRows(plan.ledger, {
        paymentIntentId: snap.id,
        bookingId: snap.bookingId,
        merchantId: snap.merchantId,
      }),
    );
    const intentPatch: Record<string, unknown> = {
      payment_status: plan.intentStatus,
    };
    if (plan.intentStatus === "succeeded") {
      intentPatch.confirmed_at = new Date().toISOString();
    }
    const { data: updated, error } = await db
      .from("payment_intents")
      .update(intentPatch)
      .eq("id", snap.id)
      .select("*")
      .single();
    if (error) throw error;

    const bookingPatch: Record<string, unknown> = {};
    if (plan.bookingPaymentStatus) {
      bookingPatch.payment_status = plan.bookingPaymentStatus;
    }
    if (plan.confirmBooking && plan.bookingNextStatus) {
      bookingPatch.status = plan.bookingNextStatus;
    }
    if (Object.keys(bookingPatch).length > 0) {
      const { error: bErr } = await db
        .from("bookings")
        .update(bookingPatch)
        .eq("id", snap.bookingId);
      if (bErr) throw bErr;
    }
    await recordBookingEvent(db, {
      booking_id: snap.bookingId,
      event_type: plan.confirmBooking
        ? "booking_confirmed_from_payment"
        : "payment_succeeded",
      previous_status: args.booking.status,
      new_status: plan.bookingNextStatus ?? args.booking.status,
      actor_type: args.actorType,
      actor_user_id: args.actorUserId ?? null,
      metadata: {
        payment_intent_id: snap.id,
        duplicate: false,
        provider: args.intent.provider,
      },
    });
    return { intent: publicIntent(updated as IntentRow), duplicate: false };
  }

  if (args.result === "failed" || args.result === "cancelled" || args.result === "expired") {
    const plan = planPaymentFailure({
      intent: snap,
      existingEventIds: events,
      providerEventId: args.providerEventId,
    });
    const ev = await insertEvent(db, {
      payment_intent_id: snap.id,
      provider: args.intent.provider,
      event_type: `payment_${args.result}`,
      provider_event_id: args.providerEventId,
      payload_safe: { result: args.result },
      verification_status: "verified",
    });
    if (ev.duplicate || plan.duplicate) {
      const latest = await loadIntent(db, snap.id);
      return { intent: publicIntent(latest), duplicate: true };
    }
    const { data: updated, error } = await db
      .from("payment_intents")
      .update({ payment_status: args.result === "failed" ? "failed" : args.result })
      .eq("id", snap.id)
      .select("*")
      .single();
    if (error) throw error;
    if (args.result === "failed") {
      await db.from("bookings").update({ payment_status: "failed" }).eq("id", snap.bookingId);
    }
    await recordBookingEvent(db, {
      booking_id: snap.bookingId,
      event_type: "payment_failed",
      previous_status: args.booking.status,
      new_status: args.booking.status,
      actor_type: args.actorType,
      actor_user_id: args.actorUserId ?? null,
      metadata: { payment_intent_id: snap.id, result: args.result },
    });
    return { intent: publicIntent(updated as IntentRow), duplicate: false };
  }

  throw new PaymentError("unsupported_result", `Unsupported payment result '${args.result}'`, 400);
}

export async function mockSimulateResult(
  db: SupabaseClient,
  args: {
    userId: string;
    intentId: string;
    result: "succeeded" | "failed" | "cancelled";
    staff?: boolean;
  },
): Promise<Record<string, unknown>> {
  const env = envFromDeno();
  if (!isMockProviderAllowed(env)) {
    throw new PaymentError("mock_disabled", "Mock payments are disabled", 409);
  }
  const intent = await loadIntent(db, args.intentId);
  if (String(intent.provider) !== "mock") {
    throw new PaymentError("mock_disabled", "Intent is not a mock payment", 409);
  }
  if (!args.staff && String(intent.customer_user_id) !== args.userId) {
    throw new PaymentError("forbidden", "Cannot pay another customer's booking", 403);
  }
  const booking = await loadBooking(db, String(intent.booking_id));
  const mock = new MockPaymentProvider();
  const created = await mock.createPayment({
    intentId: String(intent.id),
    bookingId: String(intent.booking_id),
    currency: String(intent.currency),
    amountCents: decimalToCents(intent.gross_amount),
  });
  mock.simulateResult(
    String(intent.provider_reference ?? created.providerReference),
    args.result,
    String(intent.id),
  );
  const eventId = args.result === "succeeded"
    ? successEventId("mock", String(intent.id))
    : `mock:${args.result}:${intent.id}`;
  const captured = args.result === "succeeded" ? decimalToCents(intent.gross_amount) : null;
  const applied = await applyProviderOutcome(db, {
    intent,
    booking,
    result: args.result,
    providerEventId: eventId,
    capturedAmountCents: captured,
    actorUserId: args.userId,
    actorType: args.staff ? "staff" : "customer",
  });
  return applied.intent;
}

export async function verifyPayment(
  db: SupabaseClient,
  args: { userId: string; intentId: string; staff?: boolean },
): Promise<Record<string, unknown>> {
  const intent = await loadIntent(db, args.intentId);
  if (!args.staff && String(intent.customer_user_id) !== args.userId) {
    throw new PaymentError("forbidden", "Cannot read another customer's payment", 403);
  }
  if (String(intent.payment_status) === "succeeded") {
    return publicIntent(intent);
  }
  const env = envFromDeno();
  const provider = resolvePaymentProvider(String(intent.provider), env);
  const ref = String(intent.provider_reference ?? "");
  if (!ref) {
    throw new PaymentError("not_found", "Payment has no provider reference", 409);
  }
  const status = await provider.getPaymentStatus(ref);
  if (status.status === "requires_action" || status.status === "pending" || status.status === "processing") {
    return publicIntent(intent);
  }
  const booking = await loadBooking(db, String(intent.booking_id));
  const applied = await applyProviderOutcome(db, {
    intent,
    booking,
    result: status.status,
    providerEventId: status.providerEventId,
    capturedAmountCents: status.amountCents,
    actorUserId: args.userId,
    actorType: "system",
  });
  return applied.intent;
}

export async function requestRefund(
  db: SupabaseClient,
  args: {
    userId: string;
    intentId: string;
    amountRaw?: unknown;
    reason: string;
    actorType: "customer" | "staff";
  },
): Promise<Record<string, unknown>> {
  const intent = await loadIntent(db, args.intentId);
  if (args.actorType === "customer" && String(intent.customer_user_id) !== args.userId) {
    throw new PaymentError("forbidden", "Cannot refund another customer's payment", 403);
  }
  const status = String(intent.payment_status);
  if (status !== "succeeded" && status !== "partially_refunded") {
    throw new PaymentError("not_refundable", "Payment is not captured", 409);
  }
  const captured = decimalToCents(intent.gross_amount);
  const { data: refunds, error } = await db
    .from("payment_refunds")
    .select("amount, status")
    .eq("payment_intent_id", intent.id)
    .in("status", ["requested", "processing", "succeeded"]);
  if (error) throw error;
  const already = (refunds ?? []).reduce((sum, r) => {
    const st = String((r as { status: string }).status);
    if (st === "succeeded" || st === "requested" || st === "processing") {
      return sum + decimalToCents((r as { amount: unknown }).amount);
    }
    return sum;
  }, 0);
  const requestedCents = args.amountRaw == null || args.amountRaw === ""
    ? captured - already
    : decimalToCents(args.amountRaw);
  assertRefundAmount({
    capturedCents: captured,
    alreadyRefundedCents: already,
    requestedCents,
  });
  const refundKey = `refund:${intent.id}:${requestedCents}:${args.userId}`;
  const { data: created, error: insErr } = await db
    .from("payment_refunds")
    .insert({
      payment_intent_id: intent.id,
      booking_id: intent.booking_id,
      merchant_id: intent.merchant_id,
      amount: centsToDecimal(requestedCents),
      currency: intent.currency,
      status: "requested",
      reason: args.reason.slice(0, 500),
      provider: intent.provider,
      idempotency_key: refundKey,
      requested_by_user_id: args.userId,
      requested_by_type: args.actorType,
    })
    .select("*")
    .single();
  if (insErr) {
    if (String(insErr.code) === "23505") {
      const { data: raced } = await db
        .from("payment_refunds")
        .select("*")
        .eq("idempotency_key", refundKey)
        .maybeSingle();
      if (raced) return raced as Record<string, unknown>;
    }
    throw insErr;
  }
  await recordBookingEvent(db, {
    booking_id: String(intent.booking_id),
    event_type: "refund_requested",
    actor_type: args.actorType,
    actor_user_id: args.userId,
    metadata: {
      payment_intent_id: intent.id,
      refund_id: created.id,
      amount: centsToDecimal(requestedCents),
    },
  });
  return created as Record<string, unknown>;
}

export async function processRefund(
  db: SupabaseClient,
  args: { userId: string; refundId: string },
): Promise<Record<string, unknown>> {
  const { data: refund, error } = await db
    .from("payment_refunds")
    .select("*")
    .eq("id", args.refundId)
    .maybeSingle();
  if (error) throw error;
  if (!refund) throw new PaymentError("not_found", "Refund not found", 404);
  if (String(refund.status) === "succeeded") return refund as Record<string, unknown>;

  const intent = await loadIntent(db, String(refund.payment_intent_id));
  const env = envFromDeno();
  const provider = resolvePaymentProvider(String(intent.provider), env);
  const result = await provider.refundPayment({
    intentId: String(intent.id),
    refundId: String(refund.id),
    providerReference: String(intent.provider_reference ?? ""),
    amountCents: decimalToCents(refund.amount),
    currency: String(refund.currency),
    reason: String(refund.reason ?? ""),
  });

  if (result.status !== "succeeded") {
    await db.from("payment_refunds").update({
      status: result.status,
      provider_reference: result.providerReference,
    }).eq("id", refund.id);
    return { ...refund, status: result.status };
  }

  const { data: succeededRefunds, error: sumErr } = await db
    .from("payment_refunds")
    .select("amount")
    .eq("payment_intent_id", intent.id)
    .eq("status", "succeeded");
  if (sumErr) throw sumErr;
  const already = (succeededRefunds ?? []).reduce(
    (s, r) => s + decimalToCents((r as { amount: unknown }).amount),
    0,
  );
  const keys = await existingLedgerKeys(db, String(intent.id));
  const events = await existingEventIds(db, String(intent.provider));
  const eventId = result.providerEventId || refundEventId(String(intent.provider), String(refund.id));
  const plan = planRefundSuccess({
    intent: asIntent(intent),
    refundId: String(refund.id),
    refundAmountCents: decimalToCents(refund.amount),
    capturedCents: decimalToCents(intent.gross_amount),
    alreadyRefundedCents: already,
    existingEventIds: events,
    providerEventId: eventId,
    existingLedgerKeys: keys,
  });
  const ev = await insertEvent(db, {
    payment_intent_id: intent.id,
    provider: intent.provider,
    event_type: "refund_succeeded",
    provider_event_id: eventId,
    payload_safe: { refund_id: refund.id },
    verification_status: "verified",
  });
  if (ev.duplicate || plan.duplicate) {
    return refund as Record<string, unknown>;
  }
  await insertLedger(
    db,
    draftsToRows(plan.ledger, {
      paymentIntentId: String(intent.id),
      bookingId: String(intent.booking_id),
      merchantId: String(intent.merchant_id),
    }),
  );
  await db.from("payment_refunds").update({
    status: "succeeded",
    provider_reference: result.providerReference,
  }).eq("id", refund.id);
  await db.from("payment_intents").update({
    payment_status: plan.intentStatus,
  }).eq("id", intent.id);
  await db.from("bookings").update({
    payment_status: plan.bookingPaymentStatus,
  }).eq("id", intent.booking_id);
  await recordBookingEvent(db, {
    booking_id: String(intent.booking_id),
    event_type: "refund_completed",
    actor_type: "staff",
    actor_user_id: args.userId,
    metadata: {
      payment_intent_id: intent.id,
      refund_id: refund.id,
      amount: refund.amount,
    },
  });
  const { data: latest } = await db.from("payment_refunds").select("*").eq("id", refund.id).single();
  return (latest ?? refund) as Record<string, unknown>;
}

export async function handleProviderWebhook(
  db: SupabaseClient,
  envelope: {
    provider: string;
    eventType: string;
    providerEventId: string | null;
    providerReference: string | null;
    intentId: string | null;
    result: PaymentStatus | null;
    amountCents: number | null;
  },
): Promise<Record<string, unknown>> {
  if (!envelope.providerEventId && !envelope.intentId && !envelope.providerReference) {
    throw new PaymentError("malformed_webhook", "Webhook must identify an intent or event", 400);
  }
  let query = db.from("payment_intents").select("*");
  if (envelope.intentId) query = query.eq("id", envelope.intentId);
  else if (envelope.providerReference) {
    query = query.eq("provider", envelope.provider).eq("provider_reference", envelope.providerReference);
  }
  const { data: intent, error } = await query.maybeSingle();
  if (error) throw error;
  if (!intent) {
    await insertEvent(db, {
      provider: envelope.provider,
      event_type: envelope.eventType,
      provider_event_id: envelope.providerEventId,
      payload_safe: { unmatched: true },
      verification_status: "ignored",
    });
    throw new PaymentError("not_found", "Payment intent not found for webhook", 404);
  }
  if (!envelope.result) {
    throw new PaymentError("malformed_webhook", "Webhook result/status is required", 400);
  }
  const booking = await loadBooking(db, String(intent.booking_id));
  const eventId = envelope.providerEventId ??
    `${envelope.provider}:${envelope.eventType}:${intent.id}`;
  const applied = await applyProviderOutcome(db, {
    intent: intent as IntentRow,
    booking,
    result: envelope.result,
    providerEventId: eventId,
    capturedAmountCents: envelope.amountCents,
    actorType: "system",
  });
  return { duplicate: applied.duplicate, intent: applied.intent };
}

export async function staffListPayments(db: SupabaseClient) {
  const { data, error } = await db
    .from("payment_intents")
    .select("*")
    .order("created_at", { ascending: false })
    .limit(200);
  if (error) throw error;
  return (data ?? []).map((r) => publicIntent(r as IntentRow));
}

export async function staffGetPayment(db: SupabaseClient, intentId: string) {
  const intent = await loadIntent(db, intentId);
  const [{ data: ledger }, { data: refunds }, { data: events }, { data: attempts }, booking] =
    await Promise.all([
      db.from("payment_ledger_entries").select("*").eq("payment_intent_id", intentId).order("created_at"),
      db.from("payment_refunds").select("*").eq("payment_intent_id", intentId).order("created_at", { ascending: false }),
      db.from("payment_events").select("id, event_type, provider, provider_event_id, verification_status, created_at, payload_safe")
        .eq("payment_intent_id", intentId).order("created_at", { ascending: false }),
      db.from("payment_attempts").select("id, status, provider, provider_reference, failure_code, failure_message, created_at")
        .eq("payment_intent_id", intentId).order("created_at", { ascending: false }),
      loadBooking(db, String(intent.booking_id)),
    ]);
  return {
    intent: publicIntent(intent),
    booking: {
      id: booking.id,
      status: booking.status,
      payment_status: booking.payment_status,
      item_name: booking.item_name,
      item_type: booking.item_type,
      customer_user_id: booking.user_id,
      quoted_total: booking.quoted_total,
      currency: booking.currency,
    },
    ledger: ledger ?? [],
    refunds: refunds ?? [],
    events: events ?? [],
    attempts: attempts ?? [],
  };
}

export async function staffReconcile(
  db: SupabaseClient,
  args: {
    userId: string;
    intentId: string;
    settlementStatus: "reconciled" | "discrepancy" | "pending" | "unsettled";
    note: string;
  },
) {
  const { data, error } = await db
    .from("payment_intents")
    .update({
      settlement_status: args.settlementStatus,
      reconciled_at: args.settlementStatus === "reconciled"
        ? new Date().toISOString()
        : null,
      reconciled_by_user_id: args.userId,
      reconciliation_note: args.note.slice(0, 1000),
    })
    .eq("id", args.intentId)
    .select("*")
    .single();
  if (error) throw error;
  await recordBookingEvent(db, {
    booking_id: String(data.booking_id),
    event_type: "reconciliation_changed",
    actor_type: "staff",
    actor_user_id: args.userId,
    metadata: {
      payment_intent_id: args.intentId,
      settlement_status: args.settlementStatus,
    },
  });
  return publicIntent(data as IntentRow);
}
