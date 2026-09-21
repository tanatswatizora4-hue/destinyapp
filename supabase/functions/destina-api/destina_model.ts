/**
 * Provider-neutral Destina model factory.
 */

import { DestinaError, DestinaModelProvider } from "./destina_domain.ts";
import { DESTINA_LIMITS, EnvLike, isMockModelAllowed } from "./destina_rules.ts";
import { GeminiDestinaProvider } from "./gemini_provider.ts";
import { ScriptedDestinaProvider } from "./mock_provider.ts";

export type { DestinaModelProvider } from "./destina_domain.ts";

export class ModelNotConfiguredError extends DestinaError {
  constructor() {
    super(
      "model_not_configured",
      "Destina isn't connected to a language model yet. I can still take a note for our travel team once that's enabled.",
      503,
    );
  }
}

export function withTimeout<T>(
  promise: Promise<T>,
  ms: number = DESTINA_LIMITS.modelTimeoutMs,
): Promise<T> {
  return new Promise((resolve, reject) => {
    const t = setTimeout(() => {
      reject(
        new DestinaError(
          "model_timeout",
          "I couldn't finish that just now. I can try again, or I can send this to our travel team.",
          504,
        ),
      );
    }, ms);
    promise.then(
      (v) => {
        clearTimeout(t);
        resolve(v);
      },
      (e) => {
        clearTimeout(t);
        reject(e);
      },
    );
  });
}

export function createDestinaModelProvider(
  env: EnvLike = Deno.env.toObject(),
): DestinaModelProvider {
  const provider = (env.DESTINA_MODEL_PROVIDER ?? "gemini").trim().toLowerCase();
  const model = (env.DESTINA_MODEL ?? "gemini-2.5-flash").trim() ||
    "gemini-2.5-flash";
  const key = (env.DESTINA_API_KEY ?? "").trim();

  if (provider === "mock") {
    if (!isMockModelAllowed(env)) {
      throw new DestinaError(
        "mock_disabled",
        "The Destina mock model is not allowed in this environment.",
        403,
      );
    }
    return new ScriptedDestinaProvider(model);
  }

  if (provider === "gemini") {
    if (!key) throw new ModelNotConfiguredError();
    return new GeminiDestinaProvider({ apiKey: key, model });
  }

  throw new DestinaError(
    "model_not_configured",
    `Unknown Destina model provider '${provider}'`,
    503,
  );
}
