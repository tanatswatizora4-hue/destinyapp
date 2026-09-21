/**
 * Conversational-first Destina tests. Deterministic mock model only.
 */

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { DestinaChatMessage } from "./destina_domain.ts";
import { emptyTripState, mergeTripState } from "./destina_rules.ts";
import { DESTINA_PLACE_COPY } from "./destina_airports.ts";
import {
  SequenceDestinaProvider,
  ScriptedDestinaProvider,
} from "./mock_provider.ts";
import { DestinaToolDeps, executeDestinaTool } from "./destina_tools.ts";
import { runDestinaLoop } from "./destina_orchestrator.ts";

function deps(overrides: Partial<DestinaToolDeps> = {}): DestinaToolDeps {
  return {
    searchFlights: async () => ({
      offers: [],
      nextLegRequired: false,
      provider: "travelport",
      transactionId: "txn",
      warnings: [],
    }),
    searchCatalog: async () => [{ id: "t1", name: "Zanzibar spice tour" }],
    getCatalogDetail: async () => null,
    getProfile: async () => ({ display_name: "Ada" }),
    listBookings: async () => [{ id: "b1", status: "submitted", item_name: "Tour" }],
    getBooking: async () => null,
    createEnquiry: async () => ({ id: "enq-1", status: "received" }),
    ...overrides,
  };
}

const actor = { userId: "user-1", displayName: "Ada", email: "a@x.com" };

function loop(
  userMessage: string,
  model = new ScriptedDestinaProvider(),
  extra: Partial<DestinaToolDeps> = {},
  tripState = emptyTripState(),
  history: DestinaChatMessage[] = [],
) {
  return runDestinaLoop({
    model,
    deps: deps(extra),
    actor,
    conversationId: "c1",
    tripState,
    history,
    userMessage,
  });
}

Deno.test("A hi is conversational with no required tool", async () => {
  const out = await loop("hi");
  assertEquals(out.toolRuns.length, 0);
  assertEquals(out.response.message.content.toLowerCase().includes("destina"), true);
  assertEquals(out.response.message.content.includes("IATA"), false);
});

Deno.test("B Zanzibar intent stores a natural destination without IATA errors", async () => {
  const out = await loop("I want to go to Zanzibar.");
  assertEquals(out.tripState.destination, "Zanzibar");
  assertEquals(out.tripState.destination_iata, "ZNZ");
  assertEquals(out.toolRuns.some((t) => t.name === "search_flights"), false);
  assertEquals(out.response.message.content.includes("IATA"), false);
  assertEquals(out.response.message.content.toLowerCase().includes("zanzibar"), true);
});

Deno.test("C top places is conversational with no flight tool", async () => {
  const out = await loop("What are the top 3 places to visit?");
  assertEquals(out.toolRuns.some((t) => t.name === "search_flights"), false);
  assertEquals(out.toolRuns.length, 0);
  assertEquals(out.response.message.content.includes("IATA"), false);
});

Deno.test("D October question is conversational with no flight tool", async () => {
  const out = await loop("Is Zanzibar good in October?");
  assertEquals(out.toolRuns.length, 0);
  assertEquals(out.response.message.content.toLowerCase().includes("october"), true);
});

Deno.test("E packing is conversational using context", async () => {
  const out = await loop("What should I pack?");
  assertEquals(out.toolRuns.length, 0);
  assertEquals(out.response.message.content.toLowerCase().includes("pack"), true);
});

Deno.test("F Harare to Johannesburg resolves HRE/JNB for search_flights", async () => {
  const captured: Record<string, unknown>[] = [];
  const out = await loop(
    "Find me flights from Harare to Johannesburg on 2026-11-20",
    new ScriptedDestinaProvider(),
    {
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
    },
  );
  assertEquals(out.toolRuns.some((t) => t.name === "search_flights"), true);
  assertEquals(captured[0]?.origin, "HRE");
  assertEquals(captured[0]?.destination, "JNB");
});

Deno.test("G flight from Harare to Zanzibar resolves HRE/ZNZ", async () => {
  const captured: Record<string, unknown>[] = [];
  const out = await loop(
    "flight from Harare to Zanzibar on 2026-10-12",
    new ScriptedDestinaProvider(),
    {
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
    },
  );
  assertEquals(out.toolRuns.some((t) => t.name === "search_flights"), true);
  assertEquals(captured[0]?.origin, "HRE");
  assertEquals(captured[0]?.destination, "ZNZ");
});

Deno.test("H Destiny packages use a catalog tool", async () => {
  const out = await loop("Show me Destiny's Zanzibar packages");
  assertEquals(out.toolRuns.some((t) => t.name === "search_tours"), true);
  assertEquals(out.toolRuns.some((t) => t.name === "search_flights"), false);
});

Deno.test("I booking status uses a customer booking tool", async () => {
  const out = await loop("What's the status of my booking?");
  assertEquals(out.toolRuns.some((t) => t.name === "list_customer_bookings"), true);
});

Deno.test("J send to consultant uses handoff", async () => {
  const out = await loop("Send this to a consultant");
  assertEquals(out.toolRuns.some((t) => t.name === "handoff_to_consultant"), true);
});

