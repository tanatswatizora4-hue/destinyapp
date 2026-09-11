/**
 * Deno tests for staff body spoof rejection (M3B.5).
 * Run: deno test supabase/functions/staff-commerce-api/lifecycle_rules_test.ts
 */
import {
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { assertStaffBodySafe } from "./lifecycle_rules.ts";

Deno.test("assertStaffBodySafe rejects user_id and role spoof", () => {
  assertThrows(() => assertStaffBodySafe({ user_id: "x", action: "staff_me" }));
  assertThrows(() => assertStaffBodySafe({ role: "admin" }));
  assertThrows(() => assertStaffBodySafe({ firebase_uid: "legacy" }));
  assertThrows(() => assertStaffBodySafe({ is_active: true }));
});
