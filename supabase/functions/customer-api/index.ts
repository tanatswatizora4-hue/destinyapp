/**
 * M3A customer-api Edge Function
 *
 * Flutter → Firebase ID token (Authorization: Bearer) → verify → service_role DB ops.
 * Never trusts client firebase_uid / quoted price / status / payment_status.
 *
 * Deploy:
 *   supabase functions deploy customer-api --project-ref xchddfpfzrzhlbbmyhyn
 * Optional secret:
 *   supabase secrets set FIREBASE_PROJECT_ID=destinytravel-1a16e
 *
 * verify_jwt=false (config.toml) — gateway must not expect a Supabase user JWT.
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import {
  assertNoAuthoritativeClientFields,
  canCustomerCancel,
  sanitizeBookingCreateInput,
  sanitizeFlightEnquiryPayload,
} from "./commerce_rules.ts";
import {
  extractBearerToken,
  verifyFirebaseIdToken,
} from "./firebase_verify.ts";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
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

type Action =
  | "upsert_profile"
  | "get_profile"
  | "create_enquiry"
  | "list_enquiries"
  | "create_booking_request"
  | "list_bookings"
  | "cancel_booking"
  | "create_flight_enquiry"
  | "close_enquiry";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json(405, { status: "error", message: "POST required" });
  }

  try {
    const token = extractBearerToken(req);
    if (!token) {
      return json(401, {
        status: "error",
        message: "Missing Firebase ID token (Authorization: Bearer)",
      });
    }

    let user;
    try {
      user = await verifyFirebaseIdToken(token);
    } catch (e) {
      return json(401, {
        status: "error",
        message: `Invalid Firebase token: ${(e as Error).message}`,
      });
    }

    const body = (await req.json().catch(() => ({}))) as Record<
      string,
      unknown
    >;
    const action = String(body.action ?? "") as Action;
    if (!action) {
      return json(400, { status: "error", message: "action is required" });
    }

    // Reject identity / authority spoofing on every action.
    try {
      assertNoAuthoritativeClientFields(body);
    } catch (e) {
      return json(400, { status: "error", message: (e as Error).message });
    }

    const db = adminClient();
    const uid = user.uid;

    switch (action) {
      case "upsert_profile": {
        const fullName = String(
          body.full_name ?? user.name ?? "",
        ).slice(0, 200);
        const email = String(body.email ?? user.email ?? "").slice(0, 320);
        const phone = body.phone == null
          ? null
          : String(body.phone).slice(0, 40);

        const { data, error } = await db
          .from("customer_profiles")
          .upsert(
            {
              firebase_uid: uid,
              full_name: fullName,
              email,
              phone,
              updated_at: new Date().toISOString(),
            },
            { onConflict: "firebase_uid" },
          )
          .select("*")
          .single();
        if (error) throw error;
        return json(200, { status: "success", data });
      }

      case "get_profile": {
        const { data, error } = await db
          .from("customer_profiles")
          .select("*")
          .eq("firebase_uid", uid)
          .maybeSingle();
        if (error) throw error;
        return json(200, { status: "success", data });
      }

      case "create_enquiry": {
        const kind = String(body.kind ?? "general");
        if (!["flight", "general", "stay", "vehicle", "tour"].includes(kind)) {
          return json(400, { status: "error", message: "Invalid enquiry kind" });
        }
        const payload = (body.payload && typeof body.payload === "object")
          ? body.payload as Record<string, unknown>
          : {};
        // Strip spoof fields from nested payload too.
        delete payload.firebase_uid;
        delete payload.quoted_total;
        delete payload.payment_status;

        const { data: profile } = await db
          .from("customer_profiles")
          .select("id")
          .eq("firebase_uid", uid)
          .maybeSingle();

        const { data, error } = await db
          .from("enquiries")
          .insert({
            kind,
            firebase_uid: uid,
            customer_profile_id: profile?.id ?? null,
            payload,
            status: "received",
          })
          .select("*")
          .single();
        if (error) throw error;
        return json(200, { status: "success", data });
      }

      case "list_enquiries": {
        const { data, error } = await db
          .from("enquiries")
          .select("*")
          .eq("firebase_uid", uid)
          .order("created_at", { ascending: false });
        if (error) throw error;
        return json(200, { status: "success", data: data ?? [] });
      }

      case "create_booking_request": {
        const input = sanitizeBookingCreateInput(body);

        // Resolve inventory UUID from published tables when possible.
        let itemId = input.item_id;
        let itemName = input.item_name;
        if (!itemId && input.item_legacy_id != null) {
          if (input.item_type === "tour") {
            const { data: inv } = await db
              .from("tours")
              .select("id, title")
              .eq("legacy_id", input.item_legacy_id)
              .eq("is_published", true)
              .maybeSingle();
            if (inv) {
              itemId = inv.id as string;
              if (!itemName) itemName = String(inv.title ?? "");
            }
          } else if (input.item_type === "vehicle") {
            const { data: inv } = await db
              .from("vehicles")
              .select("id, make, model")
              .eq("legacy_id", input.item_legacy_id)
              .eq("is_published", true)
              .maybeSingle();
            if (inv) {
              itemId = inv.id as string;
              if (!itemName) {
                itemName = `${inv.make ?? ""} ${inv.model ?? ""}`.trim();
              }
            }
          } else {
            const { data: inv } = await db
              .from("stays")
              .select("id, name")
              .eq("legacy_id", input.item_legacy_id)
              .eq("is_published", true)
              .maybeSingle();
            if (inv) {
              itemId = inv.id as string;
              if (!itemName) itemName = String(inv.name ?? "");
            }
          }
        }

        const row = {
          firebase_uid: uid,
          item_type: input.item_type,
          item_legacy_id: input.item_legacy_id,
          item_id: itemId,
          item_name: itemName || "Booking request",
          num_travelers: input.num_travelers,
          requested_total: input.requested_total,
          // Mirror estimate into legacy column for older readers; NOT a quote.
          total_price: input.requested_total ?? 0,
          quoted_total: null,
          currency: input.currency,
          currency_requested: input.currency,
          payment_status: "none",
          status: "submitted",
          start_date: input.start_date,
          end_date: input.end_date,
          item_image_json: input.item_image_json,
          customer_notes: input.customer_notes,
        };

        const { data, error } = await db
          .from("bookings")
          .insert(row)
          .select("*")
          .single();
        if (error) throw error;
        return json(200, {
          status: "success",
          message:
            "Request submitted. Destiny will review and confirm availability.",
          data,
        });
      }

      case "list_bookings": {
        const { data, error } = await db
          .from("bookings")
          .select("*")
          .eq("firebase_uid", uid)
          .order("created_at", { ascending: false });
        if (error) throw error;
        return json(200, { status: "success", data: data ?? [] });
      }

      case "cancel_booking": {
        const bookingId = String(body.booking_id ?? "");
        if (!bookingId) {
          return json(400, { status: "error", message: "booking_id required" });
        }
        const reason = String(body.reason ?? "").slice(0, 500);

        const { data: existing, error: findErr } = await db
          .from("bookings")
          .select("id, firebase_uid, status")
          .eq("id", bookingId)
          .maybeSingle();
        if (findErr) throw findErr;
        if (!existing || existing.firebase_uid !== uid) {
          return json(404, {
            status: "error",
            message: "Booking not found",
          });
        }
        if (!canCustomerCancel(String(existing.status))) {
          return json(409, {
            status: "error",
            message:
              `Booking status '${existing.status}' cannot be cancelled by customer`,
          });
        }

        const { data, error } = await db
          .from("bookings")
          .update({
            status: "cancelled",
            cancellation_reason: reason || null,
            cancelled_at: new Date().toISOString(),
          })
          .eq("id", bookingId)
          .eq("firebase_uid", uid)
          .select("*")
          .single();
        if (error) throw error;
        return json(200, { status: "success", data });
      }

      case "create_flight_enquiry": {
        const payload = sanitizeFlightEnquiryPayload(body);
        if (!payload.origin || !payload.destination) {
          return json(400, {
            status: "error",
            message: "origin and destination are required",
          });
        }

        const { data: profile } = await db
          .from("customer_profiles")
          .select("id")
          .eq("firebase_uid", uid)
          .maybeSingle();

        const { data, error } = await db
          .from("enquiries")
          .insert({
            kind: "flight",
            firebase_uid: uid,
            customer_profile_id: profile?.id ?? null,
            payload,
            status: "received",
          })
          .select("*")
          .single();
        if (error) throw error;
        return json(200, {
          status: "success",
          message:
            "Flight enquiry submitted. Destiny will review and respond.",
          data,
        });
      }

      case "close_enquiry": {
        const enquiryId = String(body.enquiry_id ?? "");
        if (!enquiryId) {
          return json(400, { status: "error", message: "enquiry_id required" });
        }
        const { data: existing, error: findErr } = await db
          .from("enquiries")
          .select("id, firebase_uid, status")
          .eq("id", enquiryId)
          .maybeSingle();
        if (findErr) throw findErr;
        if (!existing || existing.firebase_uid !== uid) {
          return json(404, { status: "error", message: "Enquiry not found" });
        }
        if (!["received", "in_review"].includes(String(existing.status))) {
          return json(409, {
            status: "error",
            message: `Enquiry status '${existing.status}' cannot be closed by customer`,
          });
        }
        const { data, error } = await db
          .from("enquiries")
          .update({ status: "closed" })
          .eq("id", enquiryId)
          .eq("firebase_uid", uid)
          .select("*")
          .single();
        if (error) throw error;
        return json(200, { status: "success", data });
      }

      default:
        return json(400, {
          status: "error",
          message: `Unknown action: ${action}`,
        });
    }
  } catch (e) {
    console.error("customer-api error", e);
    return json(500, {
      status: "error",
      message: (e as Error).message || "Internal error",
    });
  }
});
