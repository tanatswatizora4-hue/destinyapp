/**
 * Destina observability + call-count tests. Deterministic — no paid Gemini.
 */

import { assertEquals, assertRejects } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { DestinaError } from "./destina_domain.ts";
import { emptyTripState, mergeTripState } from "./destina_rules.ts";
import { DESTINA_AMBIGUOUS_REGIONS, parseFlexibleDate } from "./destina_airports.ts";
import {
  SequenceDestinaProvider,
  ScriptedDestinaProvider,
  TimeoutDestinaProvider,
} from "./mock_provider.ts";
import { DestinaToolDeps, executeDestinaTool } from "./destina_tools.ts";
import { runDestinaLoop } from "./destina_orchestrator.ts";
import { withTimeout } from "./destina_model.ts";
import {
  DestinaObsEvent,
  DestinaRequestTrace,
  assertSafeObsEvent,
  classifyDestinaErrorCode,
} from "./destina_observability.ts";
import { GeminiDestinaProvider } from "./gemini_provider.ts";

function deps(overrides: Partial<DestinaToolDeps> = {}): DestinaToolDeps {
  return {
    searchFlights: async () => ({
      offers: [],
      nextLegRequired: false,
      provider: "travelport",
      transactionId: "txn",
      warnings: [],
    }),
    searchCatalog: async () => [{ id: "t1", name: "Falls day tour" }],
    getCatalogDetail: async () => null,
    getProfile: async () => ({ display_name: "Ada" }),
    listBookings: async () => [],
    getBooking: async () => null,
    createEnquiry: async () => ({ id: "enq-1", status: "received" }),
    ...overrides,
  };
}

const actor = { userId: "user-1", displayName: "Ada", email: "a@x.com" };

function collectSink() {
  const events: DestinaObsEvent[] = [];
  return {
    events,
    sink: (e: DestinaObsEvent) => events.push(e),
  };
}

Deno.test("obs A completed request emits destina_request_completed", async () => {
  const { events, sink } = collectSink();
  const trace = new DestinaRequestTrace({ sink });
  trace.start(true, "chat");
  const out = await runDestinaLoop({
    model: new ScriptedDestinaProvider(),
    deps: deps(),
    actor,
    conversationId: "c1",
    tripState: emptyTripState(),
    history: [],
    userMessage: "hi",
    trace,
  });
  Object.assign(trace.metrics, out.metrics);
  trace.complete("ok");
  assertEquals(events.some((e) => e.event === "destina_request_started"), true);
  assertEquals(events.some((e) => e.event === "destina_request_completed"), true);
  assertEquals(out.metrics.model_calls, 1);
  assertEquals(out.metrics.tool_calls, 0);
});

Deno.test("obs B C customer fallback emits destina_request_failed with stage", () => {
  const { events, sink } = collectSink();
  const trace = new DestinaRequestTrace({ sink });
  trace.start(false, "chat");
  trace.fail("model_timeout", 504);
  const failed = events.find((e) => e.event === "destina_request_failed");
  assertEquals(failed?.event, "destina_request_failed");
  if (failed?.event === "destina_request_failed") {
    assertEquals(failed.stage, "model");
    assertEquals(failed.error_code, "model_timeout");
  }
});

Deno.test("obs D E F timing events never contain customer text, signatures, or secrets", () => {
  const event = assertSafeObsEvent({
    event: "destina_model_call_completed",
    request_id: "r1",
    iteration: 0,
    duration_ms: 12,
    outcome: "ok",
    tool_call_count: 0,
    provider: "gemini",
    model: "gemini-3.6-flash",
  });
  const encoded = JSON.stringify(event);
  assertEquals(/how much are flights|thoughtSignature|AIza|service_role|Bearer /i.test(encoded), false);

  let threw = false;
  try {
    assertSafeObsEvent({
      event: "destina_model_provider_error",
      provider: "gemini",
      model: "gemini-3.6-flash",
      http_status: 400,
      provider_status: "INVALID",
      provider_code: null,
      provider_message: "key AIzaSyFakeSecretKey1234567890xxxx",
    });
  } catch {
    threw = true;
  }
  assertEquals(threw, true);
});

