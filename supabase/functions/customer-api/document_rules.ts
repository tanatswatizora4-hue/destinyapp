/**
 * M5A private travel-document rules — pure, deterministic, unit-testable.
 * Never invents storage paths from client input.
 */

export const TRAVEL_DOCUMENT_BUCKET = "customer-travel-documents";

export const TRAVEL_DOCUMENT_TYPES = [
  "passport",
  "visa",
  "national_id",
  "residence_permit",
  "vaccination_certificate",
  "other",
] as const;

export type TravelDocumentType = (typeof TRAVEL_DOCUMENT_TYPES)[number];

export const TRAVEL_DOCUMENT_MIME_TYPES = [
  "image/jpeg",
  "image/png",
  "image/webp",
  "application/pdf",
] as const;

export type TravelDocumentMime = (typeof TRAVEL_DOCUMENT_MIME_TYPES)[number];

export const TRAVEL_DOCUMENT_MAX_BYTES = 10 * 1024 * 1024; // 10 MiB

export const TRAVEL_DOCUMENT_SIGNED_URL_SECONDS = 120;

export const VERIFICATION_STATUSES = [
  "unverified",
  "pending_review",
  "verified",
  "rejected",
] as const;

export type VerificationStatus = (typeof VERIFICATION_STATUSES)[number];

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export class DocumentValidationError extends Error {
  constructor(
    public readonly code: string,
    message: string,
  ) {
    super(message);
    this.name = "DocumentValidationError";
  }
}

export function isUuid(v: unknown): boolean {
  return typeof v === "string" && UUID_RE.test(v);
}

export function assertUuid(v: unknown, label = "id"): string {
  if (!isUuid(v)) {
    throw new DocumentValidationError("invalid_uuid", `Invalid ${label}`);
  }
  return String(v);
}

export function isTravelDocumentType(v: unknown): v is TravelDocumentType {
  return (TRAVEL_DOCUMENT_TYPES as readonly string[]).includes(String(v));
}

export function isTravelDocumentMime(v: unknown): v is TravelDocumentMime {
  return (TRAVEL_DOCUMENT_MIME_TYPES as readonly string[]).includes(String(v));
}

export function isVerificationStatus(v: unknown): v is VerificationStatus {
  return (VERIFICATION_STATUSES as readonly string[]).includes(String(v));
}

export function extensionForMime(mime: TravelDocumentMime): string {
  switch (mime) {
    case "image/jpeg":
      return "jpg";
    case "image/png":
      return "png";
    case "image/webp":
      return "webp";
    case "application/pdf":
      return "pdf";
  }
}

/** Server-owned path: never accept client-supplied bucket/path. */
export function buildTravelDocumentStoragePath(input: {
  customerUserId: string;
  documentId: string;
  mime: TravelDocumentMime;
  objectToken?: string;
}): string {
  const userId = assertUuid(input.customerUserId, "customer_user_id");
  const documentId = assertUuid(input.documentId, "document_id");
  const token = (input.objectToken ?? crypto.randomUUID()).replace(/[^a-zA-Z0-9_-]/g, "");
  const ext = extensionForMime(input.mime);
  return `${userId}/${documentId}/${token}.${ext}`;
}

export function assertOwnedStoragePath(
  path: string,
  customerUserId: string,
  documentId: string,
): void {
  const userId = assertUuid(customerUserId, "customer_user_id");
  const docId = assertUuid(documentId, "document_id");
  if (path.includes("..") || path.includes("\\") || path.startsWith("/")) {
    throw new DocumentValidationError("invalid_path", "Invalid storage path");
  }
  const prefix = `${userId}/${docId}/`;
  if (!path.startsWith(prefix)) {
    throw new DocumentValidationError("path_mismatch", "Storage path ownership mismatch");
  }
  if (path.includes("//") || /[^a-zA-Z0-9_./-]/.test(path)) {
    throw new DocumentValidationError("invalid_path", "Invalid storage path characters");
  }
}

export function sanitizeDisplayName(raw: unknown, fallback: string): string {
  const s = String(raw ?? "").trim().slice(0, 120);
  return s || fallback.slice(0, 120);
}

