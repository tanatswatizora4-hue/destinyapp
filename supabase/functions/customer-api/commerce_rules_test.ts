/**
 * Deno tests for M3A commerce_rules (no network / secrets).
 * Run: deno test supabase/functions/customer-api/commerce_rules_test.ts
 */

import {
  assertEquals,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  assertNoAuthoritativeClientFields,
  canCustomerCancel,
  sanitizeBookingCreateInput,
  sanitizeFlightEnquiryPayload,
} from "./commerce_rules.ts";

Deno.test("canCustomerCancel allows early lifecycle only", () => {
  assertEquals(canCustomerCancel("submitted"), true);
  assertEquals(canCustomerCancel("quoted"), true);
  assertEquals(canCustomerCancel("confirmed"), false);
  assertEquals(canCustomerCancel("completed"), false);
  assertEquals(canCustomerCancel("cancelled"), false);
});

Deno.test("sanitizeBookingCreateInput rejects client authority fields via assert", () => {
  assertThrows(() =>
    assertNoAuthoritativeClientFields({ quoted_total: 99, action: "x" })
  );
  assertThrows(() =>
    assertNoAuthoritativeClientFields({ firebase_uid: "evil" })
  );
  assertThrows(() => assertNoAuthoritativeClientFields({ status: "confirmed" }));
  assertThrows(() =>
    assertNoAuthoritativeClientFields({ payment_status: "paid" })
  );
  assertThrows(() => assertNoAuthoritativeClientFields({ total_price: 1 }));
});

Deno.test("sanitizeBookingCreateInput maps stay→accommodation and keeps estimate only", () => {
  const out = sanitizeBookingCreateInput({
    item_type: "stay",
    item_legacy_id: 3,
    item_name: "Lodge",
    num_travelers: 2,
    requested_estimate: 150.555,
    currency: "USD",
    start_date: "2026-10-01",
    end_date: "2026-10-03",
  });
  assertEquals(out.item_type, "accommodation");
  assertEquals(out.requested_total, 150.56);
  assertEquals(out.item_legacy_id, 3);
});

Deno.test("sanitizeFlightEnquiryPayload strips price-like extras by omission", () => {
  const out = sanitizeFlightEnquiryPayload({
    origin: "HRE",
    destination: "JNB",
    mid_places: ["VFA"],
    num_travelers: 2,
    total_price: 9999,
    firebase_uid: "nope",
  });
  assertEquals(out.origin, "HRE");
  assertEquals(out.destination, "JNB");
  assertEquals("total_price" in out, false);
  assertEquals("firebase_uid" in out, false);
});