Deno.test("obs G model timeout classified model_timeout", async () => {
  const err = await assertRejects(
    () =>
      withTimeout(
        new TimeoutDestinaProvider().generate({ system: "", messages: [], tools: [] }),
        5,
      ),
    DestinaError,
  );
  assertEquals(err.code, "model_timeout");
  assertEquals(classifyDestinaErrorCode(err.code).stage, "model");
  assertEquals(classifyDestinaErrorCode(err.code).error_code, "model_timeout");
});

Deno.test("obs H travelport timeout classified travelport_timeout", async () => {
  const { FlightProviderError } = await import(
    "../flight-commerce-api/flight_domain.ts"
  );
  let code = "";
  const { result } = await executeDestinaTool(
    deps({
      searchFlights: async () => {
        throw new FlightProviderError("provider_timeout", "timed out", {
          retryable: true,
        });
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
    {
      origin: "Harare",
      destination: "Johannesburg",
      departure_date: "2026-11-20",
    },
  );
  code = result.error_code ?? "";
  assertEquals(code, "travelport_timeout");
  assertEquals(classifyDestinaErrorCode(code).stage, "travelport");
});

Deno.test("obs I airport resolution / ambiguous classified safely", async () => {
  const amb = await executeDestinaTool(
    deps(),
    {
      actor,
      tripState: emptyTripState(),
      conversationId: "c1",
      flightSearchesUsed: 0,
      catalogCallsUsed: 0,
    },
    "search_flights",
    {
      origin: "Harare",
      destination: "Japan",
      departure_date: "2026-12-02",
    },
  );
  assertEquals(amb.result.status, "needs_input");
  assertEquals(amb.result.error_code, "airport_ambiguous");
  assertEquals(
    amb.result.summary,
    DESTINA_AMBIGUOUS_REGIONS.japan.prompt,
  );
  assertEquals(classifyDestinaErrorCode("airport_ambiguous").stage, "airport_resolution");

  const unresolved = await executeDestinaTool(
    deps(),
    {
      actor,
      tripState: emptyTripState(),
      conversationId: "c1",
      flightSearchesUsed: 0,
      catalogCallsUsed: 0,
    },
    "search_flights",
    {
      origin: "Harare",
      destination: "Narnia",
      departure_date: "2026-12-02",
    },
  );
  assertEquals(unresolved.result.error_code, "airport_unresolved");
  assertEquals(
    classifyDestinaErrorCode("airport_unresolved").error_code,
    "airport_resolution",
  );
});

Deno.test("obs J unknown_internal classification", () => {
  const c = classifyDestinaErrorCode("something_weird");
  assertEquals(c.stage, "unknown_internal");
  assertEquals(c.error_code, "something_weird");
});

Deno.test("perf A hi → one model call, zero tools", async () => {
  const out = await runDestinaLoop({
    model: new ScriptedDestinaProvider(),
    deps: deps(),
    actor,
    conversationId: "c1",
    tripState: emptyTripState(),
    history: [],
    userMessage: "hi",
  });
  assertEquals(out.metrics.model_calls, 1);
  assertEquals(out.metrics.tool_calls, 0);
});

Deno.test("perf B October question → one model call, zero tools", async () => {
  const out = await runDestinaLoop({
    model: new ScriptedDestinaProvider(),
    deps: deps(),
    actor,
    conversationId: "c1",
    tripState: emptyTripState(),
    history: [],
    userMessage: "Is Zanzibar good in October?",
  });
  assertEquals(out.metrics.model_calls, 1);
  assertEquals(out.metrics.tool_calls, 0);
});

Deno.test("perf C packing → one model call", async () => {
  const out = await runDestinaLoop({
    model: new ScriptedDestinaProvider(),
    deps: deps(),
    actor,
    conversationId: "c1",
    tripState: emptyTripState(),
    history: [],
    userMessage: "What should I pack?",
  });
  assertEquals(out.metrics.model_calls, 1);
  assertEquals(out.metrics.tool_calls, 0);
});

Deno.test("perf D text + update_trip_state skips redundant second model call", async () => {
  const model = new SequenceDestinaProvider("mock", [
    {
      text: "Got it — Zanzibar sounds wonderful. Beach escape or Stone Town exploring?",
      toolCalls: [{
        id: "1",
        name: "update_trip_state",
        arguments: { destination: "Zanzibar" },
      }],
    },
    {
      text: "THIS SHOULD NOT RUN",
      toolCalls: [],
    },
  ]);
  const out = await runDestinaLoop({
    model,
    deps: deps(),
    actor,
    conversationId: "c1",
    tripState: emptyTripState(),
    history: [],
    userMessage: "I want to go to Zanzibar",
  });
  assertEquals(model.requests.length, 1);
  assertEquals(out.metrics.model_calls, 1);
  assertEquals(out.tripState.destination, "Zanzibar");
  assertEquals(out.response.message.content.includes("Stone Town"), true);
  assertEquals(out.response.message.content.includes("THIS SHOULD NOT RUN"), false);
});

Deno.test("perf E state-only update allows continuation model call", async () => {
  const model = new SequenceDestinaProvider("mock", [
    {
      text: "",
      toolCalls: [{
        id: "1",
        name: "update_trip_state",
        arguments: { destination: "Zanzibar" },
      }],
    },
    {
      text: "Zanzibar is lovely — beach trip or Stone Town?",
      toolCalls: [],
    },
  ]);
  const out = await runDestinaLoop({
    model,
    deps: deps(),
    actor,
    conversationId: "c1",
    tripState: emptyTripState(),
    history: [],
    userMessage: "I want to go to Zanzibar",
  });
  assertEquals(model.requests.length, 2);
  assertEquals(out.metrics.model_calls, 2);
  assertEquals(out.response.message.content.includes("Stone Town"), true);
});

Deno.test("perf F complete flight request → search_flights without redundant update round trip", async () => {
  let flights = 0;
  const model = new SequenceDestinaProvider("mock", [
    {
      text: "",
      toolCalls: [{
        id: "1",
        name: "search_flights",
        arguments: {
          origin: "Harare",
          destination: "Johannesburg",
          departure_date: "2026-11-20",
        },
      }],
    },
    {
      text: "Here are live Travelport quotes. These are not tickets.",
      toolCalls: [],
    },
  ]);
  const out = await runDestinaLoop({
    model,
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
    userMessage: "Find me flights from Harare to Johannesburg on 2026-11-20",
  });
  assertEquals(flights, 1);
  assertEquals(out.toolRuns.some((t) => t.name === "update_trip_state"), false);
  assertEquals(out.toolRuns.filter((t) => t.name === "search_flights").length, 1);
  assertEquals(out.metrics.model_calls, 2);
});

Deno.test("perf G Japan multi-turn retains context and never hits Travelport until city resolved", async () => {
  let flights = 0;
  const first = await runDestinaLoop({
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
    userMessage: "how much are flights to japan",
  });
  assertEquals(flights, 0);
  assertEquals(first.tripState.destination, "Japan");
  assertEquals(first.tripState.destination_iata, null);
  assertEquals(
    /origin|flying from|departure|date/i.test(first.response.message.content),
    true,
  );

  const second = await runDestinaLoop({
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
    tripState: first.tripState,
    history: [
      { role: "user", content: "how much are flights to japan" },
      { role: "assistant", content: first.response.message.content },
    ],
    userMessage: "harare, departing december second",
  });
  assertEquals(flights, 0);
  assertEquals(second.tripState.destination, "Japan");
  assertEquals(second.tripState.origin, "Harare");
  assertEquals(second.tripState.origin_iata, "HRE");
  assertEquals(second.tripState.departure_date, "2026-12-02");
  assertEquals(
    second.toolRuns.some((t) =>
      t.name === "search_flights" && t.error_code === "airport_ambiguous"
    ),
    true,
  );
  assertEquals(
    second.response.message.content.includes(
      DESTINA_AMBIGUOUS_REGIONS.japan.prompt,
    ) ||
      /tokyo|osaka|japan/i.test(second.response.message.content),
    true,
  );
  assertEquals(second.response.message.content.includes("IATA"), false);
});

Deno.test("perf december second resolves to 2026-12-02 from current year rules", () => {
  const parsed = parseFlexibleDate("december second", new Date("2026-09-21T12:00:00Z"));
  assertEquals(parsed.status, "resolved");
  if (parsed.status === "resolved") {
    assertEquals(parsed.iso, "2026-12-02");
  }
});

Deno.test("perf H I J K gemini retry once on 429, never on 400, never duplicates enquiry", async () => {
  let fetches = 0;
  let enquiries = 0;
  const fetch429ThenOk: typeof fetch = async () => {
    fetches += 1;
    if (fetches === 1) {
      return new Response(JSON.stringify({ error: { message: "rate" } }), {
        status: 429,
      });
    }
    return new Response(
      JSON.stringify({
        candidates: [{
          content: {
            parts: [{ text: "Hello from Destina after retry." }],
            role: "model",
          },
        }],
      }),
      { status: 200 },
    );
  };
  const retries: string[] = [];
  const p = new GeminiDestinaProvider(
    {
      apiKey: "test-key-not-real",
      model: "gemini-3.6-flash",
      maxRetries: 1,
      retryBackoffMs: 1,
      onRetry: (info) => retries.push(info.reason),
    },
    fetch429ThenOk,
  );
  const out = await p.generate({
    system: "sys",
    messages: [{ role: "user", content: "hi" }],
    tools: [],
  });
  assertEquals(fetches, 2);
  assertEquals(retries, ["model_429"]);
  assertEquals(out.text.includes("Hello from Destina"), true);

  let fetches400 = 0;
  const fetch400: typeof fetch = async () => {
    fetches400 += 1;
    return new Response(JSON.stringify({ error: { message: "bad", status: "INVALID_ARGUMENT" } }), {
      status: 400,
    });
  };
  const p400 = new GeminiDestinaProvider(
    {
      apiKey: "test-key-not-real",
      model: "gemini-3.6-flash",
      maxRetries: 1,
      retryBackoffMs: 1,
    },
    fetch400,
  );
  let code400 = "";
  try {
    await p400.generate({
      system: "sys",
      messages: [{ role: "user", content: "hi" }],
      tools: [],
    });
  } catch (e) {
    code400 = e instanceof DestinaError ? e.code : "other";
  }
  assertEquals(fetches400, 1);
  assertEquals(code400, "model_invalid_argument");

  // Side-effecting enquiry must not re-run on model retry (retry is provider-level only).
  const model = new SequenceDestinaProvider("mock", [
    {
      text: "",
      toolCalls: [{
        id: "1",
        name: "create_travel_enquiry",
        arguments: { confirm: true, summary: "please send" },
      }],
    },
    { text: "Sent to the team.", toolCalls: [] },
  ]);
  await runDestinaLoop({
    model,
    deps: deps({
      createEnquiry: async () => {
        enquiries += 1;
        return { id: "enq-1", status: "received" };
      },
    }),
    actor,
    conversationId: "c1",
    tripState: emptyTripState(),
    history: [],
    userMessage: "Yes, please send this to the team.",
  });
  assertEquals(enquiries, 1);
});

Deno.test("perf K no retry on deterministic validation failure", async () => {
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
    {
      actor,
      tripState: emptyTripState(),
      conversationId: "c1",
      flightSearchesUsed: 0,
      catalogCallsUsed: 0,
    },
    "search_flights",
    { origin: "Harare", destination: "Japan", departure_date: "2026-12-02" },
  );
  assertEquals(called, false);
  assertEquals(result.status, "needs_input");
});

Deno.test("mergeTripState keeps Japan without inventing IATA", () => {
  const next = mergeTripState(emptyTripState(), { destination: "Japan" });
  assertEquals(next.destination, "Japan");
  assertEquals(next.destination_iata, null);
});
