/**
 * M3D payment-commerce-api
 *
 * Customer/staff JWT actions + provider webhooks.
 * Gateway: verify_jwt=false so webhooks work; user actions still call getUser.
 *
 * Never trusts client amount / currency / fees / payment_status / user_id.
 * Never stores PAN/CVV/PIN. Never returns service_role or provider secrets.
 *
 * Deploy:
 *   supabase functions deploy payment-commerce-api --project-ref xchddfpfzrzhlbbmyhyn
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import { PaymentError } from "./payment_domain.ts";
import {
  assertNoRejectedClientFields,
  isMockProviderAllowed,
  parseWebhookEnvelope,
  stripUntrustedMoneyFields,
  timingSafeEqual,
} from "./payment_rules.ts";
import {
  createPaymentIntent,
  getOwnedIntent,
  handleProviderWebhook,
  listMyPayments,
  mockSimulateResult,
  processRefund,
  requestRefund,
  requireStaff,
  staffGetPayment,
  staffListPayments,
  staffReconcile,
  verifyPayment,
} from "./payment_service.ts";
import {
  extractBearerToken,
  verifySupabaseAccessToken,
} from "./supabase_auth.ts";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-destiny-webhook-secret, x-webhook-signature",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type CustomerAction =
  | "create_payment_intent"
  | "get_payment_intent"
  | "list_my_payments"
  | "verify_payment"
  | "request_refund"
  | "mock_simulate_result";

type StaffAction =
  | "staff_list_payments"
  | "staff_get_payment"
  | "staff_list_ledger"
  | "staff_request_refund"
  | "staff_process_refund"
  | "staff_reconcile";

const CUSTOMER_ACTIONS = new Set<string>([
  "create_payment_intent",
  "get_payment_intent",
  "list_my_payments",
  "verify_payment",
  "request_refund",
  "mock_simulate_result",
]);

const STAFF_ACTIONS = new Set<string>([
  "staff_list_payments",
  "staff_get_payment",
  "staff_list_ledger",
  "staff_request_refund",
  "staff_process_refund",
  "staff_reconcile",
]);

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function errorJson(err: unknown): Response {
  if (err instanceof PaymentError) {
    return json(err.httpStatus, {
      status: "error",
      code: err.code,
      message: err.message,
    });
  }
  console.error("payment-commerce-api", (err as Error)?.message ?? "error");
  return json(500, {
    status: "error",
    code: "internal_error",
    message: "Payment commerce failed",
  });
}

function adminClient() {
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) {
    throw new Error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
  }
  return createClient(url, key, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

function isWebhookRequest(req: Request, body: Record<string, unknown>): boolean {
  const url = new URL(req.url);
  if (url.pathname.endsWith("/webhook") || url.searchParams.get("webhook") === "1") {
    return true;
  }
  return String(body.action ?? "") === "provider_webhook";
}

function verifyMockWebhookSecret(req: Request): void {
  const expected = Deno.env.get("PAYMENT_MOCK_WEBHOOK_SECRET") ?? "";
  if (!expected) {
    throw new PaymentError(
      "webhook_unconfigured",
      "Mock webhook secret is not configured",
      401,
    );
  }
  const got = req.headers.get("x-destiny-webhook-secret") ??
    req.headers.get("X-Destiny-Webhook-Secret") ??
    "";
  if (!timingSafeEqual(got, expected)) {
    throw new PaymentError("webhook_unauthorized", "Invalid webhook secret", 401);
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json(405, { status: "error", message: "POST required" });
  }

  try {
    const rawBody = await req.json().catch(() => null);
    if (isWebhookRequest(req, (rawBody && typeof rawBody === "object") ? rawBody as Record<string, unknown> : {})) {
      try {
        const envelope = parseWebhookEnvelope(rawBody);
        if (envelope.provider === "mock") {
          if (!isMockProviderAllowed({
            DESTINY_ENV: Deno.env.get("DESTINY_ENV") ?? undefined,
            PAYMENT_ENV: Deno.env.get("PAYMENT_ENV") ?? undefined,
            PAYMENT_ALLOW_MOCK: Deno.env.get("PAYMENT_ALLOW_MOCK") ?? undefined,
          })) {
            return json(409, {
              status: "error",
              code: "mock_disabled",
              message: "Mock payment provider is disabled",
            });
          }
          verifyMockWebhookSecret(req);
        } else {
          return json(501, {
            status: "error",
            code: "provider_not_configured",
            message:
              `${envelope.provider} webhook verification requires official provider documentation`,
          });
        }
        const db = adminClient();
        const data = await handleProviderWebhook(db, envelope);
        return json(200, { status: "success", data });
      } catch (e) {
        return errorJson(e);
      }
    }

    const body = (rawBody && typeof rawBody === "object")
      ? rawBody as Record<string, unknown>
      : {};
    const action = String(body.action ?? "");
    if (!action) {
      return json(400, { status: "error", message: "action is required" });
    }

    try {
      assertNoRejectedClientFields(body);
    } catch (e) {
      return errorJson(e);
    }
    const safe = stripUntrustedMoneyFields(body);

    const token = extractBearerToken(req);
    if (!token) {
      return json(401, {
        status: "error",
        message: "Missing Supabase access token (Authorization: Bearer)",
      });
    }
    let user;
    try {
      user = await verifySupabaseAccessToken(token);
    } catch (e) {
      return json(401, {
        status: "error",
        message: `Invalid Supabase token: ${(e as Error).message}`,
      });
    }

    const db = adminClient();

    if (STAFF_ACTIONS.has(action)) {
      const staff = await requireStaff(db, user.id);
      switch (action as StaffAction) {
        case "staff_list_payments": {
          const data = await staffListPayments(db);
          return json(200, { status: "success", data });
        }
        case "staff_get_payment":
        case "staff_list_ledger": {
          const intentId = String(safe.payment_intent_id ?? "");
          if (!intentId) {
            return json(400, { status: "error", message: "payment_intent_id is required" });
          }
          const data = await staffGetPayment(db, intentId);
          return json(200, { status: "success", data });
        }
        case "staff_request_refund": {
          const intentId = String(safe.payment_intent_id ?? "");
          if (!intentId) {
            return json(400, { status: "error", message: "payment_intent_id is required" });
          }
          const data = await requestRefund(db, {
            userId: staff.user_id,
            intentId,
            amountRaw: body.refund_amount,
            reason: String(safe.reason ?? "Staff refund request"),
            actorType: "staff",
          });
          return json(200, { status: "success", data });
        }
        case "staff_process_refund": {
          const refundId = String(safe.refund_id ?? "");
          if (!refundId) {
            return json(400, { status: "error", message: "refund_id is required" });
          }
          const data = await processRefund(db, {
            userId: staff.user_id,
            refundId,
          });
          return json(200, { status: "success", data });
        }
        case "staff_reconcile": {
          const intentId = String(safe.payment_intent_id ?? "");
          const settlement = String(safe.settlement_status ?? "");
          if (!intentId) {
            return json(400, { status: "error", message: "payment_intent_id is required" });
          }
          if (!["reconciled", "discrepancy", "pending", "unsettled"].includes(settlement)) {
            return json(400, { status: "error", message: "Invalid settlement_status" });
          }
          const data = await staffReconcile(db, {
            userId: staff.user_id,
            intentId,
            settlementStatus: settlement as
              | "reconciled"
              | "discrepancy"
              | "pending"
              | "unsettled",
            note: String(safe.note ?? ""),
          });
          return json(200, { status: "success", data });
        }
      }
    }

    if (!CUSTOMER_ACTIONS.has(action)) {
      return json(400, { status: "error", message: `Unknown action '${action}'` });
    }

    switch (action as CustomerAction) {
      case "create_payment_intent": {
        const bookingId = String(safe.booking_id ?? "");
        if (!bookingId) {
          return json(400, { status: "error", message: "booking_id is required" });
        }
        const data = await createPaymentIntent(db, {
          userId: user.id,
          bookingId,
        });
        return json(200, { status: "success", data });
      }
      case "get_payment_intent": {
        const intentId = String(safe.payment_intent_id ?? "");
        if (!intentId) {
          return json(400, { status: "error", message: "payment_intent_id is required" });
        }
        const data = await getOwnedIntent(db, {
          userId: user.id,
          intentId,
        });
        return json(200, { status: "success", data });
      }
      case "list_my_payments": {
        const data = await listMyPayments(db, user.id);
        return json(200, { status: "success", data });
      }
      case "verify_payment": {
        const intentId = String(safe.payment_intent_id ?? "");
        if (!intentId) {
          return json(400, { status: "error", message: "payment_intent_id is required" });
        }
        const data = await verifyPayment(db, {
          userId: user.id,
          intentId,
        });
        return json(200, { status: "success", data });
      }
      case "request_refund": {
        const intentId = String(safe.payment_intent_id ?? "");
        if (!intentId) {
          return json(400, { status: "error", message: "payment_intent_id is required" });
        }
        const data = await requestRefund(db, {
          userId: user.id,
          intentId,
          amountRaw: body.refund_amount,
          reason: String(safe.reason ?? "Customer refund request"),
          actorType: "customer",
        });
        return json(200, { status: "success", data });
      }
      case "mock_simulate_result": {
        const intentId = String(safe.payment_intent_id ?? "");
        const result = String(safe.mock_result ?? "");
        if (!intentId) {
          return json(400, { status: "error", message: "payment_intent_id is required" });
        }
        if (result !== "succeeded" && result !== "failed" && result !== "cancelled") {
          return json(400, { status: "error", message: "mock_result must be succeeded|failed|cancelled" });
        }
        const data = await mockSimulateResult(db, {
          userId: user.id,
          intentId,
          result,
        });
        return json(200, { status: "success", data });
      }
    }

    return json(400, { status: "error", message: `Unknown action '${action}'` });
  } catch (e) {
    return errorJson(e);
  }
});