export function optionalIsoDate(raw: unknown, label: string): string | null {
  if (raw == null || raw === "") return null;
  const s = String(raw).trim().slice(0, 10);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(s)) {
    throw new DocumentValidationError("invalid_date", `Invalid ${label}`);
  }
  const d = new Date(`${s}T00:00:00Z`);
  if (Number.isNaN(d.getTime())) {
    throw new DocumentValidationError("invalid_date", `Invalid ${label}`);
  }
  return s;
}

export function optionalCountry(raw: unknown): string | null {
  if (raw == null || raw === "") return null;
  const s = String(raw).trim().toUpperCase().replace(/[^A-Z]/g, "").slice(0, 3);
  if (s.length !== 2 && s.length !== 3) {
    throw new DocumentValidationError(
      "invalid_country",
      "Issuing country must be a 2–3 letter code",
    );
  }
  return s;
}

export type CreateTravelDocumentInput = {
  document_type: TravelDocumentType;
  display_name: string;
  mime_type: TravelDocumentMime;
  file_size: number;
  issuing_country: string | null;
  issue_date: string | null;
  expiry_date: string | null;
};

export function sanitizeCreateTravelDocument(
  body: Record<string, unknown>,
): CreateTravelDocumentInput {
  if (!isTravelDocumentType(body.document_type)) {
    throw new DocumentValidationError(
      "invalid_document_type",
      "Unsupported travel document type",
    );
  }
  if (!isTravelDocumentMime(body.mime_type)) {
    throw new DocumentValidationError(
      "invalid_mime",
      "Unsupported file type. Use JPEG, PNG, WebP, or PDF.",
    );
  }
  const fileSize = Number(body.file_size);
  if (!Number.isFinite(fileSize) || !Number.isInteger(fileSize) || fileSize <= 0) {
    throw new DocumentValidationError("invalid_file_size", "file_size must be a positive integer");
  }
  if (fileSize > TRAVEL_DOCUMENT_MAX_BYTES) {
    throw new DocumentValidationError(
      "file_too_large",
      "File exceeds the 10 MB limit",
    );
  }
  // Reject client attempts to choose storage location.
  if (
    Object.prototype.hasOwnProperty.call(body, "storage_path") ||
    Object.prototype.hasOwnProperty.call(body, "storage_bucket") ||
    Object.prototype.hasOwnProperty.call(body, "customer_user_id") ||
    Object.prototype.hasOwnProperty.call(body, "user_id") ||
    Object.prototype.hasOwnProperty.call(body, "bucket")
  ) {
    throw new DocumentValidationError(
      "forbidden_field",
      "Client may not set storage path, bucket, or ownership fields",
    );
  }

  const type = body.document_type;
  return {
    document_type: type,
    display_name: sanitizeDisplayName(
      body.display_name,
      type.replace(/_/g, " "),
    ),
    mime_type: body.mime_type,
    file_size: fileSize,
    issuing_country: optionalCountry(body.issuing_country),
    issue_date: optionalIsoDate(body.issue_date, "issue_date"),
    expiry_date: optionalIsoDate(body.expiry_date, "expiry_date"),
  };
}

export function publicDocumentRow(row: Record<string, unknown>): Record<string, unknown> {
  return {
    id: row.id,
    document_type: row.document_type,
    display_name: row.display_name,
    mime_type: row.mime_type,
    file_size: row.file_size,
    issuing_country: row.issuing_country ?? null,
    issue_date: row.issue_date ?? null,
    expiry_date: row.expiry_date ?? null,
    verification_status: row.verification_status,
    upload_status: row.upload_status,
    created_at: row.created_at,
    updated_at: row.updated_at,
    verified_at: row.verified_at ?? null,
    // Never expose storage_path/bucket to customers in list payloads unnecessarily —
    // staff may see bucket name only; path stays server-side for signing.
  };
}

export function staffDocumentRow(row: Record<string, unknown>): Record<string, unknown> {
  return {
    ...publicDocumentRow(row),
    customer_user_id: row.customer_user_id,
    verification_note: row.verification_note ?? "",
    verified_by_user_id: row.verified_by_user_id ?? null,
    storage_bucket: TRAVEL_DOCUMENT_BUCKET,
  };
}
