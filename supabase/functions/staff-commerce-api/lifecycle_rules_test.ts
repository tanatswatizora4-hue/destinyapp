/**
 * Deno tests for M3B lifecycle_rules.
 * Run: deno test supabase/functions/staff-commerce-api/lifecycle_rules_test.ts
 */
import {
  assertEquals,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  canCustomerCancel,
  canStaffTransitionBooking,
  canStaffTransitionEnquiry,
  sanitizeQuoteInput,
} from "./lifecycle_rules.ts";

Deno.test("staff booking transitions", () => {
  assertEquals(canStaffTransitionBooking("submitted", "quoted"), true);
  assertEquals(canStaffTransitionBooking("submitted", "confirmed"), false);
  assertEquals(canStaffTransitionBooking("quoted", "awaiting_payment"), true);
  assertEquals(canStaffTransitionBooking("awaiting_payment", "confirmed"), true);
  assertEquals(canStaffTransitionBooking("confirmed", "completed"), true);
  assertEquals(canStaffTransitionBooking("cancelled", "submitted"), false);
  assertEquals(canStaffTransitionBooking("completed", "cancelled"), false);
});

Deno.test("customer cancel narrower than staff", () => {
  assertEquals(canCustomerCancel("submitted"), true);
  assertEquals(canCustomerCancel("confirmed"), false);
  assertEquals(canStaffTransitionBooking("confirmed", "cancelled"), true);
});

Deno.test("enquiry transitions", () => {
  assertEquals(canStaffTransitionEnquiry("received", "in_review"), true);
  assertEquals(canStaffTransitionEnquiry("in_review", "quoted"), true);
  assertEquals(canStaffTransitionEnquiry("quoted", "converted"), true);
  assertEquals(canStaffTransitionEnquiry("converted", "closed"), false);
  assertEquals(canStaffTransitionEnquiry("received", "converted"), false);
});

Deno.test("sanitizeQuoteInput rejects paid spoof and negative", () => {
  assertThrows(() => sanitizeQuoteInput({ quoted_total: -1 }));
  assertThrows(() =>
    sanitizeQuoteInput({ quoted_total: 10, payment_status: "paid" })
  );
  const ok = sanitizeQuoteInput({
    quoted_total: 199.999,
    currency: "USD",
    customer_quote_note: "Includes transfers",
  });
  assertEquals(ok.quoted_total, 200);
  assertEquals(ok.customer_quote_note, "Includes transfers");
});
