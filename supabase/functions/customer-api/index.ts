/**
 * M3B.5 customer-api Edge Function
 *
 * Flutter → Supabase Auth access token (Authorization: Bearer)
 *   → auth.getUser(token) → user_id
 *   → service_role DB ops scoped by user_id
 *
 * Never trusts client user_id / firebase_uid / quoted price / status / role.
 *
 * Deploy:
 *   supabase functions deploy customer-api --project-ref xchddfpfzrzhlbbmyhyn
 *
 * Gateway: verify_jwt=true (config.toml). Function still verifies via getUser.
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
  verifySupabaseAccessToken,
} from "./supabase_auth.ts";
import {
  DocumentValidationError,
  sanitizeCreateTravelDocument,
} from "./document_rules.ts";
import {
  archiveTravelDocument,
  createDocumentSignedUrl,
  createPendingTravelDocument,
  finalizeTravelDocument,
  listTravelDocumentsForCustomer,
} from "./document_service.ts";

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
  | "close_enquiry"
  | "list_travel_documents"
  | "create_travel_document_upload"
  | "finalize_travel_document"
  | "get_travel_document_url"
  | "delete_travel_document";

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

    const body = (await req.json().catch(() => ({}))) as Record<
      string,
      unknown
    >;
    const action = String(body.action ?? "") as Action;
    if (!action) {
      return json(400, { status: "error", message: "action is required" });
    }

    try {
      assertNoAuthoritativeClientFields(body);
    } catch (e) {
      return json(400, { status: "error", message: (e as Error).message });
    }

    const db = adminClient();
    const uid = user.id;

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
              user_id: uid,
              full_name: fullName,
              email,
              phone,
              updated_at: new Date().toISOString(),
            },
            { onConflict: "user_id" },
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
          .eq("user_id", uid)
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
        delete payload.firebase_uid;
        delete payload.user_id;
        delete payload.quoted_total;
        delete payload.payment_status;

        const { data: profile } = await db
          .from("customer_profiles")
          .select("id")
          .eq("user_id", uid)
          .maybeSingle();

        const { data, error } = await db
          .from("enquiries")
          .insert({
            kind,
            user_id: uid,
            customer_profile_id: profile?.id ?? null,
            payload,
            status: "received",
          })
          .select("*")
          .single();
        if (error) throw error;
        {
          const { error: evErr } = await db.from("enquiry_events").insert({
            enquiry_id: data.id,
            event_type: "received",
            previous_status: null,
            new_status: "received",
            actor_type: "customer",
            actor_user_id: uid,
            metadata: { kind },
          });
          if (evErr) console.warn("enquiry_events insert", evErr.message);
        }
        return json(200, { status: "success", data });
      }

      case "list_enquiries": {
        const { data, error } = await db
          .from("enquiries")
          .select("*")
          .eq("user_id", uid)
          .order("created_at", { ascending: false });
        if (error) throw error;
        return json(200, { status: "success", data: data ?? [] });
      }

      case "create_booking_request": {
        const input = sanitizeBookingCreateInput(body);

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
          user_id: uid,
          item_type: input.item_type,
          item_legacy_id: input.item_legacy_id,
          item_id: itemId,
          item_name: itemName || "Booking request",
          num_travelers: input.num_travelers,
          requested_total: input.requested_total,
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
        {
          const { error: evErr } = await db.from("booking_events").insert({
            booking_id: data.id,
            event_type: "submitted",
            previous_status: null,
            new_status: "submitted",
            actor_type: "customer",
            actor_user_id: uid,
            metadata: {},
          });
          if (evErr) console.warn("booking_events insert", evErr.message);
        }
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
          .eq("user_id", uid)
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
          .select("id, user_id, status")
          .eq("id", bookingId)
          .maybeSingle();
        if (findErr) throw findErr;
        if (!existing || existing.user_id !== uid) {
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
          .eq("user_id", uid)
          .select("*")
          .single();
        if (error) throw error;
        {
          const { error: evErr } = await db.from("booking_events").insert({
            booking_id: bookingId,
            event_type: "cancelled",
            previous_status: String(existing.status),
            new_status: "cancelled",
            actor_type: "customer",
            actor_user_id: uid,
            metadata: reason ? { reason } : {},
          });
          if (evErr) console.warn("booking_events insert", evErr.message);
        }
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
          .eq("user_id", uid)
          .maybeSingle();

        const { data, error } = await db
          .from("enquiries")
          .insert({
            kind: "flight",
            user_id: uid,
            customer_profile_id: profile?.id ?? null,
            payload,
            status: "received",
          })
          .select("*")
          .single();
        if (error) throw error;
        {
          const { error: evErr } = await db.from("enquiry_events").insert({
            enquiry_id: data.id,
            event_type: "received",
            previous_status: null,
            new_status: "received",
            actor_type: "customer",
            actor_user_id: uid,
            metadata: { kind: "flight" },
          });
          if (evErr) console.warn("enquiry_events insert", evErr.message);
        }
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
          .select("id, user_id, status")
          .eq("id", enquiryId)
          .maybeSingle();
        if (findErr) throw findErr;
        if (!existing || existing.user_id !== uid) {
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
          .eq("user_id", uid)
          .select("*")
          .single();
        if (error) throw error;
        return json(200, { status: "success", data });
      }

      case "list_travel_documents": {
        const data = await listTravelDocumentsForCustomer(db, uid);
        return json(200, { status: "success", data });
      }

      case "create_travel_document_upload": {
        let input;
        try {
          input = sanitizeCreateTravelDocument(body);
        } catch (e) {
          if (e instanceof DocumentValidationError) {
            return json(400, {
              status: "error",
              code: e.code,
              message: e.message,
            });
          }
          throw e;
        }
        const created = await createPendingTravelDocument(db, uid, input);
        return json(200, {
          status: "success",
          data: {
            document: {
              id: created.row.id,
              document_type: created.row.document_type,
              display_name: created.row.display_name,
              mime_type: created.row.mime_type,
              file_size: created.row.file_size,
              upload_status: created.row.upload_status,
              verification_status: created.row.verification_status,
              expiry_date: created.row.expiry_date ?? null,
              created_at: created.row.created_at,
            },
            upload: created.upload,
            // Never return a permanent public URL.
            public_url: null,
          },
        });
      }

      case "finalize_travel_document": {
        const documentId = String(body.document_id ?? "");
        if (!documentId) {
          return json(400, { status: "error", message: "document_id required" });
        }
        try {
          const row = await finalizeTravelDocument(db, uid, documentId);
          return json(200, {
            status: "success",
            data: {
              id: row.id,
              upload_status: row.upload_status,
              verification_status: row.verification_status,
            },
          });
        } catch (e) {
          const status = (e as { status?: number }).status ?? 500;
          if (status === 404) {
            return json(404, { status: "error", message: "Document not found" });
          }
          throw e;
        }
      }

      case "get_travel_document_url": {
        const documentId = String(body.document_id ?? "");
        if (!documentId) {
          return json(400, { status: "error", message: "document_id required" });
        }
        try {
          const signed = await createDocumentSignedUrl(db, {
            documentId,
            actorUserId: uid,
            actorType: "customer",
            requireOwnerUserId: uid,
          });
          return json(200, {
            status: "success",
            data: {
              signed_url: signed.signed_url,
              expires_in: signed.expires_in,
              document: signed.document,
              public_url: null,
            },
          });
        } catch (e) {
          const status = (e as { status?: number }).status ?? 500;
          if (status === 404) {
            return json(404, { status: "error", message: "Document not found" });
          }
          if (status === 409) {
            return json(409, {
              status: "error",
              message: (e as Error).message,
            });
          }
          throw e;
        }
      }

      case "delete_travel_document": {
        const documentId = String(body.document_id ?? "");
        if (!documentId) {
          return json(400, { status: "error", message: "document_id required" });
        }
        try {
          await archiveTravelDocument(db, uid, documentId);
          return json(200, { status: "success", data: { deleted: true } });
        } catch (e) {
          const status = (e as { status?: number }).status ?? 500;
          if (status === 404) {
            return json(404, { status: "error", message: "Document not found" });
          }
          throw e;
        }
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
