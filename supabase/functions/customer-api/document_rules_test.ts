/**
 * M5A document rules tests — no network, no Supabase.
 */

import {
  assertEquals,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  DocumentValidationError,
  TRAVEL_DOCUMENT_BUCKET,
  TRAVEL_DOCUMENT_MAX_BYTES,
  assertOwnedStoragePath,
  buildTravelDocumentStoragePath,
  publicDocumentRow,
  sanitizeCreateTravelDocument,
} from "./document_rules.ts";

const USER = "11111111-1111-4111-8111-111111111111";
const DOC = "22222222-2222-4222-8222-222222222222";

Deno.test("rejects invalid document type", () => {
  assertThrows(
    () =>
      sanitizeCreateTravelDocument({
        document_type: "driver_license",
        mime_type: "image/jpeg",
        file_size: 100,
      }),
    DocumentValidationError,
    "Unsupported travel document type",
  );
});

Deno.test("rejects invalid MIME", () => {
  assertThrows(
    () =>
      sanitizeCreateTravelDocument({
        document_type: "passport",
        mime_type: "application/zip",
        file_size: 100,
      }),
    DocumentValidationError,
    "Unsupported file type",
  );
});

Deno.test("rejects oversized upload", () => {
  assertThrows(
    () =>
      sanitizeCreateTravelDocument({
        document_type: "passport",
        mime_type: "application/pdf",
        file_size: TRAVEL_DOCUMENT_MAX_BYTES + 1,
      }),
    DocumentValidationError,
    "10 MB",
  );
});

Deno.test("rejects client-supplied bucket/path/ownership", () => {
  assertThrows(
    () =>
      sanitizeCreateTravelDocument({
        document_type: "visa",
        mime_type: "image/png",
        file_size: 50,
        storage_path: "evil/path.pdf",
      }),
    DocumentValidationError,
    "Client may not set",
  );
  assertThrows(
    () =>
      sanitizeCreateTravelDocument({
        document_type: "visa",
        mime_type: "image/png",
        file_size: 50,
        storage_bucket: "destiny-media",
      }),
    DocumentValidationError,
    "Client may not set",
  );
  assertThrows(
    () =>
      sanitizeCreateTravelDocument({
        document_type: "visa",
        mime_type: "image/png",
        file_size: 50,
        customer_user_id: USER,
      }),
    DocumentValidationError,
    "Client may not set",
  );
});

Deno.test("builds customer-scoped unpredictable path", () => {
  const path = buildTravelDocumentStoragePath({
    customerUserId: USER,
    documentId: DOC,
    mime: "application/pdf",
    objectToken: "tok_abc",
  });
  assertEquals(path.startsWith(`${USER}/${DOC}/`), true);
  assertEquals(path.endsWith(".pdf"), true);
  assertEquals(path.includes(".."), false);
  assertEquals(TRAVEL_DOCUMENT_BUCKET, "customer-travel-documents");
});

Deno.test("owned path check rejects traversal and foreign prefixes", () => {
  const good = buildTravelDocumentStoragePath({
    customerUserId: USER,
    documentId: DOC,
    mime: "image/jpeg",
    objectToken: "x",
  });
  assertOwnedStoragePath(good, USER, DOC);
  assertThrows(
    () => assertOwnedStoragePath(`${USER}/../other/x.jpg`, USER, DOC),
    DocumentValidationError,
  );
  assertThrows(
    () =>
      assertOwnedStoragePath(
        `33333333-3333-4333-8333-333333333333/${DOC}/x.jpg`,
        USER,
        DOC,
      ),
    DocumentValidationError,
  );
});

Deno.test("public document row never includes storage_path", () => {
  const pub = publicDocumentRow({
    id: DOC,
    document_type: "passport",
    display_name: "My passport",
    mime_type: "image/jpeg",
    file_size: 12,
    storage_path: `${USER}/${DOC}/secret.jpg`,
    storage_bucket: "customer-travel-documents",
    verification_status: "unverified",
    upload_status: "ready",
    created_at: "2026-01-01T00:00:00Z",
    updated_at: "2026-01-01T00:00:00Z",
  });
  assertEquals("storage_path" in pub, false);
  assertEquals("storage_bucket" in pub, false);
  assertEquals(JSON.stringify(pub).includes("secret.jpg"), false);
});

Deno.test("accepts valid passport create payload", () => {
  const out = sanitizeCreateTravelDocument({
    document_type: "passport",
    mime_type: "image/jpeg",
    file_size: 2048,
    display_name: "Primary passport",
    issuing_country: "zw",
    expiry_date: "2030-05-01",
  });
  assertEquals(out.document_type, "passport");
  assertEquals(out.issuing_country, "ZW");
  assertEquals(out.expiry_date, "2030-05-01");
});
