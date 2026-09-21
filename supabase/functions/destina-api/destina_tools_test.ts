/**
 * Destina tool registry tests — fake deps, no paid model, no Travelport.
 */

import {
  assertEquals,
  assertRejects,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { DestinaError } from "./destina_domain.ts";
import { FlightProviderError } from "../flight-commerce-api/flight_domain.ts";
import { emptyTripState } from "./destina_rules.ts";
import { DESTINA_PLACE_COPY } from "./destina_airports.ts";
import {
  DestinaToolDeps,
  executeDestinaTool,
} from "./destina_tools.ts";

function deps(overrides: Partial<DestinaToolDeps> = {}): DestinaToolDeps {
  return {
    searchFlights: async () => {
      throw new Error("Travelport should not be called");
    },
    searchCatalog: async () => [],
    getCatalogDetail: async () => null,
    getProfile: async () => ({ display_name: "Ada" }),
    listBookings: async () => [],
    getBooking: async () => null,
    createEnquiry: async () => ({ id: "enq-1", status: "received" }),
    ...overrides,
  };
}

const ctxBase = {
  actor: { userId: "user-1", displayName: "Ada", email: "a@x.com" },
  tripState: emptyTripState(),
  conversationId: "conv-1",
  flightSearchesUsed: 0,
  catalogCallsUsed: 0,
};

Deno.test("search_flights resolves Harare and Johannesburg to HRE/JNB", async () => {
  const captured: Record<string, unknown>[] = [];
  const { result, tripState } = await executeDestinaTool(
    deps({
      searchFlights: async (body) => {
        captured.push(body);
        return {
          offers: [],
          nextLegRequired: false,
          provider: "travelport",
          transactionId: "txn",
          warnings: [],
        };
      },
    }),
    ctxBase,
    "search_flights",
    { origin: "Harare", destination: "Johannesburg", departure_date: "2026-11-20" },
  );
  assertEquals(result.status, "ok");
  assertEquals(captured[0]?.origin, "HRE");
  assertEquals(captured[0]?.destination, "JNB");
  assertEquals(tripState.origin, "Harare");
  assertEquals(tripState.destination, "Johannesburg");
  assertEquals(tripState.origin_iata, "HRE");
  assertEquals(tripState.destination_iata, "JNB");
});

Deno.test("search_flights does not send London to Travelport", async () => {
  let called = false;
  const { result, tripState } = await executeDestinaTool(
    deps({
      searchFlights: async () => {
        called = true;
        return {
          offers: [],
          nextLegRequired: false,
          provider: "travelport",
          transactionId: null,
          warnings: [],
        };
      },
    }),
    ctxBase,
    "search_flights",
    { origin: "Harare", destination: "London", departure_date: "2026-11-20" },
  );
  assertEquals(called, false);
  assertEquals(result.status, "needs_input");
  assertEquals(result.error_code, "airport_unresolved");
  assertEquals(result.summary, DESTINA_PLACE_COPY.flyTo);
  assertEquals(tripState.destination, "London");
  assertEquals(tripState.destination_iata, null);
  assertEquals(/IATA|Airport codes must/i.test(result.summary), false);
});

Deno.test("provider IATA validation is converted to a natural clarification", async () => {
  const { result } = await executeDestinaTool(
    deps({
      searchFlights: async () => {
        throw new FlightProviderError(
          "validation_error",
          "Origin and destination must be 3-letter IATA airport codes",
        );
      },
    }),
    ctxBase,
    "search_flights",
    { origin: "HRE", destination: "JNB", departure_date: "2026-11-20" },
  );
  assertEquals(result.status, "needs_input");
  assertEquals(result.error_code, "invalid_flight_request");
  assertEquals(result.summary, DESTINA_PLACE_COPY.unresolved);
  assertEquals(/IATA|Airport codes must/i.test(result.summary), false);
});

Deno.test("search_flights asks for missing origin instead of calling Travelport", async () => {
  let called = false;
  const { result } = await executeDestinaTool(
    deps({
      searchFlights: async () => {
        called = true;
        return {
          offers: [],
          nextLegRequired: false,
          provider: "travelport",
          transactionId: null,
          warnings: [],
        };
      },
    }),
    ctxBase,
    "search_flights",
    { destination: "JNB", departure_date: "2026-11-20" },
  );
  assertEquals(result.status, "needs_input");
  assertEquals(called, false);
  assertEquals(result.summary, DESTINA_PLACE_COPY.flyFrom);
  assertEquals(/IATA|Airport codes must/i.test(result.summary), false);
});

Deno.test("search_flights returns live quotes without inventing fares", async () => {
  const { result } = await executeDestinaTool(
    deps({
      searchFlights: async () => ({
        offers: [{
          id: "o1",
          provider: {
            provider: "travelport",
            transactionId: "t1",
            offerId: "o1",
            productIds: ["p0"],
            sequence: 1,
          },
          itineraries: [{
            origin: { code: "HRE" },
            destination: { code: "JNB" },
            departure: "2026-11-20T07:25:00",
            arrival: "2026-11-20T09:10:00",
            durationMinutes: 105,
            stops: 0,
            segments: [{
              origin: { code: "HRE" },
              destination: { code: "JNB" },
              departure: "2026-11-20T07:25:00",
              arrival: "2026-11-20T09:10:00",
              durationMinutes: 105,
              carrier: { code: "FN" },
              flightNumber: "FN8331",
              cabin: "Economy",
            }],
          }],
          totalPrice: { amount: 214.1, currency: "GBP" },
          cabin: "Economy",
          fareName: "Value Flex",
          expiresAt: null,
        }],
        nextLegRequired: false,
        provider: "travelport",
        transactionId: "t1",
        warnings: [],
      }),
    }),
    ctxBase,
    "search_flights",
    { origin: "HRE", destination: "JNB", departure_date: "2026-11-20", adults: 1 },
  );
  assertEquals(result.status, "ok");
  assertEquals(result.cards?.[0].kind, "flight_offer");
  assertEquals(result.cards?.[0].source, "live_travelport");
  const offer = result.cards![0].kind === "flight_offer" ? result.cards![0].offer : {};
  assertEquals((offer.total_price as { amount: number }).amount, 214.1);
});

Deno.test("Travelport failure is not invented as availability", async () => {
  const { result } = await executeDestinaTool(
    deps({
      searchFlights: async () => {
        throw new Error("provider timeout");
      },
    }),
    ctxBase,
    "search_flights",
    { origin: "HRE", destination: "JNB", departure_date: "2026-11-20" },
  );
  assertEquals(result.status, "error");
  assertEquals(result.error_code, "travelport_failure");
});

Deno.test("catalog search is labeled not-live-hold", async () => {
  const { result } = await executeDestinaTool(
    deps({
      searchCatalog: async () => [{ id: "s1", name: "Victoria Falls Lodge" }],
    }),
    ctxBase,
    "search_stays",
    { query: "victoria" },
  );
  assertEquals(result.status, "ok");
  assertEquals(result.cards?.[0].kind, "stay");
  if (result.cards?.[0].kind !== "flight_offer") {
    assertEquals(result.cards?.[0].availability, "catalog_not_live_hold");
  }
});

Deno.test("enquiry requires confirmation and auth", async () => {
  const unconfirmed = await executeDestinaTool(
    deps(),
    ctxBase,
    "create_travel_enquiry",
    { confirm: false, summary: "trip" },
  );
  assertEquals(unconfirmed.result.status, "needs_input");

  const anon = await executeDestinaTool(
    deps(),
    { ...ctxBase, actor: { userId: null, displayName: null, email: null } },
    "create_travel_enquiry",
    { confirm: true, summary: "trip" },
  );
  assertEquals(anon.result.status, "auth_required");

  const ok = await executeDestinaTool(
    deps(),
    ctxBase,
    "create_travel_enquiry",
    { confirm: true, summary: "HRE to Zanzibar" },
  );
  assertEquals(ok.result.status, "ok");
  assertEquals(ok.result.data?.enquiry_id, "enq-1");
});

Deno.test("booking status cannot cross customers", async () => {
  const { result } = await executeDestinaTool(
    deps({ getBooking: async () => null }),
    ctxBase,
    "get_booking_status",
    { booking_id: "00000000-0000-4000-8000-000000000099" },
  );
  assertEquals(result.status, "rejected");
});

Deno.test("prompt-injection refund tool is unknown", async () => {
  await assertRejects(
    () =>
      executeDestinaTool(deps(), ctxBase, "refund_booking", {
        booking_id: "XYZ",
      }),
    DestinaError,
  );
});

Deno.test("handoff creates enquiry with brief, not transcript", async () => {
  let payload: Record<string, unknown> | null = null;
  const { result } = await executeDestinaTool(
    deps({
      createEnquiry: async (input) => {
        payload = input.payload;
        return { id: "enq-h", status: "received" };
      },
    }),
    ctxBase,
    "handoff_to_consultant",
    { reason: "customer_requested_human", summary: "Please call Ada" },
  );
  assertEquals(result.status, "ok");
  const destina = payload!.destina as Record<string, unknown>;
  assertEquals(destina.handoff_reason, "customer_requested_human");
  assertEquals(destina.summary, "Please call Ada");
});
