/**
 * M5 ops rules tests — no network.
 */

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { canStaffTransitionEnquiry } from "./lifecycle_rules.ts";
import {
  aggregateDashboardCounts,
  classifyFollowUp,
  filterEnquiriesForRole,
  sanitizeNoteBody,
  sanitizeSearchQuery,
} from "./ops_rules.ts";

Deno.test("expanded enquiry transitions remain safe", () => {
  assertEquals(canStaffTransitionEnquiry("received", "contacted"), true);
  assertEquals(canStaffTransitionEnquiry("quoted", "awaiting_customer"), true);
  assertEquals(canStaffTransitionEnquiry("awaiting_customer", "converted"), true);
  assertEquals(canStaffTransitionEnquiry("received", "converted"), false);
  assertEquals(canStaffTransitionEnquiry("cancelled", "received"), false);
});

Deno.test("follow-up overdue/due/upcoming are deterministic", () => {
  const now = new Date("2026-09-21T15:00:00Z");
  assertEquals(
    classifyFollowUp({
      next_follow_up_at: "2026-09-20T10:00:00Z",
      follow_up_completed_at: null,
      status: "in_review",
    }, now),
    "overdue",
  );
  assertEquals(
    classifyFollowUp({
      next_follow_up_at: "2026-09-21T18:00:00Z",
      follow_up_completed_at: null,
      status: "quoted",
    }, now),
    "due",
  );
  assertEquals(
    classifyFollowUp({
      next_follow_up_at: "2026-09-22T10:00:00Z",
      follow_up_completed_at: null,
      status: "quoted",
    }, now),
    "upcoming",
  );
  assertEquals(
    classifyFollowUp({
      next_follow_up_at: "2026-09-20T10:00:00Z",
      follow_up_completed_at: "2026-09-20T12:00:00Z",
      status: "quoted",
    }, now),
    "done",
  );
});

Deno.test("dashboard aggregates ignore closed/cancelled and count attention", () => {
  const now = new Date("2026-09-21T12:00:00Z");
  const counts = aggregateDashboardCounts([
    {
      status: "received",
      assigned_staff_user_id: null,
      next_follow_up_at: null,
      follow_up_completed_at: null,
    },
    {
      status: "awaiting_customer",
      assigned_staff_user_id: "s1",
      next_follow_up_at: "2026-09-21T09:00:00Z",
      follow_up_completed_at: null,
    },
    {
      status: "closed",
      assigned_staff_user_id: null,
      next_follow_up_at: "2026-09-20T09:00:00Z",
      follow_up_completed_at: null,
    },
    {
      status: "cancelled",
      assigned_staff_user_id: null,
      next_follow_up_at: null,
      follow_up_completed_at: null,
    },
    {
      status: "in_review",
      assigned_staff_user_id: null,
      next_follow_up_at: "2026-09-19T09:00:00Z",
      follow_up_completed_at: null,
    },
  ], now);
  assertEquals(counts.new_enquiries, 1);
  assertEquals(counts.unassigned_enquiries, 2);
  assertEquals(counts.awaiting_customer, 1);
  assertEquals(counts.follow_ups_due, 1);
  assertEquals(counts.follow_ups_overdue, 1);
  assertEquals(counts.in_pipeline, 3);
});

Deno.test("consultant role filter keeps unassigned + own work", () => {
  const rows = [
    { id: "1", assigned_staff_user_id: null },
    { id: "2", assigned_staff_user_id: "me" },
    { id: "3", assigned_staff_user_id: "other" },
  ];
  const filtered = filterEnquiriesForRole(rows, "consultant", "me");
  assertEquals(filtered.map((r) => r.id), ["1", "2"]);
  assertEquals(filterEnquiriesForRole(rows, "admin", "me").length, 3);
});

Deno.test("note and search sanitizers bound input", () => {
  assertEquals(sanitizeNoteBody("  hello  "), "hello");
  assertEquals(sanitizeSearchQuery("a%b_c").includes("%"), false);
});
