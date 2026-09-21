/**
 * Destina rules tests — no model or network.
 * deno test supabase/functions/destina-api
 */

import {
  assertEquals,
  assertRejects,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { DestinaError } from "./destina_domain.ts";
import {
  applySeedContext,
  assertKnownTool,
  assertNoAuthoritativeClientFields,
  clampMessage,
  emptyTripState,
  hashAnonSession,
  isMockModelAllowed,
  mergeTripState,
  missingFlightFields,
  parseToolArguments,
  sanitizeAnonSessionId,
  sanitizeSearchQuery,
} from "./destina_rules.ts";

Deno.test("client cannot set identity or money fields", () => {
  assertThrows(() => assertNoAuthoritativeClientFields({ user_id: "x" }));
  assertThrows(() => assertNoAuthoritativeClientFields({ quoted_total: 9 }));
  assertThrows(() => assertNoAuthoritativeClientFields({ DESTINA_API_KEY: "k" }));
  assertNoAuthoritativeClientFields({ message: "hello", action: "chat" });
});

Deno.test("trip state validates IATA and dates", () => {
  const s = mergeTripState(emptyTripState(), {
    origin: "hre",
    destination: "jnb",
    departure_date: "2026-11-20",
    adults: 2,
  });
  assertEquals(s.origin, "HRE");
  assertEquals(s.destination, "JNB");
  assertEquals(s.adults, 2);
  assertThrows(() => mergeTripState(emptyTripState(), { origin: "Harare" }));
  assertThrows(() =>
    mergeTripState(emptyTripState(), {
      origin: "HRE",
      destination: "HRE",
    })
  );
});

Deno.test("missing flight fields block Travelport", () => {
  assertEquals(missingFlightFields(emptyTripState()), [
    "origin",
    "destination",
    "departure_date",
  ]);
  const ready = mergeTripState(emptyTripState(), {
    origin: "HRE",
    destination: "JNB",
    departure_date: "2026-11-20",
  });
  assertEquals(missingFlightFields(ready), []);
});

Deno.test("seed context is best-effort and does not invent fares", () => {
  const s = applySeedContext(emptyTripState(), {
    product_type: "tour",
    product_id: "tour-1",
    origin: "HRE",
  });
  assertEquals(s.selected_tour_id, "tour-1");
  assertEquals(s.origin, "HRE");
  const bad = applySeedContext(emptyTripState(), { origin: "Harare" });
  assertEquals(bad.origin, null);
});

Deno.test("anon session hashing is unguessable-input only", async () => {
  assertThrows(() => sanitizeAnonSessionId("short"));
  const a = await hashAnonSession("destina-session-aaaaaaaaaaaa");
  const b = await hashAnonSession("destina-session-bbbbbbbbbbbb");
  assertEquals(a.length, 64);
  assertEquals(a === b, false);
});

Deno.test("unknown tools and SQL-like names are rejected", () => {
  assertThrows(() => assertKnownTool("execute_sql"), DestinaError);
  assertThrows(() => assertKnownTool("http_request"), DestinaError);
  assertThrows(() => assertKnownTool("refund_booking"), DestinaError);
  assertEquals(assertKnownTool("search_flights"), "search_flights");
});

Deno.test("search query strips wildcard injection", () => {
  assertEquals(sanitizeSearchQuery("vic%toria_falls"), "vic toria falls");
});

Deno.test("mock model is fail-closed in production", () => {
  assertEquals(
    isMockModelAllowed({ DESTINY_ENV: "production", DESTINA_ALLOW_MOCK: "true" }),
    false,
  );
  assertEquals(
    isMockModelAllowed({ DESTINY_ENV: "development", DESTINA_ALLOW_MOCK: "true" }),
    true,
  );
});

Deno.test("message length is capped", () => {
  assertEquals(clampMessage("  hi  "), "hi");
  const long = "x".repeat(9000);
  assertEquals(clampMessage(long).length, 4000);
});

Deno.test("tool arguments must be objects", () => {
  assertEquals(parseToolArguments('{"origin":"HRE"}').origin, "HRE");
  assertThrows(() => parseToolArguments("not-json"));
});
