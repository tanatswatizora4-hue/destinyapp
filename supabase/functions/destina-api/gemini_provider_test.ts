/**
 * Gemini adapter tests — mock fetch only. No paid Gemini calls.
 */

import {
  assertEquals,
  assertRejects,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { DestinaError, DestinaModelGenerateRequest } from "./destina_domain.ts";
import { DESTINA_TOOL_SPECS } from "./destina_tools.ts";
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
const MODEL = "gemini-2.5-flash";

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

Deno.test("generateContent URL uses v1beta models path without the API key", () => {
  const url = geminiGenerateContentUrl(MODEL);
  assertEquals(
    url,
    "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent",
  );
  assertEquals(url.includes("key="), false);
  assertEquals(geminiGenerateContentUrl("models/gemini-2.5-flash"), url);
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

Deno.test("tool results become functionCall then functionResponse", () => {
  const contents = buildGeminiContents([
    { role: "user", content: "Find HRE to JNB" },
    { role: "assistant", content: "tool:search_flights" },
    {
      role: "tool",
      toolName: "search_flights",
      content: JSON.stringify({ status: "needs_input", summary: "Need dates" }),
    },
  ]);
  assertEquals(contents[0].role, "user");
  assertEquals(contents[1].role, "model");
  const modelParts = contents[1].parts as Record<string, unknown>[];
  assertEquals(
    (modelParts[0].functionCall as { name: string }).name,
    "search_flights",
  );
  assertEquals(contents[2].role, "user");
  const userParts = contents[2].parts as Record<string, unknown>[];
  const fr = userParts[0].functionResponse as {
    name: string;
    response: Record<string, unknown>;
  };
  assertEquals(fr.name, "search_flights");
  assertEquals(fr.response.status, "needs_input");
});

Deno.test("200 text response", async () => {
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
  assertEquals(logs.length, 0);
  assertEquals(captured.url, geminiGenerateContentUrl(MODEL));
  assertEquals(captured.apiKeyHeader, FAKE_KEY);
  assertEquals(captured.url.includes(FAKE_KEY), false);
  assertEquals(captured.body.includes(FAKE_KEY), false);
  assertStringIncludes(captured.body, "systemInstruction");
  assertEquals(captured.body.includes("system_instruction"), false);
});

Deno.test("200 functionCall response", async () => {
  const logs: GeminiLogEvent[] = [];
  const model = providerWith(async () =>
    jsonResponse(200, {
      candidates: [{
        content: {
          role: "model",
          parts: [{
            functionCall: {
              name: "search_flights",
              args: {
                origin: "HRE",
                destination: "JNB",
                departure_date: "2026-10-01",
              },
            },
          }],
        },
      }],
    }), logs);
  const out = await model.generate(sampleRequest());
  assertEquals(out.text, "");
  assertEquals(out.toolCalls.length, 1);
  assertEquals(out.toolCalls[0].name, "search_flights");
  assertEquals(out.toolCalls[0].arguments.origin, "HRE");
  assertEquals(logs.length, 0);
});

async function assertProviderHttpError(
  status: number,
  google: Record<string, unknown>,
  expectedStatus: string,
) {
  const logs: GeminiLogEvent[] = [];
  const model = providerWith(async () => jsonResponse(status, google), logs);
  const err = await assertRejects(
    () => model.generate(sampleRequest()),
    DestinaError,
  );
  assertEquals(err.code, "model_unavailable");
  assertEquals(err.status, 503);
  assertEquals(err.message, DESTINA_MODEL_UNAVAILABLE_MESSAGE);
  assertEquals(logs.length, 1);
  assertEquals(logs[0].event, "destina_model_provider_error");
  assertEquals(logs[0].provider, "gemini");
  assertEquals(logs[0].model, MODEL);
  assertEquals(logs[0].http_status, status);
  assertEquals(logs[0].provider_status, expectedStatus);
  assertNoSecrets(logs[0]);
  assertNoSecrets(err);
  assertEquals(err.message.includes("INVALID_ARGUMENT"), false);
  assertEquals(err.message.includes("UNAUTHENTICATED"), false);
}

Deno.test("400 Gemini error stays sanitized for the client", async () => {
  await assertProviderHttpError(400, {
    error: {
      code: 400,
      status: "INVALID_ARGUMENT",
      message:
        "* GenerateContentRequest.tools[0].function_declarations[8].parameters.properties: should be non-empty for OBJECT type",
    },
  }, "INVALID_ARGUMENT");
});

Deno.test("401 key error stays sanitized for the client", async () => {
  await assertProviderHttpError(401, {
    error: {
      code: 401,
      status: "UNAUTHENTICATED",
      message: `API key ${FAKE_KEY} is invalid`,
    },
  }, "UNAUTHENTICATED");
});

Deno.test("403 key error stays sanitized for the client", async () => {
  await assertProviderHttpError(403, {
    error: {
      code: 403,
      status: "PERMISSION_DENIED",
      message: `Permission denied for key ${FAKE_KEY}`,
    },
  }, "PERMISSION_DENIED");
});

Deno.test("404 model error stays sanitized for the client", async () => {
  await assertProviderHttpError(404, {
    error: {
      code: 404,
      status: "NOT_FOUND",
      message: "models/gemini-2.5-flash is not found for API version v1beta",
    },
  }, "NOT_FOUND");
});

Deno.test("429 quota error stays sanitized for the client", async () => {
  await assertProviderHttpError(429, {
    error: {
      code: 429,
      status: "RESOURCE_EXHAUSTED",
      message: "Quota exceeded for generateContent",
    },
  }, "RESOURCE_EXHAUSTED");
});

Deno.test("5xx provider error stays sanitized for the client", async () => {
  await assertProviderHttpError(500, {
    error: {
      code: 500,
      status: "INTERNAL",
      message: "The model is temporarily unavailable",
    },
  }, "INTERNAL");
});

Deno.test("provider error body never exposes the API key", () => {
  const parsed = parseGeminiErrorBody(JSON.stringify({
    error: {
      code: 401,
      status: "UNAUTHENTICATED",
      message: `Request had invalid authentication credentials. API_KEY=${FAKE_KEY} Bearer abc. Authorization: Bearer abc`,
    },
  }));
  assertEquals(parsed.provider_status, "UNAUTHENTICATED");
  assertEquals(parsed.provider_message.includes(FAKE_KEY), false);
  assertEquals(parsed.provider_message.includes("Bearer abc"), false);
  assertNoSecrets(parsed);
});

Deno.test("sanitizeGeminiProviderMessage redacts keys, JWTs, and emails", () => {
  const out = sanitizeGeminiProviderMessage(
    `user ada@example.com used ${FAKE_KEY} and eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.aaa.bbb`,
  );
  assertEquals(out.includes(FAKE_KEY), false);
  assertEquals(out.includes("ada@example.com"), false);
  assertEquals(out.includes("eyJ"), false);
  assertStringIncludes(out, "[redacted]");
});
