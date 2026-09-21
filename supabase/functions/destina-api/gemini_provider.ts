/**
 * Gemini Destina adapter (Gemini 2.5 Flash by default).
 * Credentials stay server-side. Never log the API key.
 */

import {
  DestinaError,
  DestinaModelGenerateRequest,
  DestinaModelGenerateResult,
  DestinaToolCall,
} from "./destina_domain.ts";
import { DestinaModelProvider } from "./destina_domain.ts";

type GeminiOpts = { apiKey: string; model: string };

function geminiRole(role: string): "user" | "model" {
  return role === "assistant" || role === "model" ? "model" : "user";
}

export class GeminiDestinaProvider implements DestinaModelProvider {
  readonly provider = "gemini";
  readonly model: string;
  private readonly apiKey: string;
  private readonly fetchImpl: typeof fetch;

  constructor(opts: GeminiOpts, fetchImpl: typeof fetch = fetch) {
    this.apiKey = opts.apiKey;
    this.model = opts.model;
    this.fetchImpl = fetchImpl;
  }

  async generate(
    req: DestinaModelGenerateRequest,
  ): Promise<DestinaModelGenerateResult> {
    const url =
      `https://generativelanguage.googleapis.com/v1beta/models/${this.model}:generateContent`;
    const contents: Record<string, unknown>[] = [];
    for (const msg of req.messages) {
      if (msg.role === "tool") {
        contents.push({
          role: "user",
          parts: [{
            functionResponse: {
              name: msg.toolName ?? "tool",
              response: { result: msg.content },
            },
          }],
        });
        continue;
      }
      if (msg.role === "system") continue;
      contents.push({
        role: geminiRole(msg.role),
        parts: [{ text: msg.content }],
      });
    }

    const body = {
      system_instruction: { parts: [{ text: req.system }] },
      contents,
      tools: [{
        functionDeclarations: req.tools.map((t) => ({
          name: t.name,
          description: t.description,
          parameters: t.parameters,
        })),
      }],
      generationConfig: {
        temperature: 0.4,
        maxOutputTokens: 1024,
      },
    };

    const res = await this.fetchImpl(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-goog-api-key": this.apiKey,
      },
      body: JSON.stringify(body),
    });

    if (!res.ok) {
      throw new DestinaError(
        "model_unavailable",
        "I couldn't reach Destina's language model just now. I can try again, or send this to our travel team.",
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
}
