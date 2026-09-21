/**
 * Gemini Destina adapter (Gemini 3.6 Flash by default).
 * Credentials stay server-side. Never log the API key, auth headers, or thought signatures.
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

export const DESTINA_MODEL_TIMEOUT_MESSAGE =
  "I couldn't finish that just now. I can try again, or I can send this to our travel team.";

export type GeminiLogEvent = {
  event: "destina_model_provider_error";
  request_id?: string;
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
  requestId?: string;
  onRetry?: (info: { reason: string; retry_number: number }) => void;
  maxRetries?: number;
  retryBackoffMs?: number;
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
  s = s.replace(/"thoughtSignature"\s*:\s*"[^"]*"/g, '"thoughtSignature":"[redacted]"');
  s = s.replace(/"thought_signature"\s*:\s*"[^"]*"/g, '"thought_signature":"[redacted]"');
  s = s.replace(
    /thought[_-]?signature["'\s:=]+[A-Za-z0-9+/=._-]{12,}/gi,
    "thought_signature=[redacted]",
  );
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

function cloneOpaqueParts(parts: unknown[]): unknown[] {
  return JSON.parse(JSON.stringify(parts)) as unknown[];
}

function asRecord(value: unknown): Record<string, unknown> | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  return value as Record<string, unknown>;
}

function partFunctionCall(part: unknown): Record<string, unknown> | null {
  const rec = asRecord(part);
  if (!rec) return null;
  return asRecord(rec.functionCall) ?? asRecord(rec.function_call);
}

function isGeminiProviderTurn(
  turn: DestinaChatMessage["providerTurn"],
): turn is { provider: string; parts: unknown[] } {
  return Boolean(
    turn &&
      turn.provider === "gemini" &&
      Array.isArray(turn.parts) &&
      turn.parts.length > 0,
  );
}

function functionResponsesFor(
  toolMsgs: DestinaChatMessage[],
  modelParts: unknown[],
): Record<string, unknown>[] {
  const calls = modelParts.map(partFunctionCall).filter((fc): fc is Record<string, unknown> =>
    Boolean(fc && typeof fc.name === "string")
  );
  return toolMsgs.map((toolMsg, idx) => {
    const fc = calls[idx];
    const name = toolMsg.toolName ??
      (typeof fc?.name === "string" ? fc.name : "tool");
    const fr: Record<string, unknown> = {
      name,
      response: parseFunctionResponse(toolMsg.content),
    };
    if (typeof fc?.id === "string" && fc.id) fr.id = fc.id;
    return { functionResponse: fr };
  });
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
      throw new DestinaError(
        "model_unavailable",
        DESTINA_MODEL_UNAVAILABLE_MESSAGE,
        503,
      );
    }
    if (msg.role === "assistant") {
      const following: DestinaChatMessage[] = [];
      let j = i + 1;
      while (j < messages.length && messages[j].role === "tool") {
        following.push(messages[j]);
        j += 1;
      }
      if (following.length > 0) {
        if (!isGeminiProviderTurn(msg.providerTurn)) {
          throw new DestinaError(
            "model_unavailable",
            DESTINA_MODEL_UNAVAILABLE_MESSAGE,
            503,
          );
        }
        contents.push({
          role: "model",
          parts: cloneOpaqueParts(msg.providerTurn.parts),
        });
        contents.push({
          role: "user",
          parts: functionResponsesFor(following, msg.providerTurn.parts),
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
  private readonly requestId?: string;
  private readonly onRetry?: (info: { reason: string; retry_number: number }) => void;
  private readonly maxRetries: number;
  private readonly retryBackoffMs: number;

  constructor(opts: GeminiOpts, fetchImpl: typeof fetch = fetch) {
    this.apiKey = opts.apiKey;
    this.model = opts.model;
    this.fetchImpl = fetchImpl;
    this.log = opts.log ?? defaultLog;
    this.requestId = opts.requestId;
    this.onRetry = opts.onRetry;
    this.maxRetries = opts.maxRetries ?? 1;
    this.retryBackoffMs = opts.retryBackoffMs ?? 400;
  }

  async generate(
    req: DestinaModelGenerateRequest,
  ): Promise<DestinaModelGenerateResult> {
    const url = geminiGenerateContentUrl(this.model);
    let body: Record<string, unknown>;
    try {
      body = buildGeminiGenerateContentBody(req);
    } catch (e) {
      this.emitProviderError({
        http_status: 0,
        provider_status: "missing_provider_continuation",
        provider_code: null,
        provider_message: "function_call continuation missing",
      });
      if (e instanceof DestinaError) {
        throw new DestinaError(
          e.code === "model_unavailable" ? "missing_provider_continuation" : e.code,
          DESTINA_MODEL_UNAVAILABLE_MESSAGE,
          503,
          "model",
        );
      }
      throw new DestinaError(
        "missing_provider_continuation",
        DESTINA_MODEL_UNAVAILABLE_MESSAGE,
        503,
        "model",
      );
    }

    let attempt = 0;
    while (true) {
      try {
        return await this.generateOnce(url, body);
      } catch (e) {
        if (!(e instanceof DestinaError) || !isRetryableModelError(e)) {
          throw e;
        }
        if (attempt >= this.maxRetries) throw e;
        attempt += 1;
        try {
          this.onRetry?.({ reason: e.code, retry_number: attempt });
        } catch {
          // ignore
        }
        await sleep(this.retryBackoffMs + Math.floor(Math.random() * 200));
      }
    }
  }

  private async generateOnce(
    url: string,
    body: Record<string, unknown>,
  ): Promise<DestinaModelGenerateResult> {
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
        "model_network_error",
        DESTINA_MODEL_UNAVAILABLE_MESSAGE,
        503,
        "model",
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
      throw classifyHttpModelError(res.status);
    }

    const json = await res.json() as Record<string, unknown>;
    const candidate = (json.candidates as Record<string, unknown>[] | undefined)
      ?.[0];
    const rawParts = ((candidate?.content as Record<string, unknown> | undefined)
      ?.parts as unknown[] | undefined) ?? [];
    const continuationParts = cloneOpaqueParts(rawParts);

    const toolCalls: DestinaToolCall[] = [];
    const texts: string[] = [];
    let i = 0;
    for (const part of rawParts) {
      const rec = asRecord(part);
      if (!rec) continue;
      if (rec.thought === true) continue;
      const fc = partFunctionCall(part);
      if (fc && typeof fc.name === "string") {
        const args = (fc.args && typeof fc.args === "object")
          ? fc.args as Record<string, unknown>
          : {};
        const providerId = typeof fc.id === "string" && fc.id ? fc.id : "";
        toolCalls.push({
          id: providerId || `call_${i++}`,
          name: fc.name,
          arguments: args,
        });
      } else if (typeof rec.text === "string" && rec.text.trim()) {
        texts.push(rec.text.trim());
      }
    }

    return {
      text: texts.join("\n").trim(),
      toolCalls,
      providerTurn: toolCalls.length > 0
        ? { provider: "gemini", parts: continuationParts }
        : undefined,
    };
  }

  private emitProviderError(
    fields: Omit<GeminiLogEvent, "event" | "provider" | "model" | "request_id">,
  ): void {
    const event = assertSafeLogEvent({
      event: "destina_model_provider_error",
      request_id: this.requestId,
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

function classifyHttpModelError(status: number): DestinaError {
  if (status === 429) {
    return new DestinaError("model_429", DESTINA_MODEL_UNAVAILABLE_MESSAGE, 503, "model");
  }
  if (status === 401 || status === 403) {
    return new DestinaError("model_auth_error", DESTINA_MODEL_UNAVAILABLE_MESSAGE, 503, "model");
  }
  if (status === 400) {
    return new DestinaError(
      "model_invalid_argument",
      DESTINA_MODEL_UNAVAILABLE_MESSAGE,
      503,
      "model",
    );
  }
  if (status >= 500) {
    return new DestinaError("model_5xx", DESTINA_MODEL_UNAVAILABLE_MESSAGE, 503, "model");
  }
  return new DestinaError("model_unavailable", DESTINA_MODEL_UNAVAILABLE_MESSAGE, 503, "model");
}

function isRetryableModelError(err: DestinaError): boolean {
  return err.code === "model_429" ||
    err.code === "model_5xx" ||
    err.code === "model_network_error";
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
