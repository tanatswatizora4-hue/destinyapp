/**
 * M5B/C/D operational helpers — pure, deterministic.
 * Enquiry transitions live in lifecycle_rules.ts (canonical).
 */

import {
  ENQUIRY_STATUSES,
  EnquiryStatus,
  isEnquiryStatus,
} from "./lifecycle_rules.ts";

export { ENQUIRY_STATUSES, isEnquiryStatus, canStaffTransitionEnquiry } from "./lifecycle_rules.ts";
export type { EnquiryStatus } from "./lifecycle_rules.ts";

export const CLOSED_ENQUIRY_STATUSES = new Set<EnquiryStatus>([
  "converted",
  "closed",
  "cancelled",
]);

export function sanitizeNoteBody(raw: unknown): string {
  const s = String(raw ?? "").trim();
  if (!s) throw new Error("Note body is required");
  if (s.length > 4000) throw new Error("Note body exceeds 4000 characters");
  return s;
}

export function sanitizeSearchQuery(raw: unknown): string {
  return String(raw ?? "")
    .trim()
    .slice(0, 80)
    .replace(/[%_]/g, " ");
}

export function clampPage(raw: unknown, fallback = 1): number {
  const n = Number(raw);
  if (!Number.isFinite(n) || n < 1) return fallback;
  return Math.min(Math.trunc(n), 500);
}

export function clampPageSize(raw: unknown, fallback = 25, max = 50): number {
  const n = Number(raw);
  if (!Number.isFinite(n) || n < 1) return fallback;
  return Math.min(Math.trunc(n), max);
}

export function optionalFollowUpAt(raw: unknown): string | null {
  if (raw == null || raw === "") return null;
  const d = new Date(String(raw));
  if (Number.isNaN(d.getTime())) throw new Error("next_follow_up_at invalid");
  return d.toISOString();
}

export type FollowUpState = "none" | "upcoming" | "due" | "overdue" | "done";

/** Deterministic follow-up classification relative to `now`. */
export function classifyFollowUp(
  row: {
    next_follow_up_at: string | null;
    follow_up_completed_at: string | null;
    status: string;
  },
  now: Date = new Date(),
): FollowUpState {
  if (CLOSED_ENQUIRY_STATUSES.has(row.status as EnquiryStatus)) {
    return row.follow_up_completed_at ? "done" : "none";
  }
  if (row.follow_up_completed_at) return "done";
  if (!row.next_follow_up_at) return "none";
  const due = new Date(row.next_follow_up_at).getTime();
  if (Number.isNaN(due)) return "none";
  const t = now.getTime();
  const startOfToday = Date.UTC(
    now.getUTCFullYear(),
    now.getUTCMonth(),
    now.getUTCDate(),
  );
  const endOfToday = startOfToday + 86400000;
  if (due < startOfToday) return "overdue";
  if (due < endOfToday) return "due";
  if (due >= t) return "upcoming";
  return "due";
}

export type DashboardCounts = {
  new_enquiries: number;
  unassigned_enquiries: number;
  follow_ups_due: number;
  follow_ups_overdue: number;
  in_pipeline: number;
  awaiting_customer: number;
};

export function aggregateDashboardCounts(
  enquiries: Array<{
    status: string;
    assigned_staff_user_id: string | null;
    next_follow_up_at: string | null;
    follow_up_completed_at: string | null;
  }>,
  now: Date = new Date(),
): DashboardCounts {
  const counts: DashboardCounts = {
    new_enquiries: 0,
    unassigned_enquiries: 0,
    follow_ups_due: 0,
    follow_ups_overdue: 0,
    in_pipeline: 0,
    awaiting_customer: 0,
  };
  for (const e of enquiries) {
    if (CLOSED_ENQUIRY_STATUSES.has(e.status as EnquiryStatus)) continue;
    if (e.status === "received") counts.new_enquiries += 1;
    if (!e.assigned_staff_user_id) counts.unassigned_enquiries += 1;
    if (e.status === "awaiting_customer") counts.awaiting_customer += 1;
    counts.in_pipeline += 1;
    const fu = classifyFollowUp(e, now);
    if (fu === "due") counts.follow_ups_due += 1;
    if (fu === "overdue") counts.follow_ups_overdue += 1;
  }
  return counts;
}

export function staffCanViewCompanyWide(role: string): boolean {
  return role === "admin" || role === "manager";
}

export function filterEnquiriesForRole<T extends {
  assigned_staff_user_id: string | null;
}>(
  rows: T[],
  role: string,
  staffUserId: string,
): T[] {
  if (staffCanViewCompanyWide(role)) return rows;
  return rows.filter((r) =>
    r.assigned_staff_user_id == null ||
    r.assigned_staff_user_id === staffUserId
  );
}