Deno.test("follow-ups keep Zanzibar context and only ask for missing flight facts", async () => {
  const trip = mergeTripState(emptyTripState(), { destination: "Zanzibar" });
  const history: DestinaChatMessage[] = [
    { role: "user", content: "I want to go to Zanzibar" },
    {
      role: "assistant",
      content:
        "Zanzibar is a great choice. Are you thinking of a relaxing beach trip, exploring Stone Town, or a bit of both?",
    },
  ];
  const beaches = await loop("mostly beaches", new ScriptedDestinaProvider(), {}, trip, history);
  assertEquals(beaches.toolRuns.length, 0);
  assertEquals(beaches.tripState.destination, "Zanzibar");

  const october = await loop("what about October?", new ScriptedDestinaProvider(), {}, trip, history);
  assertEquals(october.toolRuns.length, 0);
  assertEquals(october.response.message.content.toLowerCase().includes("october"), true);
  assertEquals(october.response.message.content.includes("IATA"), false);

  const flights = await loop("okay find me flights", new ScriptedDestinaProvider(), {}, trip, history);
  assertEquals(flights.toolRuns.some((t) => t.name === "search_flights"), false);
  assertEquals(flights.tripState.destination, "Zanzibar");
  assertEquals(flights.response.message.content.toLowerCase().includes("flying from"), true);
});

Deno.test("K state-only update is followed by a natural model turn", async () => {
  const model = new SequenceDestinaProvider("mock", [
    {
      text: "",
      toolCalls: [{
        id: "s1",
        name: "update_trip_state",
        arguments: { destination: "Zanzibar" },
      }],
    },
    {
      text:
        "Zanzibar is a great choice. Are you thinking of a relaxing beach trip, exploring Stone Town, or a bit of both?",
      toolCalls: [],
    },
  ]);
  const out = await loop("I want to go to Zanzibar.", model);
  assertEquals(model.requests.length, 2);
  assertEquals(out.tripState.destination, "Zanzibar");
  assertEquals(out.response.message.content.toLowerCase().includes("stone town"), true);
  assertEquals(JSON.stringify(out.response).includes("IATA"), false);
});

Deno.test("L multiple tool calls retain Gemini 3.6 thought signatures", async () => {
  const sigUpdate = "opaque-thought-sig-update";
  const sigFlights = "opaque-thought-sig-flights";
  const model = new SequenceDestinaProvider("gemini", [
    {
      text: "",
      toolCalls: [{
        id: "s1",
        name: "update_trip_state",
        arguments: { destination: "Zanzibar" },
      }],
      providerTurn: {
        provider: "gemini",
        parts: [{
          functionCall: {
            id: "s1",
            name: "update_trip_state",
            args: { destination: "Zanzibar" },
          },
          thoughtSignature: sigUpdate,
        }],
      },
    },
    {
      text: "",
      toolCalls: [{
        id: "s2",
        name: "search_flights",
        arguments: {
          origin: "Harare",
          destination: "Zanzibar",
          departure_date: "2026-10-12",
        },
      }],
      providerTurn: {
        provider: "gemini",
        parts: [{
          functionCall: {
            id: "s2",
            name: "search_flights",
            args: {
              origin: "Harare",
              destination: "Zanzibar",
              departure_date: "2026-10-12",
            },
          },
          thoughtSignature: sigFlights,
        }],
      },
    },
    {
      text: "Here are live quotes from Travelport. These are not tickets.",
      toolCalls: [],
    },
  ]);
  const out = await loop("Find me flights from Harare to Zanzibar on 2026-10-12", model);
  assertEquals(model.requests.length, 3);
  assertEquals(JSON.stringify(model.requests[1].messages).includes(sigUpdate), true);
  assertEquals(JSON.stringify(model.requests[2].messages).includes(sigFlights), true);
  assertEquals(JSON.stringify(out.response).includes("thoughtSignature"), false);
  assertEquals("providerTurn" in out.response, false);
});

Deno.test("M ordinary conversation never surfaces raw IATA validation errors", async () => {
  const { result } = await executeDestinaTool(
    deps(),
    {
      actor,
      tripState: emptyTripState(),
      conversationId: "c1",
      flightSearchesUsed: 0,
      catalogCallsUsed: 0,
    },
    "update_trip_state",
    { destination: "Zanzibar" },
  );
  assertEquals(result.status, "ok");
  assertEquals(result.summary.includes("IATA"), false);
  const publicText = JSON.stringify(result);
  assertEquals(publicText.includes("Airport codes must"), false);
});

Deno.test("N unknown airport never reaches Travelport", async () => {
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
    {
      actor,
      tripState: emptyTripState(),
      conversationId: "c1",
      flightSearchesUsed: 0,
      catalogCallsUsed: 0,
    },
    "search_flights",
    { origin: "Harare", destination: "Narnia", departure_date: "2026-11-20" },
  );
  assertEquals(called, false);
  assertEquals(result.status, "needs_input");
  assertEquals(result.error_code, "airport_unresolved");
  assertEquals(result.summary, DESTINA_PLACE_COPY.flyTo);
  assertEquals(tripState.destination, "Narnia");
  assertEquals(tripState.destination_iata, null);
});

Deno.test("O ordinary conversation does not invent fares, holds, or bookings", async () => {
  const mauritius = await loop("tell me about Mauritius");
  assertEquals(mauritius.toolRuns.length, 0);
  assertEquals(/\$\d|confirmed booking|PNR|ticketed/i.test(mauritius.response.message.content), false);

  const expensive = await loop("haha that's expensive");
  assertEquals(expensive.toolRuns.length, 0);
  assertEquals(/IATA|Airport codes must/i.test(expensive.response.message.content), false);
  assertEquals(/invent a cheaper fare/i.test(expensive.response.message.content), true);
});
