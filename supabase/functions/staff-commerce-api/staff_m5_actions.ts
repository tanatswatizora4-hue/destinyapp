/**
 * M5 staff CRM / queue / dashboard / document actions.
 * Called from staff-commerce-api after requireStaff.
 */

import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import {
  isVerificationStatus,
  staffDocumentRow,
} from "../customer-api/document_rules.ts";
import {
  createDocumentSignedUrl,
  recordDocumentEvent,
} from "../customer-api/document_service.ts";
import {
  aggregateDashboardCounts,
  clampPage,
  clampPageSize,
  classifyFollowUp,
  filterEnquiriesForRole,
  optionalFollowUpAt,
  sanitizeNoteBody,
  sanitizeSearchQuery,
  staffCanViewCompanyWide,
} from "./ops_rules.ts";
import { canStaffTransitionEnquiry } from "./lifecycle_rules.ts";

export type StaffActor = {
  id: string;
  user_id: string;
  email: string;
  display_name: string;
  role: string;
  is_active: boolean;
};

async function recordOpsAudit(
  db: SupabaseClient,
  args: {
    actor_user_id: string;
    action: string;
    entity_type: string;
    entity_id?: string | null;
    metadata?: Record<string, unknown>;
  },
) {
  const { error } = await db.from("ops_audit_events").insert({
    actor_user_id: args.actor_user_id,
    actor_type: "staff",
    action: args.action,
    entity_type: args.entity_type,
    entity_id: args.entity_id ?? null,
    metadata: args.metadata ?? {},
  });
  if (error) throw error;
}

