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
  customerFacingToolError,
  DESTINA_SYSTEM_PROMPT,
  emptyTripState,
  hashAnonSession,
  isMockModelAllowed,
  mergeTripState,
  missingFlightFields,
  parseToolArguments,
  sanitizeAnonSessionId,
  sanitizeSearchQuery,
} from "./destina_rules.ts";
import { DESTINA_PLACE_COPY } from "./destina_airports.ts";

Deno.test("client cannot set identity or money fields", () => {
  assertThrows(() => assertNoAuthoritativeClientFields({ user_id: "x" }));
  assertThrows(() => assertNoAuthoritativeClientFields({ quoted_total: 9 }));
  assertThrows(() => assertNoAuthoritativeClientFields({ DESTINA_API_KEY: "k" }));
  assertNoAuthoritativeClientFields({ message: "hello", action: "chat" });
});

Deno.test("trip state accepts human place names and explicit IATA", () => {
  const named = mergeTripState(emptyTripState(), {
    origin: "Harare",
    destination: "Zanzibar",
    departure_date: "2026-11-20",
    adults: 2,
  });
  assertEquals(named.origin, "Harare");
  assertEquals(named.destination, "Zanzibar");
  assertEquals(named.origin_iata, "HRE");
  assertEquals(named.destination_iata, "ZNZ");
  const s = mergeTripState(emptyTripState(), {
    origin: "hre",
    destination: "jnb",
    departure_date: "2026-11-20",
    adults: 2,
  });
  assertEquals(s.origin, "HRE");
  assertEquals(s.destination, "JNB");
  assertEquals(s.origin_iata, "HRE");
  assertEquals(s.destination_iata, "JNB");
  const london = mergeTripState(emptyTripState(), { destination: "London" });
  assertEquals(london.destination, "London");
  assertEquals(london.destination_iata, null);
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
  const bad = applySeedContext(emptyTripState(), { origin: "%%%" });
  assertEquals(bad.origin, null);
  const harare = applySeedContext(emptyTripState(), { origin: "Harare" });
  assertEquals(harare.origin, "Harare");
  assertEquals(harare.origin_iata, "HRE");
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

Deno.test("system prompt is conversational-first and never requires IATA in chat", () => {
  assertEquals(DESTINA_SYSTEM_PROMPT.includes("You MAY and SHOULD answer ordinary conversation"), true);
  assertEquals(DESTINA_SYSTEM_PROMPT.includes("Never ask for IATA codes"), true);
  assertEquals(DESTINA_SYSTEM_PROMPT.includes("update_trip_state is OPTIONAL"), true);
});

Deno.test("customer-facing tool errors never leak IATA validation copy", () => {
  const leaked = customerFacingToolError(
    new DestinaError(
      "validation_error",
      "Airport codes must be 3-letter IATA (e.g. HRE, JNB)",
      400,
    ),
  );
  assertEquals(leaked, DESTINA_PLACE_COPY.flyFrom);
  assertEquals(/IATA|Airport codes must/i.test(leaked), false);
});
