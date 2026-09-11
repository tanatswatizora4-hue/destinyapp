/**
 * M3B.5 staff-commerce-api
 *
 * Flutter staff → Supabase Auth access token → getUser → staff_users.user_id
 *   → is_active + role → privileged service_role ops.
 *
 * Never authorize by email alone. Never trust body.user_id / role.
 * Gateway: verify_jwt=true.
 */

import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import {
  assertStaffBodySafe,
  canStaffTransitionBooking,
  canStaffTransitionEnquiry,
  sanitizeQuoteInput,
} from "./lifecycle_rules.ts";
import {
  extractBearerToken,
  verifySupabaseAccessToken,
} from "./supabase_auth.ts";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type StaffRow = {
  id: string;
  user_id: string;
  email: string;
  display_name: string;
  role: string;
  is_active: boolean;
};

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function adminClient(): SupabaseClient {
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) throw new Error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
  return createClient(url, key, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

async function requireStaff(
  db: SupabaseClient,
  userId: string,
): Promise<{ staff: StaffRow | null; status: number; message?: string }> {
  const { data, error } = await db
    .from("staff_users")
    .select("id, user_id, email, display_name, role, is_active")
    .eq("user_id", userId)
    .maybeSingle();
  if (error) throw error;
  if (!data) {
    return { staff: null, status: 403, message: "Not authorized as Destiny staff" };
  }
  if (!data.is_active) {
    return { staff: null, status: 403, message: "Staff account inactive" };
  }
  return { staff: data as StaffRow, status: 200 };
}

async function recordBookingEvent(
  db: SupabaseClient,
  args: {
    booking_id: string;
    event_type: string;
    previous_status?: string | null;
    new_status?: string | null;
    actor_user_id: string;
    metadata?: Record<string, unknown>;
  },
) {
  const { error } = await db.from("booking_events").insert({
    booking_id: args.booking_id,
    event_type: args.event_type,
    previous_status: args.previous_status ?? null,
    new_status: args.new_status ?? null,
    actor_type: "staff",
    actor_user_id: args.actor_user_id,
    metadata: args.metadata ?? {},
  });
  if (error) throw error;
}

async function recordEnquiryEvent(
  db: SupabaseClient,
  args: {
    enquiry_id: string;
    event_type: string;
    previous_status?: string | null;
    new_status?: string | null;
    actor_user_id: string;
    metadata?: Record<string, unknown>;
  },
) {
  const { error } = await db.from("enquiry_events").insert({
    enquiry_id: args.enquiry_id,
    event_type: args.event_type,
    previous_status: args.previous_status ?? null,
    new_status: args.new_status ?? null,
    actor_type: "staff",
    actor_user_id: args.actor_user_id,
    metadata: args.metadata ?? {},
  });
  if (error) throw error;
}

type Action =
  | "staff_me"
  | "list_bookings"
  | "get_booking"
  | "quote_booking"
  | "transition_booking"
  | "add_booking_note"
  | "list_enquiries"
  | "get_enquiry"
  | "update_enquiry"
  | "convert_enquiry";

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
      assertStaffBodySafe(body);
    } catch (e) {
      return json(400, { status: "error", message: (e as Error).message });
    }

    const db = adminClient();
    const authz = await requireStaff(db, user.id);
    if (!authz.staff) {
      return json(authz.status, {
        status: "error",
        message: authz.message ?? "Forbidden",
      });
    }
    const staff = authz.staff;

    switch (action) {
      case "staff_me": {
        return json(200, { status: "success", data: staff });
      }

      case "list_bookings": {
        const statusFilter = body.status ? String(body.status) : null;
        let q = db
          .from("bookings")
          .select("*")
          .order("created_at", { ascending: false })
          .limit(200);
        if (statusFilter) q = q.eq("status", statusFilter);
        const { data, error } = await q;
        if (error) throw error;
        return json(200, { status: "success", data: data ?? [] });
      }

      case "get_booking": {
        const bookingId = String(body.booking_id ?? "");
        if (!bookingId) {
          return json(400, { status: "error", message: "booking_id required" });
        }
        const { data, error } = await db
          .from("bookings")
          .select("*")
          .eq("id", bookingId)
          .maybeSingle();
        if (error) throw error;
        if (!data) {
          return json(404, { status: "error", message: "Booking not found" });
        }
        const { data: events } = await db
          .from("booking_events")
          .select("*")
          .eq("booking_id", bookingId)
          .order("created_at", { ascending: false })
          .limit(50);
        return json(200, {
          status: "success",
          data: { ...data, events: events ?? [] },
        });
      }

      case "quote_booking": {
        const bookingId = String(body.booking_id ?? "");
        if (!bookingId) {
          return json(400, { status: "error", message: "booking_id required" });
        }
        let quote;
        try {
          quote = sanitizeQuoteInput(body);
        } catch (e) {
          return json(400, { status: "error", message: (e as Error).message });
        }

        const { data: existing, error: findErr } = await db
          .from("bookings")
          .select("*")
          .eq("id", bookingId)
          .maybeSingle();
        if (findErr) throw findErr;
        if (!existing) {
          return json(404, { status: "error", message: "Booking not found" });
        }

        const prev = String(existing.status);
        let nextStatus = prev;
        if (prev === "submitted") {
          if (!canStaffTransitionBooking(prev, "quoted")) {
            return json(409, {
              status: "error",
              message: `Cannot quote from status '${prev}'`,
            });
          }
          nextStatus = "quoted";
        } else if (prev === "quoted") {
          nextStatus = "quoted";
        } else {
          return json(409, {
            status: "error",
            message: `Cannot quote from status '${prev}'`,
          });
        }

        const internalNotes = quote.internal_note
          ? `${existing.internal_notes || ""}${
            existing.internal_notes ? "\n" : ""
          }[${new Date().toISOString()}] ${quote.internal_note}`.slice(0, 8000)
          : existing.internal_notes;

        const { data, error } = await db
          .from("bookings")
          .update({
            quoted_total: quote.quoted_total,
            currency: quote.currency,
            quote_expires_at: quote.quote_expires_at,
            customer_quote_note: quote.customer_quote_note,
            internal_notes: internalNotes,
            status: nextStatus,
            quoted_at: new Date().toISOString(),
            quoted_by_user_id: staff.user_id,
            assigned_staff_user_id: staff.user_id,
            payment_status: existing.payment_status === "paid"
              ? existing.payment_status
              : "none",
          })
          .eq("id", bookingId)
          .select("*")
          .single();
        if (error) throw error;

        await recordBookingEvent(db, {
          booking_id: bookingId,
          event_type: prev === nextStatus ? "quote_changed" : "quoted",
          previous_status: prev,
          new_status: nextStatus,
          actor_user_id: staff.user_id,
          metadata: {
            quoted_total: quote.quoted_total,
            currency: quote.currency,
            quote_expires_at: quote.quote_expires_at,
            has_customer_note: Boolean(quote.customer_quote_note),
          },
        });

        return json(200, { status: "success", data });
      }

      case "transition_booking": {
        const bookingId = String(body.booking_id ?? "");
        const toStatus = String(body.to_status ?? "");
        if (!bookingId || !toStatus) {
          return json(400, {
            status: "error",
            message: "booking_id and to_status required",
          });
        }
        const { data: existing, error: findErr } = await db
          .from("bookings")
          .select("*")
          .eq("id", bookingId)
          .maybeSingle();
        if (findErr) throw findErr;
        if (!existing) {
          return json(404, { status: "error", message: "Booking not found" });
        }
        const prev = String(existing.status);
        if (!canStaffTransitionBooking(prev, toStatus)) {
          return json(409, {
            status: "error",
            message: `Illegal transition ${prev} → ${toStatus}`,
          });
        }
        if (toStatus === "quoted" && existing.quoted_total == null) {
          return json(409, {
            status: "error",
            message: "Use quote_booking to set an authoritative quote",
          });
        }
        if (toStatus === "awaiting_payment" && existing.quoted_total == null) {
          return json(409, {
            status: "error",
            message: "Cannot await payment without an authoritative quote",
          });
        }
        if (toStatus === "confirmed" && existing.quoted_total == null) {
          return json(409, {
            status: "error",
            message: "Cannot confirm without an authoritative quote",
          });
        }

        const patch: Record<string, unknown> = {
          status: toStatus,
          assigned_staff_user_id: staff.user_id,
        };
        if (toStatus === "cancelled") {
          patch.cancellation_reason = String(body.reason ?? "Cancelled by Destiny staff")
            .slice(0, 500);
          patch.cancelled_at = new Date().toISOString();
        }
        if (toStatus === "awaiting_payment") {
          patch.payment_status = "awaiting_payment";
        }

        const { data, error } = await db
          .from("bookings")
          .update(patch)
          .eq("id", bookingId)
          .select("*")
          .single();
        if (error) throw error;

        await recordBookingEvent(db, {
          booking_id: bookingId,
          event_type: `moved_to_${toStatus}`,
          previous_status: prev,
          new_status: toStatus,
          actor_user_id: staff.user_id,
          metadata: body.reason ? { reason: String(body.reason).slice(0, 200) } : {},
        });

        return json(200, { status: "success", data });
      }

      case "add_booking_note": {
        const bookingId = String(body.booking_id ?? "");
        const note = String(body.note ?? "").trim();
        const customerFacing = Boolean(body.customer_facing);
        if (!bookingId || !note) {
          return json(400, {
            status: "error",
            message: "booking_id and note required",
          });
        }
        const { data: existing, error: findErr } = await db
          .from("bookings")
          .select("*")
          .eq("id", bookingId)
          .maybeSingle();
        if (findErr) throw findErr;
        if (!existing) {
          return json(404, { status: "error", message: "Booking not found" });
        }

        const stamp = `[${new Date().toISOString()} ${staff.role}] ${note}`;
        const patch: Record<string, unknown> = customerFacing
          ? {
            customer_quote_note:
              `${existing.customer_quote_note || ""}${
                existing.customer_quote_note ? "\n" : ""
              }${note}`.slice(0, 4000),
          }
          : {
            internal_notes:
              `${existing.internal_notes || ""}${
                existing.internal_notes ? "\n" : ""
              }${stamp}`.slice(0, 8000),
          };

        const { data, error } = await db
          .from("bookings")
          .update(patch)
          .eq("id", bookingId)
          .select("*")
          .single();
        if (error) throw error;

        await recordBookingEvent(db, {
          booking_id: bookingId,
          event_type: customerFacing
            ? "customer_note_added"
            : "staff_note_added",
          previous_status: existing.status,
          new_status: existing.status,
          actor_user_id: staff.user_id,
          metadata: { customer_facing: customerFacing },
        });

        return json(200, { status: "success", data });
      }

      case "list_enquiries": {
        const statusFilter = body.status ? String(body.status) : null;
        let q = db
          .from("enquiries")
          .select("*")
          .order("created_at", { ascending: false })
          .limit(200);
        if (statusFilter) q = q.eq("status", statusFilter);
        const { data, error } = await q;
        if (error) throw error;
        return json(200, { status: "success", data: data ?? [] });
      }

      case "get_enquiry": {
        const enquiryId = String(body.enquiry_id ?? "");
        if (!enquiryId) {
          return json(400, { status: "error", message: "enquiry_id required" });
        }
        const { data, error } = await db
          .from("enquiries")
          .select("*")
          .eq("id", enquiryId)
          .maybeSingle();
        if (error) throw error;
        if (!data) {
          return json(404, { status: "error", message: "Enquiry not found" });
        }
        const { data: events } = await db
          .from("enquiry_events")
          .select("*")
          .eq("enquiry_id", enquiryId)
          .order("created_at", { ascending: false })
          .limit(50);
        return json(200, {
          status: "success",
          data: { ...data, events: events ?? [] },
        });
      }

      case "update_enquiry": {
        const enquiryId = String(body.enquiry_id ?? "");
        const toStatus = body.to_status != null ? String(body.to_status) : null;
        if (!enquiryId) {
          return json(400, { status: "error", message: "enquiry_id required" });
        }
        const { data: existing, error: findErr } = await db
          .from("enquiries")
          .select("*")
          .eq("id", enquiryId)
          .maybeSingle();
        if (findErr) throw findErr;
        if (!existing) {
          return json(404, { status: "error", message: "Enquiry not found" });
        }

        const prev = String(existing.status);
        const patch: Record<string, unknown> = {
          assigned_staff_user_id: staff.user_id,
        };
        if (body.customer_response_note != null) {
          patch.customer_response_note = String(body.customer_response_note)
            .slice(0, 4000);
        }
        if (body.internal_note != null || body.internal_notes != null) {
          const note = String(body.internal_note ?? body.internal_notes).trim();
          if (note) {
            patch.internal_notes =
              `${existing.internal_notes || ""}${
                existing.internal_notes ? "\n" : ""
              }[${new Date().toISOString()}] ${note}`.slice(0, 8000);
          }
        }

        let next = prev;
        if (toStatus) {
          if (toStatus === "converted") {
            return json(400, {
              status: "error",
              message: "Use convert_enquiry to convert",
            });
          }
          if (!canStaffTransitionEnquiry(prev, toStatus)) {
            return json(409, {
              status: "error",
              message: `Illegal enquiry transition ${prev} → ${toStatus}`,
            });
          }
          patch.status = toStatus;
          next = toStatus;
        }

        const { data, error } = await db
          .from("enquiries")
          .update(patch)
          .eq("id", enquiryId)
          .select("*")
          .single();
        if (error) throw error;

        await recordEnquiryEvent(db, {
          enquiry_id: enquiryId,
          event_type: toStatus ? `moved_to_${toStatus}` : "enquiry_updated",
          previous_status: prev,
          new_status: next,
          actor_user_id: staff.user_id,
        });

        return json(200, { status: "success", data });
      }

      case "convert_enquiry": {
        const enquiryId = String(body.enquiry_id ?? "");
        if (!enquiryId) {
          return json(400, { status: "error", message: "enquiry_id required" });
        }
        const { data: enquiry, error: findErr } = await db
          .from("enquiries")
          .select("*")
          .eq("id", enquiryId)
          .maybeSingle();
        if (findErr) throw findErr;
        if (!enquiry) {
          return json(404, { status: "error", message: "Enquiry not found" });
        }
        const prev = String(enquiry.status);
        if (!canStaffTransitionEnquiry(prev, "converted")) {
          return json(409, {
            status: "error",
            message: `Illegal enquiry transition ${prev} → converted`,
          });
        }
        if (!enquiry.user_id) {
          return json(409, {
            status: "error",
            message: "Enquiry missing customer user_id",
          });
        }

        const payload = (enquiry.payload ?? {}) as Record<string, unknown>;
        const kind = String(enquiry.kind);
        const itemType = kind === "stay"
          ? "accommodation"
          : ["tour", "accommodation", "vehicle", "flight"].includes(kind)
          ? kind
          : "tour";
        const itemName = kind === "flight"
          ? `Flight enquiry ${payload.origin ?? ""} → ${payload.destination ?? ""}`
            .trim()
          : `Converted ${kind} enquiry`;

        const bookingRow = {
          user_id: enquiry.user_id,
          item_type: itemType,
          item_name: itemName.slice(0, 200) || "Converted enquiry",
          num_travelers: Number(payload.num_travelers ?? 1) || 1,
          requested_total: null,
          quoted_total: null,
          total_price: 0,
          currency: "USD",
          payment_status: "none",
          status: "submitted",
          start_date: payload.departure_date
            ? String(payload.departure_date).slice(0, 10)
            : null,
          end_date: payload.return_date
            ? String(payload.return_date).slice(0, 10)
            : null,
          item_image_json: [],
          customer_notes: `Converted from enquiry ${enquiryId}`,
          enquiry_id: enquiryId,
          assigned_staff_user_id: staff.user_id,
        };

        const { data: booking, error: bookErr } = await db
          .from("bookings")
          .insert(bookingRow)
          .select("*")
          .single();
        if (bookErr) throw bookErr;

        const { data: updatedEnquiry, error: updErr } = await db
          .from("enquiries")
          .update({
            status: "converted",
            converted_booking_id: booking.id,
            assigned_staff_user_id: staff.user_id,
          })
          .eq("id", enquiryId)
          .select("*")
          .single();
        if (updErr) throw updErr;

        await recordEnquiryEvent(db, {
          enquiry_id: enquiryId,
          event_type: "converted",
          previous_status: prev,
          new_status: "converted",
          actor_user_id: staff.user_id,
          metadata: { booking_id: booking.id },
        });
        await recordBookingEvent(db, {
          booking_id: booking.id,
          event_type: "submitted",
          previous_status: null,
          new_status: "submitted",
          actor_user_id: staff.user_id,
          metadata: { source_enquiry_id: enquiryId, via: "convert_enquiry" },
        });

        return json(200, {
          status: "success",
          message:
            "Enquiry converted to booking request (not confirmed). Destiny must still quote and confirm.",
          data: { enquiry: updatedEnquiry, booking },
        });
      }

      default:
        return json(400, {
          status: "error",
          message: `Unknown action: ${action}`,
        });
    }
  } catch (e) {
    console.error("staff-commerce-api error", e);
    return json(500, {
      status: "error",
      message: (e as Error).message || "Internal error",
    });
  }
});
