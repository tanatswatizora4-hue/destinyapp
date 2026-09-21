/**
 * Gemini adapter tests — mock fetch only. No paid Gemini calls.
 */

import {
  assertEquals,
  assertRejects,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  DestinaError,
  DestinaModelGenerateRequest,
  DestinaModelProvider,
  DestinaModelGenerateResult,
} from "./destina_domain.ts";
import { DESTINA_TOOL_SPECS } from "./destina_tools.ts";
import { emptyTripState } from "./destina_rules.ts";
import { DestinaToolDeps } from "./destina_tools.ts";
import { runDestinaLoop } from "./destina_orchestrator.ts";
import {
  buildGeminiContents,
  buildGeminiGenerateContentBody,
  DESTINA_MODEL_UNAVAILABLE_MESSAGE,
  GeminiDestinaProvider,
  GeminiLogEvent,
  geminiGenerateContentUrl,
  parseGeminiErrorBody,
  sanitizeGeminiProviderMessage,
  toGeminiFunctionDeclarations,
} from "./gemini_provider.ts";

const FAKE_KEY = "AIzaSyTEST_DESTINA_KEY_VALUE_XXXX";
const MODEL = "gemini-3.6-flash";
const SIG_UPDATE = "SIG_UPDATE_TRIP_STATE_OPAQUE_VALUE_AAA";
const SIG_FLIGHTS = "SIG_SEARCH_FLIGHTS_OPAQUE_VALUE_BBB";
const SIG_TOURS = "SIG_SEARCH_TOURS_OPAQUE_VALUE_CCC";
const SIG_PARALLEL = "SIG_PARALLEL_FIRST_OPAQUE_VALUE_DDD";

function sampleRequest(
  overrides: Partial<DestinaModelGenerateRequest> = {},
): DestinaModelGenerateRequest {
  return {
    system: "You are Destina.",
    messages: [{ role: "user", content: "I want to go to Zanzibar." }],
    tools: DESTINA_TOOL_SPECS,
    ...overrides,
  };
}

