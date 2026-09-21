/**
 * Destina orchestrator tests with scripted model — no paid Gemini calls.
 */

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { DestinaError } from "./destina_domain.ts";
import { emptyTripState } from "./destina_rules.ts";
import { withTimeout } from "./destina_model.ts";
import {
  FixedToolDestinaProvider,
  LoopingDestinaProvider,
  ScriptedDestinaProvider,
  TimeoutDestinaProvider,
} from "./mock_provider.ts";
import { DestinaToolDeps } from "./destina_tools.ts";
import { runDestinaLoop } from "./destina_orchestrator.ts";
import { isMockModelAllowed } from "./destina_rules.ts";
import { createDestinaModelProvider, DEFAULT_DESTINA_MODEL } from "./destina_model.ts";

function deps(overrides: Partial<DestinaToolDeps> = {}): DestinaToolDeps {
  return {
    searchFlights: async () => ({
      offers: [],
      nextLegRequired: false,
      provider: "travelport",
      transactionId: null,
      warnings: [],
    }),
    searchCatalog: async () => [{ id: "t1", name: "Falls day tour" }],
    getCatalogDetail: async () => null,
    getProfile: async () => ({ display_name: "Ada" }),
    listBookings: async () => [{ id: "b1", status: "submitted", item_name: "Tour" }],
    getBooking: async () => null,
    createEnquiry: async () => ({ id: "enq-1", status: "received" }),
    ...overrides,
  };
}

const actor = { userId: "user-1", displayName: "Ada", email: "a@x.com" };

Deno.test("basic Zanzibar conversation asks one question", async () => {
  const out = await runDestinaLoop({
    model: new ScriptedDestinaProvider(),
    deps: deps(),
    actor,
    conversationId: "c1",
    tripState: emptyTripState(),
    history: [],
    userMessage: "I want to go to Zanzibar.",
  });
  assertEquals(out.response.message.content.toLowerCase().includes("zanzibar"), true);
  assertEquals(out.response.message.content.includes("IATA"), false);
  assertEquals(out.tripState.destination, "Zanzibar");
  assertEquals(out.tripState.destination_iata, "ZNZ");
  assertEquals(out.toolRuns.some((t) => t.name === "search_flights"), false);
});

Deno.test("incomplete flight request does not call Travelport", async () => {
  let flights = 0;
  const out = await runDestinaLoop({
    model: new ScriptedDestinaProvider(),
    deps: deps({
      searchFlights: async () => {
        flights += 1;
        return {
          offers: [],
          nextLegRequired: false,
          provider: "travelport",
          transactionId: null,
          warnings: [],
        };
      },
    }),
    actor,
    conversationId: "c1",
    tripState: emptyTripState(),
    history: [],
    userMessage: "Find me flights to Joburg.",
  });
  assertEquals(flights, 0);
  assertEquals(out.response.message.content.toLowerCase().includes("flying from"), true);
});

Deno.test("complete flight search uses live tool", async () => {
  let flights = 0;
  const out = await runDestinaLoop({
    model: new ScriptedDestinaProvider(),
    deps: deps({
      searchFlights: async () => {
        flights += 1;
        return {
          offers: [],
          nextLegRequired: false,
          provider: "travelport",
          transactionId: "txn",
          warnings: [],
        };
      },
    }),
    actor,
    conversationId: "c1",
    tripState: emptyTripState(),
    history: [],
    userMessage: "Search flights HRE to JNB on 2026-11-20",
  });
  assertEquals(flights, 1);
  assertEquals(out.toolRuns.some((t) => t.name === "search_flights"), true);
});

Deno.test("tool loop limit stops runaway search_tours", async () => {
  const out = await runDestinaLoop({
    model: new LoopingDestinaProvider(),
    deps: deps(),
    actor,
    conversationId: "c1",
    tripState: emptyTripState(),
    history: [],
    userMessage: "tours",
  });
  assertEquals(out.toolRuns.length <= 6, true);
  assertEquals(out.toolRuns.length >= 4, true);
});

Deno.test("model timeout is a DestinaError", async () => {
  let caught = "";
  try {
    await withTimeout(new TimeoutDestinaProvider().generate({
      system: "",
      messages: [],
      tools: [],
    }), 5);
  } catch (e) {
    caught = e instanceof DestinaError ? e.code : "other";
  }
  assertEquals(caught, "model_timeout");
});

Deno.test("anonymous enquiry returns auth_required, never fakes submit", async () => {
  const out = await runDestinaLoop({
    model: new FixedToolDestinaProvider("mock", [{
      id: "1",
      name: "create_travel_enquiry",
      arguments: { confirm: true, summary: "please send" },
    }]),
    deps: deps(),
    actor: { userId: null, displayName: null, email: null },
    conversationId: "anon",
    tripState: emptyTripState(),
    history: [],
    userMessage: "yes send it",
  });
  assertEquals(out.response.auth_required, true);
  assertEquals(out.response.handoff, null);
});

Deno.test("confirmed enquiry returns real id", async () => {
  const out = await runDestinaLoop({
    model: new FixedToolDestinaProvider("mock", [{
      id: "1",
      name: "create_travel_enquiry",
      arguments: { confirm: true, summary: "HRE Zanzibar 2 adults" },
    }], "Sent."),
    deps: deps(),
    actor,
    conversationId: "c1",
    tripState: emptyTripState(),
    history: [],
    userMessage: "Yes, please send this to the team.",
  });
  assertEquals(out.response.handoff?.enquiry_id, "enq-1");
});

Deno.test("Gemini provider factory requires a key", () => {
  let code = "";
  try {
    createDestinaModelProvider({
      DESTINA_MODEL_PROVIDER: "gemini",
      DESTINA_API_KEY: "",
    });
  } catch (e) {
    code = e instanceof DestinaError ? e.code : "other";
  }
  assertEquals(code, "model_not_configured");
});

Deno.test("default Destina model is gemini-3.6-flash", () => {
  const model = createDestinaModelProvider({
    DESTINA_MODEL_PROVIDER: "gemini",
    DESTINA_API_KEY: "test-key",
  });
  assertEquals(model.model, "gemini-3.6-flash");
  assertEquals(DEFAULT_DESTINA_MODEL, "gemini-3.6-flash");
});

Deno.test("mock provider rejected in production", () => {
  assertEquals(
    isMockModelAllowed({ DESTINY_ENV: "production", DESTINA_ALLOW_MOCK: "true" }),
    false,
  );
});

Deno.test("parallel tool calls keep a single model continuation turn", async () => {
  const out = await runDestinaLoop({
    model: new FixedToolDestinaProvider("mock", [
      { id: "p1", name: "search_tours", arguments: { query: "victoria" } },
      { id: "p2", name: "search_stays", arguments: { query: "victoria" } },
    ], "Catalog matches."),
    deps: deps(),
    actor,
    conversationId: "c1",
    tripState: emptyTripState(),
    history: [],
    userMessage: "Tours and stays in Victoria Falls",
  });
  assertEquals(out.toolRuns.some((t) => t.name === "search_tours"), true);
  assertEquals(out.toolRuns.some((t) => t.name === "search_stays"), true);
  assertEquals(JSON.stringify(out.response).includes("thoughtSignature"), false);
});
