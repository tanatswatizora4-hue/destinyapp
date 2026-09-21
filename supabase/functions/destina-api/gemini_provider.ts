/**
 * Gemini Destina adapter (Gemini 2.5 Flash by default).
 * Credentials stay server-side. Never log the API key or request auth headers.
 */

import {
  DestinaChatMessage,
  DestinaError,
  DestinaModelGenerateRequest,
  DestinaModelGenerateResult,
  DestinaToolCall,
  DestinaToolSpec,
} from "./destina_domain.ts";
import { DestinaModelProvider } from "./destina_domain.ts";

export const DESTINA_MODEL_UNAVAILABLE_MESSAGE =
  "I couldn't reach Destina's language model just now. I can try again, or send this to our travel team.";

export type GeminiLogEvent = {
  event: "destina_model_provider_error";
  provider: "gemini";
  model: string;
  http_status: number;
  provider_status: string | null;
  provider_code: string | number | null;
  provider_message: string;
};

export type GeminiLogger = (event: GeminiLogEvent) => void;

type GeminiOpts = {
  apiKey: string;
  model: string;
  log?: GeminiLogger;
};

const SECRET_LIKE =
  /api[_-]?key|authorization|service_role|password|secret|token|bearer|cookie|x-goog-api-key/i;

export function geminiModelId(model: string): string {
  return model.trim().replace(/^models\//, "");
}

export function geminiGenerateContentUrl(model: string): string {
  return `https://generativelanguage.googleapis.com/v1beta/models/${
    geminiModelId(model)
  }:generateContent`;
}

export function sanitizeGeminiProviderMessage(raw: unknown, max = 400): string {
  let s = typeof raw === "string" ? raw : raw == null ? "" : String(raw);
  s = s.replace(/\s+/g, " ").trim();
  s = s.replace(/AIza[0-9A-Za-z_-]{8,}/g, "[redacted]");
  s = s.replace(/eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/g, "[redacted-jwt]");
  s = s.replace(
    /(?:api[_-]?key|x-goog-api-key|authorization|bearer|token|password|secret|service_role)\s*[:=]\s*\S+/gi,
    "[redacted]",
  );
  s = s.replace(/Bearer\s+\S+/gi, "Bearer [redacted]");
  s = s.replace(/\bAuthorization\b/gi, "[redacted]");
  s = s.replace(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/gi, "[redacted-email]");
  s = s.replace(/[?&](?:key|api_key|access_token)=[^&\s"]+/gi, "[redacted]");
  if (s.length > max) s = `${s.slice(0, max)}…`;
  return s;
}

export function parseGeminiErrorBody(rawText: string): {
  provider_status: string | null;
  provider_code: string | number | null;
  provider_message: string;
} {
  const fallback = {
    provider_status: null,
    provider_code: null,
    provider_message: rawText.trim() ? "non_json_error_body" : "empty_error_body",
  };
  if (!rawText.trim()) return fallback;
  try {
    const json = JSON.parse(rawText) as Record<string, unknown>;
    const err = json.error && typeof json.error === "object"
      ? json.error as Record<string, unknown>
      : json;
    const status = typeof err.status === "string" ? err.status : null;
    const code = typeof err.code === "number" || typeof err.code === "string"
      ? err.code
      : null;
    const message = sanitizeGeminiProviderMessage(err.message ?? fallback.provider_message);
    return {
      provider_status: status,
      provider_code: code,
      provider_message: message || fallback.provider_message,
    };
  } catch {
    return fallback;
  }
}

function geminiRole(role: string): "user" | "model" {
  return role === "assistant" || role === "model" ? "model" : "user";
}

function parseFunctionResponse(content: string): Record<string, unknown> {
  const trimmed = content.trim();
  if (!trimmed) return { result: "" };
  try {
    const parsed = JSON.parse(trimmed) as unknown;
    if (parsed && typeof parsed === "object" && !Array.isArray(parsed)) {
      return parsed as Record<string, unknown>;
    }
    return { result: parsed };
  } catch {
    return { result: content };
  }
}

function isPlaceholderAssistant(msg: DestinaChatMessage): boolean {
  const text = msg.content.trim();
  return text.length === 0 || text.startsWith("tool:");
}

function toGeminiParameters(
  parameters: Record<string, unknown> | undefined,
): Record<string, unknown> | undefined {
  if (!parameters || typeof parameters !== "object") return undefined;
  const props = parameters.properties;
  if (
    !props ||
    typeof props !== "object" ||
    Array.isArray(props) ||
    Object.keys(props as object).length === 0
  ) {
    // Gemini 400: properties must be non-empty for OBJECT type.
    return undefined;
  }
  const out: Record<string, unknown> = {
    type: "object",
    properties: props,
  };
  if (Array.isArray(parameters.required) && parameters.required.length > 0) {
    out.required = parameters.required;
  }
  return out;
}

export function toGeminiFunctionDeclarations(
  tools: DestinaToolSpec[],
): Record<string, unknown>[] {
  return tools.map((t) => {
    const decl: Record<string, unknown> = {
      name: t.name,
      description: t.description,
    };
    const parameters = toGeminiParameters(t.parameters);
    if (parameters) decl.parameters = parameters;
    return decl;
  });
}

export function buildGeminiContents(
  messages: DestinaChatMessage[],
): Record<string, unknown>[] {
  const contents: Record<string, unknown>[] = [];
  let i = 0;
  while (i < messages.length) {
    const msg = messages[i];
    if (msg.role === "system") {
      i += 1;
      continue;
    }
    if (msg.role === "tool") {
      const name = msg.toolName ?? "tool";
      contents.push({
        role: "model",
        parts: [{ functionCall: { name, args: {} } }],
      });
      contents.push({
        role: "user",
        parts: [{
          functionResponse: {
            name,
            response: parseFunctionResponse(msg.content),
          },
        }],
      });
      i += 1;
      continue;
    }
    if (msg.role === "assistant") {
      const following: DestinaChatMessage[] = [];
      let j = i + 1;
      while (j < messages.length && messages[j].role === "tool") {
        following.push(messages[j]);
        j += 1;
      }
      if (following.length > 0) {
        const parts: Record<string, unknown>[] = [];
        if (!isPlaceholderAssistant(msg)) {
          parts.push({ text: msg.content });
        }
        for (const toolMsg of following) {
          parts.push({
            functionCall: {
              name: toolMsg.toolName ?? "tool",
              args: {},
            },
          });
        }
        if (parts.length === 0) {
          parts.push({
            functionCall: {
              name: following[0].toolName ?? "tool",
              args: {},
            },
          });
        }
        contents.push({ role: "model", parts });
        contents.push({
          role: "user",
          parts: following.map((toolMsg) => ({
            functionResponse: {
              name: toolMsg.toolName ?? "tool",
              response: parseFunctionResponse(toolMsg.content),
            },
          })),
        });
        i = j;
        continue;
      }
      contents.push({
        role: geminiRole(msg.role),
        parts: [{ text: msg.content }],
      });
      i += 1;
      continue;
    }
    contents.push({
      role: geminiRole(msg.role),
      parts: [{ text: msg.content }],
    });
    i += 1;
  }
  return contents;
}

export function buildGeminiGenerateContentBody(
  req: DestinaModelGenerateRequest,
): Record<string, unknown> {
  const contents = buildGeminiContents(req.messages);
  const body: Record<string, unknown> = {
    systemInstruction: { parts: [{ text: req.system }] },
    contents,
    generationConfig: {
      temperature: 0.4,
      maxOutputTokens: 1024,
    },
  };
  const functionDeclarations = toGeminiFunctionDeclarations(req.tools);
  if (functionDeclarations.length > 0) {
    body.tools = [{ functionDeclarations }];
  }
  return body;
}

function assertSafeLogEvent(event: GeminiLogEvent): GeminiLogEvent {
  const keys = Object.keys(event);
  for (const key of keys) {
    if (SECRET_LIKE.test(key)) {
      throw new Error("refusing to log a secret-bearing field");
    }
  }
  const serialized = JSON.stringify(event);
  if (/AIza[0-9A-Za-z_-]{8,}/.test(serialized) || /service_role/i.test(serialized)) {
    return {
      ...event,
      provider_message: "redacted_unsafe_provider_message",
    };
  }
  return event;
}

function defaultLog(event: GeminiLogEvent): void {
  console.warn(JSON.stringify(assertSafeLogEvent(event)));
}

export class GeminiDestinaProvider implements DestinaModelProvider {
  readonly provider = "gemini";
  readonly model: string;
  private readonly apiKey: string;
  private readonly fetchImpl: typeof fetch;
  private readonly log: GeminiLogger;

  constructor(opts: GeminiOpts, fetchImpl: typeof fetch = fetch) {
    this.apiKey = opts.apiKey;
    this.model = opts.model;
    this.fetchImpl = fetchImpl;
    this.log = opts.log ?? defaultLog;
  }

  async generate(
    req: DestinaModelGenerateRequest,
  ): Promise<DestinaModelGenerateResult> {
    const url = geminiGenerateContentUrl(this.model);
    const body = buildGeminiGenerateContentBody(req);

    let res: Response;
    try {
      res = await this.fetchImpl(url, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-goog-api-key": this.apiKey,
        },
        body: JSON.stringify(body),
      });
    } catch (e) {
      this.emitProviderError({
        http_status: 0,
        provider_status: "fetch_failed",
        provider_code: null,
        provider_message: sanitizeGeminiProviderMessage(
          e instanceof Error ? e.name : "fetch_failed",
        ),
      });
      throw new DestinaError(
        "model_unavailable",
        DESTINA_MODEL_UNAVAILABLE_MESSAGE,
        503,
      );
    }

    if (!res.ok) {
      let rawText = "";
      try {
        rawText = await res.text();
      } catch {
        rawText = "";
      }
      const parsed = parseGeminiErrorBody(rawText);
      this.emitProviderError({
        http_status: res.status,
        provider_status: parsed.provider_status,
        provider_code: parsed.provider_code,
        provider_message: parsed.provider_message,
      });
      throw new DestinaError(
        "model_unavailable",
        DESTINA_MODEL_UNAVAILABLE_MESSAGE,
        503,
      );
    }

    const json = await res.json() as Record<string, unknown>;
    const candidate = (json.candidates as Record<string, unknown>[] | undefined)
      ?.[0];
    const parts = ((candidate?.content as Record<string, unknown> | undefined)
      ?.parts as Record<string, unknown>[] | undefined) ?? [];

    const toolCalls: DestinaToolCall[] = [];
    const texts: string[] = [];
    let i = 0;
    for (const part of parts) {
      const fc = part.functionCall as Record<string, unknown> | undefined;
      if (fc && typeof fc.name === "string") {
        const args = (fc.args && typeof fc.args === "object")
          ? fc.args as Record<string, unknown>
          : {};
        toolCalls.push({
          id: `call_${i++}`,
          name: fc.name,
          arguments: args,
        });
      } else if (typeof part.text === "string" && part.text.trim()) {
        texts.push(part.text.trim());
      }
    }

    return {
      text: texts.join("\n").trim(),
      toolCalls,
    };
  }

  private emitProviderError(
    fields: Omit<GeminiLogEvent, "event" | "provider" | "model">,
  ): void {
    const event = assertSafeLogEvent({
      event: "destina_model_provider_error",
      provider: "gemini",
      model: this.model,
      ...fields,
    });
    try {
      this.log(event);
    } catch {
      // Logging must never change the client-facing failure.
    }
  }
}