function jsonResponse(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function providerWith(
  fetchImpl: typeof fetch,
  logs: GeminiLogEvent[],
): GeminiDestinaProvider {
  return new GeminiDestinaProvider(
    {
      apiKey: FAKE_KEY,
      model: MODEL,
      log: (event) => logs.push(event),
    },
    fetchImpl,
  );
}

function assertNoSecrets(value: unknown) {
  const encoded = JSON.stringify(value);
  assertEquals(encoded.includes(FAKE_KEY), false);
  assertEquals(/AIza[0-9A-Za-z_-]{8,}/.test(encoded), false);
  assertEquals(/x-goog-api-key\s*[:=]/i.test(encoded), false);
  assertEquals(/service_role/i.test(encoded), false);
}

function assertNoThoughtSignatures(value: unknown) {
  const encoded = JSON.stringify(value);
  assertEquals(encoded.includes(SIG_UPDATE), false);
  assertEquals(encoded.includes(SIG_FLIGHTS), false);
  assertEquals(encoded.includes(SIG_TOURS), false);
  assertEquals(encoded.includes(SIG_PARALLEL), false);
}

function geminiFcResponse(
  parts: unknown[],
): Record<string, unknown> {
  return {
    candidates: [{
      content: {
        role: "model",
        parts,
      },
    }],
  };
}

function loopDeps(overrides: Partial<DestinaToolDeps> = {}): DestinaToolDeps {
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

Deno.test("generateContent URL uses v1beta models path without the API key", () => {
  const url = geminiGenerateContentUrl(MODEL);
  assertEquals(
    url,
    "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.6-flash:generateContent",
  );
  assertEquals(url.includes("key="), false);
  assertEquals(geminiGenerateContentUrl("models/gemini-3.6-flash"), url);
});

Deno.test("request body matches current generateContent REST shape", () => {
  const body = buildGeminiGenerateContentBody(sampleRequest());
  assertEquals(Array.isArray((body.systemInstruction as { parts: unknown[] }).parts), true);
  assertEquals("system_instruction" in body, false);
  const contents = body.contents as Record<string, unknown>[];
  assertEquals(contents[0].role, "user");
  const tools = body.tools as { functionDeclarations: Record<string, unknown>[] }[];
  const names = tools[0].functionDeclarations.map((d) => d.name);
  assertEquals(names.includes("search_flights"), true);
  const profile = tools[0].functionDeclarations.find((d) => d.name === "get_customer_profile");
  const bookings = tools[0].functionDeclarations.find((d) =>
    d.name === "list_customer_bookings"
  );
  assertEquals(profile?.parameters, undefined);
  assertEquals(bookings?.parameters, undefined);
  const flights = tools[0].functionDeclarations.find((d) => d.name === "search_flights");
  const params = flights?.parameters as Record<string, unknown>;
  assertEquals(params.type, "object");
  assertEquals(Array.isArray(params.required), true);
  const gen = body.generationConfig as Record<string, unknown>;
  assertEquals(gen.temperature, 0.4);
  assertEquals(gen.maxOutputTokens, 1024);
});

Deno.test("parameterless Destina tools omit empty Gemini OBJECT properties", () => {
  const decls = toGeminiFunctionDeclarations(DESTINA_TOOL_SPECS);
  for (const decl of decls) {
    const params = decl.parameters as Record<string, unknown> | undefined;
    if (!params) continue;
    const props = params.properties as Record<string, unknown>;
    assertEquals(Object.keys(props).length > 0, true);
  }
});

Deno.test("A plain text response still works", async () => {
  const logs: GeminiLogEvent[] = [];
  const captured = { url: "", apiKeyHeader: "", body: "" };
  const model = providerWith(async (input, init) => {
    captured.url = String(input);
    captured.apiKeyHeader = new Headers(init?.headers).get("x-goog-api-key") ?? "";
    captured.body = String(init?.body ?? "");
    return jsonResponse(200, {
      candidates: [{
        content: {
          role: "model",
          parts: [{ text: "Zanzibar sounds lovely. When are you hoping to travel?" }],
        },
      }],
    });
  }, logs);
  const out = await model.generate(sampleRequest());
  assertEquals(out.text.includes("Zanzibar sounds lovely"), true);
  assertEquals(out.toolCalls.length, 0);
  assertEquals(out.providerTurn, undefined);
  assertEquals(logs.length, 0);
  assertEquals(captured.url, geminiGenerateContentUrl(MODEL));
  assertEquals(captured.apiKeyHeader, FAKE_KEY);
  assertEquals(captured.url.includes(FAKE_KEY), false);
  assertEquals(captured.body.includes(FAKE_KEY), false);
  assertStringIncludes(captured.body, "systemInstruction");
  assertEquals(captured.body.includes("system_instruction"), false);
});

Deno.test("B functionCall with thought signature is parsed", async () => {
  const logs: GeminiLogEvent[] = [];
  const model = providerWith(async () =>
    jsonResponse(200, geminiFcResponse([{
      functionCall: {
        id: "fc_update_1",
        name: "update_trip_state",
        args: { destination: "ZNZ" },
      },
      thoughtSignature: SIG_UPDATE,
    }])), logs);
  const out = await model.generate(sampleRequest());
  assertEquals(out.toolCalls.length, 1);
  assertEquals(out.toolCalls[0].name, "update_trip_state");
  assertEquals(out.toolCalls[0].id, "fc_update_1");
  assertEquals(out.providerTurn?.provider, "gemini");
  const part = out.providerTurn!.parts[0] as Record<string, unknown>;
  assertEquals(part.thoughtSignature, SIG_UPDATE);
  assertEquals(out.text, "");
  assertEquals(JSON.stringify(out.toolCalls).includes(SIG_UPDATE), false);
});

Deno.test("thought-only parts stay out of public text", async () => {
  const logs: GeminiLogEvent[] = [];
  const model = providerWith(async () =>
    jsonResponse(200, geminiFcResponse([
      { thought: true, text: "I will update destination then search." },
      {
        functionCall: {
          id: "fc_update_1",
          name: "update_trip_state",
          args: { destination: "ZNZ" },
        },
        thoughtSignature: SIG_UPDATE,
      },
    ])), logs);
  const out = await model.generate(sampleRequest());
  assertEquals(out.text, "");
  assertEquals(out.providerTurn?.parts.length, 2);
});

Deno.test("C D follow-up request replays original thought signature then functionResponse", async () => {
  const logs: GeminiLogEvent[] = [];
  const model = providerWith(async () =>
    jsonResponse(200, geminiFcResponse([{
      functionCall: {
        id: "fc_update_1",
        name: "update_trip_state",
        args: { destination: "ZNZ" },
      },
      thoughtSignature: SIG_UPDATE,
    }])), logs);
  const first = await model.generate(sampleRequest());
  const follow = buildGeminiGenerateContentBody({
    system: "You are Destina.",
    tools: DESTINA_TOOL_SPECS,
    messages: [
      { role: "user", content: "I want to go to Zanzibar." },
      {
        role: "assistant",
        content: "tool:update_trip_state",
        providerTurn: first.providerTurn,
      },
      {
        role: "tool",
        toolName: "update_trip_state",
        toolCallId: first.toolCalls[0].id,
        content: JSON.stringify({ status: "ok", summary: "Trip details updated." }),
      },
    ],
  });
  const contents = follow.contents as Record<string, unknown>[];
  assertEquals(contents[1].role, "model");
  const modelParts = contents[1].parts as Record<string, unknown>[];
  assertEquals(modelParts[0].thoughtSignature, SIG_UPDATE);
  assertEquals(
    (modelParts[0].functionCall as { name: string; id: string }).name,
    "update_trip_state",
  );
  assertEquals(
    (modelParts[0].functionCall as { name: string; id: string }).id,
    "fc_update_1",
  );
  assertEquals(contents[2].role, "user");
  const userParts = contents[2].parts as Record<string, unknown>[];
  const fr = userParts[0].functionResponse as {
    name: string;
    id: string;
    response: Record<string, unknown>;
  };
  assertEquals(fr.name, "update_trip_state");
  assertEquals(fr.id, "fc_update_1");
  assertEquals(fr.response.status, "ok");
  assertEquals(JSON.stringify(userParts).includes("thoughtSignature"), false);
});

Deno.test("E F update_trip_state then search_flights then final text", async () => {
  const logs: GeminiLogEvent[] = [];
  const bodies: string[] = [];
  let step = 0;
  const model = providerWith(async (_input, init) => {
    bodies.push(String(init?.body ?? ""));
    step += 1;
    if (step === 1) {
      return jsonResponse(200, geminiFcResponse([{
        functionCall: {
          id: "fc_update_1",
          name: "update_trip_state",
          args: {
            origin: "HRE",
            destination: "JNB",
            departure_date: "2026-11-20",
            flight_required: true,
          },
        },
        thoughtSignature: SIG_UPDATE,
      }]));
    }
    if (step === 2) {
      assertStringIncludes(bodies[1], SIG_UPDATE);
      return jsonResponse(200, geminiFcResponse([{
        functionCall: {
          id: "fc_flights_1",
          name: "search_flights",
          args: {
            origin: "HRE",
            destination: "JNB",
            departure_date: "2026-11-20",
          },
        },
        thoughtSignature: SIG_FLIGHTS,
      }]));
    }
    assertStringIncludes(bodies[2], SIG_UPDATE);
    assertStringIncludes(bodies[2], SIG_FLIGHTS);
    return jsonResponse(200, {
      candidates: [{
        content: {
          role: "model",
          parts: [{
            text: "Here are live fares from Travelport. These are quotes, not tickets.",
          }],
        },
      }],
    });
  }, logs);

  const out = await runDestinaLoop({
    model,
    deps: loopDeps(),
    actor: { userId: "user-1", displayName: "Ada", email: "a@x.com" },
    conversationId: "c1",
    tripState: emptyTripState(),
    history: [],
    userMessage: "Search flights HRE to JNB on 2026-11-20",
  });

  assertEquals(out.tripState.origin, "HRE");
  assertEquals(out.tripState.destination, "JNB");
  assertEquals(out.toolRuns.some((t) => t.name === "update_trip_state"), true);
  assertEquals(out.toolRuns.some((t) => t.name === "search_flights"), true);
  assertEquals(out.response.message.content.includes("live fares"), true);
  assertNoThoughtSignatures(out.response);
  assertNoThoughtSignatures(out.assistantContent);
  assertNoThoughtSignatures(out.toolRuns);
  assertEquals(step, 3);
});

Deno.test("G sequential tool calls preserve continuation state", async () => {
  const contents = buildGeminiContents([
    { role: "user", content: "Plan a trip" },
    {
      role: "assistant",
      content: "tool:update_trip_state",
      providerTurn: {
        provider: "gemini",
        parts: [{
          functionCall: { id: "1", name: "update_trip_state", args: { destination: "ZNZ" } },
          thoughtSignature: SIG_UPDATE,
        }],
      },
    },
    {
      role: "tool",
      toolName: "update_trip_state",
      toolCallId: "1",
      content: JSON.stringify({ status: "ok" }),
    },
    {
      role: "assistant",
      content: "tool:search_tours",
      providerTurn: {
        provider: "gemini",
        parts: [{
          functionCall: { id: "2", name: "search_tours", args: { query: "zanzibar" } },
          thoughtSignature: SIG_TOURS,
        }],
      },
    },
    {
      role: "tool",
      toolName: "search_tours",
      toolCallId: "2",
      content: JSON.stringify({ status: "ok" }),
    },
  ]);
  assertEquals((contents[1].parts as Record<string, unknown>[])[0].thoughtSignature, SIG_UPDATE);
  assertEquals((contents[3].parts as Record<string, unknown>[])[0].thoughtSignature, SIG_TOURS);
  assertEquals(contents[2].role, "user");
  assertEquals(contents[4].role, "user");
});

Deno.test("H parallel tool calls preserve required signatures and order", () => {
  const contents = buildGeminiContents([
    { role: "user", content: "Tours and stays in Victoria Falls" },
    {
      role: "assistant",
      content: "tool:search_tours,tool:search_stays",
      providerTurn: {
        provider: "gemini",
        parts: [
          {
            functionCall: { id: "p1", name: "search_tours", args: { query: "victoria" } },
            thoughtSignature: SIG_PARALLEL,
          },
          {
            functionCall: { id: "p2", name: "search_stays", args: { query: "victoria" } },
          },
        ],
      },
    },
    {
      role: "tool",
      toolName: "search_tours",
      toolCallId: "p1",
      content: JSON.stringify({ status: "ok", summary: "tours" }),
    },
    {
      role: "tool",
      toolName: "search_stays",
      toolCallId: "p2",
      content: JSON.stringify({ status: "ok", summary: "stays" }),
    },
  ]);
  const modelParts = contents[1].parts as Record<string, unknown>[];
  assertEquals(modelParts.length, 2);
  assertEquals(modelParts[0].thoughtSignature, SIG_PARALLEL);
  assertEquals("thoughtSignature" in modelParts[1], false);
  const responses = contents[2].parts as Record<string, unknown>[];
  assertEquals(responses.length, 2);
  assertEquals((responses[0].functionResponse as { id: string }).id, "p1");
  assertEquals((responses[1].functionResponse as { id: string }).id, "p2");
});

Deno.test("K missing provider continuation fails safely without inventing a signature", async () => {
  const logs: GeminiLogEvent[] = [];
  const model = providerWith(async () => {
    throw new Error("Gemini must not be called");
  }, logs);
  const err = await assertRejects(
    () =>
      model.generate(sampleRequest({
        messages: [
          { role: "user", content: "hi" },
          { role: "assistant", content: "tool:update_trip_state" },
          {
            role: "tool",
            toolName: "update_trip_state",
            content: JSON.stringify({ status: "ok" }),
          },
        ],
      })),
    DestinaError,
  );
  assertEquals(err.message, DESTINA_MODEL_UNAVAILABLE_MESSAGE);
  assertEquals(logs[0]?.provider_status, "missing_provider_continuation");
  assertNoThoughtSignatures(logs);
  assertEquals(JSON.stringify(logs).includes("thoughtSignature"), false);
});

Deno.test("K invalid provider continuation fails safely", () => {
  let code = "";
  try {
    buildGeminiContents([
      { role: "user", content: "hi" },
      {
        role: "assistant",
        content: "tool:update_trip_state",
        providerTurn: { provider: "other", parts: [{ functionCall: { name: "update_trip_state" } }] },
      },
      { role: "tool", toolName: "update_trip_state", content: "{}" },
    ]);
  } catch (e) {
    code = e instanceof DestinaError ? e.code : "other";
    assertEquals(e instanceof DestinaError ? e.message : "", DESTINA_MODEL_UNAVAILABLE_MESSAGE);
  }
  assertEquals(code, "model_unavailable");
});

async function assertProviderHttpError(
  status: number,
  google: Record<string, unknown>,
  expectedStatus: string,
  expectedCode =
    status === 429
      ? "model_429"
      : status === 401 || status === 403
      ? "model_auth_error"
      : status === 400
      ? "model_invalid_argument"
      : status >= 500
      ? "model_5xx"
      : "model_unavailable",
) {
  const logs: GeminiLogEvent[] = [];
  const model = providerWith(async () => jsonResponse(status, google), logs);
  const err = await assertRejects(
    () => model.generate(sampleRequest()),
    DestinaError,
  );
  assertEquals(err.code, expectedCode);
  assertEquals(err.status, 503);
  assertEquals(err.message, DESTINA_MODEL_UNAVAILABLE_MESSAGE);
  assertEquals(logs.length >= 1, true);
  assertEquals(logs[0].event, "destina_model_provider_error");
  assertEquals(logs[0].provider, "gemini");
  assertEquals(logs[0].model, MODEL);
  assertEquals(logs[0].http_status, status);
  assertEquals(logs[0].provider_status, expectedStatus);
  assertNoSecrets(logs[0]);
  assertNoSecrets(err);
  assertNoThoughtSignatures(logs[0]);
  assertEquals(err.message.includes("INVALID_ARGUMENT"), false);
  assertEquals(err.message.includes("UNAUTHENTICATED"), false);
}

Deno.test("L 400 Gemini error stays sanitized for the client", async () => {
  await assertProviderHttpError(400, {
    error: {
      code: 400,
      status: "INVALID_ARGUMENT",
      message:
        `Function call is missing a thought_signature in functionCall parts. function call default_api:update_trip_state thoughtSignature=${SIG_UPDATE}`,
    },
  }, "INVALID_ARGUMENT");
});

Deno.test("L 403 key error stays sanitized for the client", async () => {
  await assertProviderHttpError(403, {
    error: {
      code: 403,
      status: "PERMISSION_DENIED",
      message: `Permission denied for key ${FAKE_KEY}`,
    },
  }, "PERMISSION_DENIED");
});

Deno.test("L 404 model error stays sanitized for the client", async () => {
  await assertProviderHttpError(404, {
    error: {
      code: 404,
      status: "NOT_FOUND",
      message: "models/gemini-3.6-flash is not found for API version v1beta",
    },
  }, "NOT_FOUND");
});

Deno.test("L 429 quota error stays sanitized for the client", async () => {
  await assertProviderHttpError(429, {
    error: {
      code: 429,
      status: "RESOURCE_EXHAUSTED",
      message: "Quota exceeded for generateContent",
    },
  }, "RESOURCE_EXHAUSTED");
});

Deno.test("L 5xx provider error stays sanitized for the client", async () => {
  await assertProviderHttpError(500, {
    error: {
      code: 500,
      status: "INTERNAL",
      message: "The model is temporarily unavailable",
    },
  }, "INTERNAL");
});

Deno.test("J provider error body never exposes the API key or thought signature", () => {
  const parsed = parseGeminiErrorBody(JSON.stringify({
    error: {
      code: 400,
      status: "INVALID_ARGUMENT",
      message:
        `Request had invalid authentication credentials. API_KEY=${FAKE_KEY} Bearer abc. "thoughtSignature":"${SIG_UPDATE}"`,
    },
  }));
  assertEquals(parsed.provider_status, "INVALID_ARGUMENT");
  assertEquals(parsed.provider_message.includes(FAKE_KEY), false);
  assertEquals(parsed.provider_message.includes(SIG_UPDATE), false);
  assertEquals(parsed.provider_message.includes("Bearer abc"), false);
  assertNoSecrets(parsed);
  assertNoThoughtSignatures(parsed);
});

Deno.test("sanitizeGeminiProviderMessage redacts keys, JWTs, emails, and signatures", () => {
  const out = sanitizeGeminiProviderMessage(
    `user ada@example.com used ${FAKE_KEY} and eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.aaa.bbb thoughtSignature=${SIG_UPDATE}`,
  );
  assertEquals(out.includes(FAKE_KEY), false);
  assertEquals(out.includes("ada@example.com"), false);
  assertEquals(out.includes("eyJ"), false);
  assertEquals(out.includes(SIG_UPDATE), false);
  assertStringIncludes(out, "[redacted]");
});

class SequenceProvider implements DestinaModelProvider {
  readonly provider = "gemini";
  readonly model = MODEL;
  requests: DestinaModelGenerateRequest[] = [];
  constructor(private readonly steps: DestinaModelGenerateResult[]) {}
  async generate(req: DestinaModelGenerateRequest): Promise<DestinaModelGenerateResult> {
    this.requests.push(req);
    return this.steps.shift() ?? { text: "How else can I help with your trip?", toolCalls: [] };
  }
}

Deno.test("I orchestrator public Destina response never includes thought signatures", async () => {
  const model = new SequenceProvider([{
    text: "",
    toolCalls: [{
      id: "fc_update_1",
      name: "update_trip_state",
      arguments: { destination: "ZNZ" },
    }],
    providerTurn: {
      provider: "gemini",
      parts: [{
        functionCall: { id: "fc_update_1", name: "update_trip_state", args: { destination: "ZNZ" } },
        thoughtSignature: SIG_UPDATE,
      }],
    },
  }, {
    text: "Zanzibar sounds lovely. When are you hoping to travel?",
    toolCalls: [],
  }]);
  const out = await runDestinaLoop({
    model,
    deps: loopDeps(),
    actor: { userId: "user-1", displayName: "Ada", email: "a@x.com" },
    conversationId: "c1",
    tripState: emptyTripState(),
    history: [],
    userMessage: "I want to go to Zanzibar.",
  });
  assertEquals(out.tripState.destination, "ZNZ");
  assertEquals(model.requests.length, 2);
  assertEquals(
    model.requests[1].messages.some((m) =>
      m.role === "assistant" &&
      JSON.stringify(m.providerTurn ?? {}).includes(SIG_UPDATE)
    ),
    true,
  );
  assertNoThoughtSignatures(out.response);
  assertEquals("providerTurn" in out.response, false);
  assertEquals(JSON.stringify(out.response).includes("thoughtSignature"), false);
});
