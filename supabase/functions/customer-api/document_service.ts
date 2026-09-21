/**
 * Shared helpers for private travel-document Edge actions.
 */

import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import {
  CreateTravelDocumentInput,
  TRAVEL_DOCUMENT_BUCKET,
  TRAVEL_DOCUMENT_SIGNED_URL_SECONDS,
  assertUuid,
  buildTravelDocumentStoragePath,
  publicDocumentRow,
  staffDocumentRow,
} from "./document_rules.ts";

export async function recordDocumentEvent(
  db: SupabaseClient,
  args: {
    document_id: string;
    event_type: string;
    actor_type: "customer" | "staff" | "system";
    actor_user_id: string | null;
    metadata?: Record<string, unknown>;
  },
) {
  const { error } = await db.from("customer_travel_document_events").insert({
    document_id: args.document_id,
    event_type: args.event_type,
    actor_type: args.actor_type,
    actor_user_id: args.actor_user_id,
    metadata: args.metadata ?? {},
  });
  if (error) throw error;
}

export async function createPendingTravelDocument(
  db: SupabaseClient,
  customerUserId: string,
  input: CreateTravelDocumentInput,
): Promise<{
  row: Record<string, unknown>;
  storage_path: string;
  upload: { signedUrl: string; token: string; path: string } | null;
}> {
  const documentId = crypto.randomUUID();
  const storagePath = buildTravelDocumentStoragePath({
    customerUserId,
    documentId,
    mime: input.mime_type,
  });

  const { data, error } = await db
    .from("customer_travel_documents")
    .insert({
      id: documentId,
      customer_user_id: customerUserId,
      document_type: input.document_type,
      display_name: input.display_name,
      storage_bucket: TRAVEL_DOCUMENT_BUCKET,
      storage_path: storagePath,
      mime_type: input.mime_type,
      file_size: input.file_size,
      issuing_country: input.issuing_country,
      issue_date: input.issue_date,
      expiry_date: input.expiry_date,
      upload_status: "pending",
      verification_status: "unverified",
    })
    .select("*")
    .single();
  if (error) throw error;

  const signed = await db.storage
    .from(TRAVEL_DOCUMENT_BUCKET)
    .createSignedUploadUrl(storagePath);

  if (signed.error) {
    await db.from("customer_travel_documents").update({
      upload_status: "failed",
    }).eq("id", documentId);
    throw signed.error;
  }

  await recordDocumentEvent(db, {
    document_id: documentId,
    event_type: "upload_created",
    actor_type: "customer",
    actor_user_id: customerUserId,
    metadata: {
      document_type: input.document_type,
      mime_type: input.mime_type,
      file_size: input.file_size,
    },
  });

  return {
    row: data as Record<string, unknown>,
    storage_path: storagePath,
    upload: {
      signedUrl: signed.data.signedUrl,
      token: signed.data.token,
      path: signed.data.path,
    },
  };
}

export async function finalizeTravelDocument(
  db: SupabaseClient,
  customerUserId: string,
  documentId: string,
): Promise<Record<string, unknown>> {
  assertUuid(documentId, "document_id");
  const { data: row, error } = await db
    .from("customer_travel_documents")
    .select("*")
    .eq("id", documentId)
    .eq("customer_user_id", customerUserId)
    .is("archived_at", null)
    .maybeSingle();
  if (error) throw error;
  if (!row) {
    throw Object.assign(new Error("Document not found"), { status: 404 });
  }

  const { data: updated, error: upErr } = await db
    .from("customer_travel_documents")
    .update({ upload_status: "ready" })
    .eq("id", documentId)
    .eq("customer_user_id", customerUserId)
    .select("*")
    .single();
  if (upErr) throw upErr;

  await recordDocumentEvent(db, {
    document_id: documentId,
    event_type: "upload_finalized",
    actor_type: "customer",
    actor_user_id: customerUserId,
  });

  return updated as Record<string, unknown>;
}

export async function listTravelDocumentsForCustomer(
  db: SupabaseClient,
  customerUserId: string,
): Promise<Record<string, unknown>[]> {
  const { data, error } = await db
    .from("customer_travel_documents")
    .select("*")
    .eq("customer_user_id", customerUserId)
    .is("archived_at", null)
    .order("created_at", { ascending: false })
    .limit(100);
  if (error) throw error;
  return (data ?? []).map((r) => publicDocumentRow(r as Record<string, unknown>));
}

export async function createDocumentSignedUrl(
  db: SupabaseClient,
  args: {
    documentId: string;
    actorUserId: string;
    actorType: "customer" | "staff";
    requireOwnerUserId?: string;
  },
): Promise<{ signed_url: string; expires_in: number; document: Record<string, unknown> }> {
  assertUuid(args.documentId, "document_id");
  let q = db
    .from("customer_travel_documents")
    .select("*")
    .eq("id", args.documentId)
    .is("archived_at", null);
  if (args.requireOwnerUserId) {
    q = q.eq("customer_user_id", args.requireOwnerUserId);
  }
  const { data: row, error } = await q.maybeSingle();
  if (error) throw error;
  if (!row) {
    throw Object.assign(new Error("Document not found"), { status: 404 });
  }
  if (row.upload_status !== "ready") {
    throw Object.assign(new Error("Document is not ready to view"), { status: 409 });
  }

  const signed = await db.storage
    .from(TRAVEL_DOCUMENT_BUCKET)
    .createSignedUrl(
      String(row.storage_path),
      TRAVEL_DOCUMENT_SIGNED_URL_SECONDS,
    );
  if (signed.error || !signed.data?.signedUrl) {
    throw signed.error ?? new Error("Could not create signed URL");
  }

  await recordDocumentEvent(db, {
    document_id: args.documentId,
    event_type: "signed_url_issued",
    actor_type: args.actorType,
    actor_user_id: args.actorUserId,
    metadata: { expires_in: TRAVEL_DOCUMENT_SIGNED_URL_SECONDS },
  });

  const doc = args.actorType === "staff"
    ? staffDocumentRow(row as Record<string, unknown>)
    : publicDocumentRow(row as Record<string, unknown>);

  return {
    signed_url: signed.data.signedUrl,
    expires_in: TRAVEL_DOCUMENT_SIGNED_URL_SECONDS,
    document: doc,
  };
}

export async function archiveTravelDocument(
  db: SupabaseClient,
  customerUserId: string,
  documentId: string,
): Promise<void> {
  assertUuid(documentId, "document_id");
  const { data: row, error } = await db
    .from("customer_travel_documents")
    .select("*")
    .eq("id", documentId)
    .eq("customer_user_id", customerUserId)
    .is("archived_at", null)
    .maybeSingle();
  if (error) throw error;
  if (!row) {
    throw Object.assign(new Error("Document not found"), { status: 404 });
  }

  const { error: upErr } = await db
    .from("customer_travel_documents")
    .update({ archived_at: new Date().toISOString() })
    .eq("id", documentId)
    .eq("customer_user_id", customerUserId);
  if (upErr) throw upErr;

  // Best-effort storage delete; metadata archive is authoritative if object gone.
  await db.storage.from(TRAVEL_DOCUMENT_BUCKET).remove([String(row.storage_path)]);

  await recordDocumentEvent(db, {
    document_id: documentId,
    event_type: "archived",
    actor_type: "customer",
    actor_user_id: customerUserId,
  });
}