export async function handleStaffM5Action(
  db: SupabaseClient,
  staff: StaffActor,
  action: string,
  body: Record<string, unknown>,
): Promise<{ status: number; body: Record<string, unknown> } | null> {
  switch (action) {
    case "search_customers": {
      const q = sanitizeSearchQuery(body.query ?? body.q);
      const page = clampPage(body.page, 1);
      const pageSize = clampPageSize(body.page_size, 25, 50);
      const from = (page - 1) * pageSize;
      let query = db
        .from("customer_profiles")
        .select("id, user_id, full_name, email, phone, created_at, updated_at", {
          count: "exact",
        })
        .order("updated_at", { ascending: false })
        .range(from, from + pageSize - 1);
      if (q) {
        query = query.or(
          `full_name.ilike.%${q}%,email.ilike.%${q}%,phone.ilike.%${q}%`,
        );
      }
      const { data, error, count } = await query;
      if (error) throw error;
      return {
        status: 200,
        body: {
          status: "success",
          data: {
            items: data ?? [],
            page,
            page_size: pageSize,
            total: count ?? (data ?? []).length,
          },
        },
      };
    }

    case "get_customer_workspace": {
      const customerUserId = String(body.customer_user_id ?? "");
      if (!customerUserId) {
        return {
          status: 400,
          body: { status: "error", message: "customer_user_id required" },
        };
      }
      const { data: profile, error: pErr } = await db
        .from("customer_profiles")
        .select("*")
        .eq("user_id", customerUserId)
        .maybeSingle();
      if (pErr) throw pErr;
      if (!profile) {
        return {
          status: 404,
          body: { status: "error", message: "Customer not found" },
        };
      }

      const [enquiries, bookings, documents, notes, destina] = await Promise.all([
        db.from("enquiries").select(
          "id, kind, status, payload, assigned_staff_user_id, created_at, updated_at, next_follow_up_at, follow_up_note, follow_up_completed_at, converted_booking_id",
        ).eq("user_id", customerUserId).order("created_at", { ascending: false })
          .limit(50),
        db.from("bookings").select(
          "id, status, payment_status, item_name, item_type, quoted_total, currency, created_at, updated_at",
        ).eq("user_id", customerUserId).order("created_at", { ascending: false })
          .limit(50),
        db.from("customer_travel_documents").select("*")
          .eq("customer_user_id", customerUserId).is("archived_at", null)
          .order("created_at", { ascending: false }).limit(50),
        db.from("staff_customer_notes").select("*")
          .eq("customer_user_id", customerUserId).is("archived_at", null)
          .order("created_at", { ascending: false }).limit(50),
        db.from("destina_conversations").select(
          "id, status, trip_state, last_enquiry_id, last_handoff_at, updated_at",
        ).eq("user_id", customerUserId).order("updated_at", { ascending: false })
          .limit(10),
      ]);

      if (enquiries.error) throw enquiries.error;
      if (bookings.error) throw bookings.error;
      if (documents.error) throw documents.error;
      if (notes.error) throw notes.error;
      // Destina table may be missing in older environments — soft-fail.
      const destinaRows = destina.error ? [] : (destina.data ?? []);

      return {
        status: 200,
        body: {
          status: "success",
          data: {
            profile,
            enquiries: enquiries.data ?? [],
            bookings: bookings.data ?? [],
            documents: (documents.data ?? []).map((r) =>
              staffDocumentRow(r as Record<string, unknown>)
            ),
            notes: notes.data ?? [],
            destina_conversations: destinaRows.map((c) => ({
              id: c.id,
              status: c.status,
              trip_state: c.trip_state,
              last_enquiry_id: c.last_enquiry_id,
              last_handoff_at: c.last_handoff_at,
              updated_at: c.updated_at,
            })),
          },
        },
      };
    }

    case "add_customer_note": {
      const customerUserId = String(body.customer_user_id ?? "");
      if (!customerUserId) {
        return {
          status: 400,
          body: { status: "error", message: "customer_user_id required" },
        };
      }
      let noteBody: string;
      try {
        noteBody = sanitizeNoteBody(body.body ?? body.note);
      } catch (e) {
        return {
          status: 400,
          body: { status: "error", message: (e as Error).message },
        };
      }
      // Author is always the authenticated staff member — never client-spoofed.
      const { data, error } = await db.from("staff_customer_notes").insert({
        customer_user_id: customerUserId,
        author_staff_user_id: staff.user_id,
        author_staff_row_id: staff.id,
        body: noteBody,
      }).select("*").single();
      if (error) throw error;
      await recordOpsAudit(db, {
        actor_user_id: staff.user_id,
        action: "customer_note_created",
        entity_type: "staff_customer_note",
        entity_id: data.id,
        metadata: { customer_user_id: customerUserId },
      });
      return { status: 200, body: { status: "success", data } };
    }

    case "work_queue": {
      const statusFilter = body.status ? String(body.status) : null;
      const assignedFilter = body.assigned == null
        ? null
        : String(body.assigned);
      const page = clampPage(body.page, 1);
      const pageSize = clampPageSize(body.page_size, 40, 50);
      const from = (page - 1) * pageSize;

      let q = db.from("enquiries").select("*").order("updated_at", {
        ascending: false,
      }).range(from, from + pageSize - 1);
      if (statusFilter) q = q.eq("status", statusFilter);
      if (assignedFilter === "me") {
        q = q.eq("assigned_staff_user_id", staff.user_id);
      } else if (assignedFilter === "unassigned") {
        q = q.is("assigned_staff_user_id", null);
      } else if (
        assignedFilter && assignedFilter !== "all" &&
        staffCanViewCompanyWide(staff.role)
      ) {
        q = q.eq("assigned_staff_user_id", assignedFilter);
      }

      const { data, error } = await q;
      if (error) throw error;
      let rows = (data ?? []) as Array<Record<string, unknown>>;
      if (!staffCanViewCompanyWide(staff.role) && assignedFilter !== "me") {
        rows = filterEnquiriesForRole(
          rows.map((r) => ({
            ...r,
            assigned_staff_user_id:
              (r.assigned_staff_user_id as string | null) ?? null,
          })),
          staff.role,
          staff.user_id,
        );
      }
      const now = new Date();
      const items = rows.map((r) => ({
        ...r,
        follow_up_state: classifyFollowUp({
          next_follow_up_at: (r.next_follow_up_at as string | null) ?? null,
          follow_up_completed_at:
            (r.follow_up_completed_at as string | null) ?? null,
          status: String(r.status),
        }, now),
      }));
      return {
        status: 200,
        body: {
          status: "success",
          data: { items, page, page_size: pageSize },
        },
      };
    }

    case "assign_enquiry": {
      const enquiryId = String(body.enquiry_id ?? "");
      if (!enquiryId) {
        return {
          status: 400,
          body: { status: "error", message: "enquiry_id required" },
        };
      }
      const assignTo = body.assign_to_staff_user_id == null
        ? staff.user_id
        : String(body.assign_to_staff_user_id);
      if (
        assignTo !== staff.user_id && !staffCanViewCompanyWide(staff.role)
      ) {
        return {
          status: 403,
          body: {
            status: "error",
            message: "Only managers/admins can assign to other staff",
          },
        };
      }
      if (assignTo) {
        const { data: target } = await db.from("staff_users").select(
          "user_id, is_active",
        ).eq("user_id", assignTo).maybeSingle();
        if (!target || !target.is_active) {
          return {
            status: 400,
            body: { status: "error", message: "Assignment target is not active staff" },
          };
        }
      }
      const { data: existing, error: findErr } = await db.from("enquiries")
        .select("id, status, assigned_staff_user_id").eq("id", enquiryId)
        .maybeSingle();
      if (findErr) throw findErr;
      if (!existing) {
        return {
          status: 404,
          body: { status: "error", message: "Enquiry not found" },
        };
      }
      const patch: Record<string, unknown> = {
        assigned_staff_user_id: assignTo,
      };
      // Auto-move new enquiries into review when first assigned.
      if (
        existing.status === "received" &&
        canStaffTransitionEnquiry("received", "in_review")
      ) {
        patch.status = "in_review";
      }
      const { data, error } = await db.from("enquiries").update(patch).eq(
        "id",
        enquiryId,
      ).select("*").single();
      if (error) throw error;
      await db.from("enquiry_events").insert({
        enquiry_id: enquiryId,
        event_type: "assigned",
        previous_status: existing.status,
        new_status: data.status,
        actor_type: "staff",
        actor_user_id: staff.user_id,
        metadata: {
          from: existing.assigned_staff_user_id,
          to: assignTo,
        },
      });
      await recordOpsAudit(db, {
        actor_user_id: staff.user_id,
        action: "enquiry_assigned",
        entity_type: "enquiry",
        entity_id: enquiryId,
        metadata: { assign_to_staff_user_id: assignTo },
      });
      return { status: 200, body: { status: "success", data } };
    }

    case "set_enquiry_follow_up": {
      const enquiryId = String(body.enquiry_id ?? "");
      if (!enquiryId) {
        return {
          status: 400,
          body: { status: "error", message: "enquiry_id required" },
        };
      }
      let nextAt: string | null;
      try {
        nextAt = optionalFollowUpAt(body.next_follow_up_at);
      } catch (e) {
        return {
          status: 400,
          body: { status: "error", message: (e as Error).message },
        };
      }
      const note = String(body.follow_up_note ?? "").trim().slice(0, 1000);
      const complete = body.complete === true;
      const patch: Record<string, unknown> = {
        next_follow_up_at: nextAt,
        follow_up_note: note,
      };
      if (complete) {
        patch.follow_up_completed_at = new Date().toISOString();
      } else if (body.clear_completed === true) {
        patch.follow_up_completed_at = null;
      }
      const { data, error } = await db.from("enquiries").update(patch).eq(
        "id",
        enquiryId,
      ).select("*").single();
      if (error) throw error;
      await recordOpsAudit(db, {
        actor_user_id: staff.user_id,
        action: complete ? "follow_up_completed" : "follow_up_set",
        entity_type: "enquiry",
        entity_id: enquiryId,
      });
      return { status: 200, body: { status: "success", data } };
    }

    case "ops_dashboard": {
      const { data, error } = await db.from("enquiries").select(
        "status, assigned_staff_user_id, next_follow_up_at, follow_up_completed_at, updated_at, kind, id",
      ).order("updated_at", { ascending: false }).limit(500);
      if (error) throw error;
      let rows = (data ?? []) as Array<{
        status: string;
        assigned_staff_user_id: string | null;
        next_follow_up_at: string | null;
        follow_up_completed_at: string | null;
        updated_at: string;
        kind: string;
        id: string;
      }>;
      if (!staffCanViewCompanyWide(staff.role)) {
        rows = filterEnquiriesForRole(rows, staff.role, staff.user_id);
      }
      const now = new Date();
      const counts = aggregateDashboardCounts(rows, now);
      const attention = rows
        .map((r) => ({
          ...r,
          follow_up_state: classifyFollowUp(r, now),
        }))
        .filter((r) =>
          r.status === "received" ||
          r.assigned_staff_user_id == null ||
          r.follow_up_state === "due" ||
          r.follow_up_state === "overdue"
        )
        .slice(0, 25);

      const { data: recentBookings } = await db.from("bookings").select(
        "id, status, payment_status, item_name, created_at",
      ).order("created_at", { ascending: false }).limit(10);

      const { data: recentAudit } = await db.from("ops_audit_events").select(
        "id, action, entity_type, entity_id, created_at, actor_user_id",
      ).order("created_at", { ascending: false }).limit(20);

      return {
        status: 200,
        body: {
          status: "success",
          data: {
            counts,
            attention,
            recent_bookings: recentBookings ?? [],
            recent_activity: recentAudit ?? [],
            scope: staffCanViewCompanyWide(staff.role) ? "company" : "mine",
          },
        },
      };
    }

    case "list_customer_documents": {
      const customerUserId = String(body.customer_user_id ?? "");
      if (!customerUserId) {
        return {
          status: 400,
          body: { status: "error", message: "customer_user_id required" },
        };
      }
      const { data, error } = await db.from("customer_travel_documents")
        .select("*").eq("customer_user_id", customerUserId)
        .is("archived_at", null).order("created_at", { ascending: false })
        .limit(100);
      if (error) throw error;
      return {
        status: 200,
        body: {
          status: "success",
          data: (data ?? []).map((r) =>
            staffDocumentRow(r as Record<string, unknown>)
          ),
        },
      };
    }

    case "get_customer_document_url": {
      const documentId = String(body.document_id ?? "");
      if (!documentId) {
        return {
          status: 400,
          body: { status: "error", message: "document_id required" },
        };
      }
      try {
        const signed = await createDocumentSignedUrl(db, {
          documentId,
          actorUserId: staff.user_id,
          actorType: "staff",
        });
        await recordOpsAudit(db, {
          actor_user_id: staff.user_id,
          action: "document_signed_url_issued",
          entity_type: "customer_travel_document",
          entity_id: documentId,
        });
        return {
          status: 200,
          body: {
            status: "success",
            data: {
              signed_url: signed.signed_url,
              expires_in: signed.expires_in,
              document: signed.document,
              public_url: null,
            },
          },
        };
      } catch (e) {
        const status = (e as { status?: number }).status ?? 500;
        return {
          status,
          body: {
            status: "error",
            message: status === 404
              ? "Document not found"
              : (e as Error).message,
          },
        };
      }
    }

    case "verify_customer_document": {
      const documentId = String(body.document_id ?? "");
      const verificationStatus = String(body.verification_status ?? "");
      if (!documentId || !isVerificationStatus(verificationStatus)) {
        return {
          status: 400,
          body: {
            status: "error",
            message: "document_id and valid verification_status required",
          },
        };
      }
      if (
        verificationStatus === "verified" &&
        !staffCanViewCompanyWide(staff.role) &&
        staff.role !== "consultant"
      ) {
        // consultants/managers/admins may verify; inactive already blocked
      }
      const note = String(body.verification_note ?? "").trim().slice(0, 1000);
      const { data, error } = await db.from("customer_travel_documents").update({
        verification_status: verificationStatus,
        verification_note: note,
        verified_at: verificationStatus === "verified" ||
            verificationStatus === "rejected"
          ? new Date().toISOString()
          : null,
        verified_by_user_id: staff.user_id,
      }).eq("id", documentId).is("archived_at", null).select("*").maybeSingle();
      if (error) throw error;
      if (!data) {
        return {
          status: 404,
          body: { status: "error", message: "Document not found" },
        };
      }
      await recordDocumentEvent(db, {
        document_id: documentId,
        event_type: `verification_${verificationStatus}`,
        actor_type: "staff",
        actor_user_id: staff.user_id,
      });
      await recordOpsAudit(db, {
        actor_user_id: staff.user_id,
        action: "document_verified",
        entity_type: "customer_travel_document",
        entity_id: documentId,
        metadata: { verification_status: verificationStatus },
      });
      return {
        status: 200,
        body: {
          status: "success",
          data: staffDocumentRow(data as Record<string, unknown>),
        },
      };
    }

    default:
      return null;
  }
}
