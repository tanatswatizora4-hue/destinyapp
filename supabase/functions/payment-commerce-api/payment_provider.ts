/**
 * Provider registry. Real adapters stay placeholders until official docs exist.
 */

import {
  PaymentError,
  PaymentProvider,
} from "./payment_domain.ts";
import { MockPaymentProvider } from "./mock_provider.ts";
import { PaynowPaymentProvider } from "./paynow_provider.ts";
import { ToomaPaymentProvider } from "./tooma_provider.ts";
import { ZimswitchPaymentProvider } from "./zimswitch_provider.ts";
import { EnvLike, isMockProviderAllowed } from "./payment_rules.ts";

export function resolvePaymentProvider(
  name: string,
  env: EnvLike,
): PaymentProvider {
  const n = (name || "mock").trim().toLowerCase();
  if (n === "mock") {
    if (!isMockProviderAllowed(env)) {
      throw new PaymentError(
        "mock_disabled",
        "Mock payment provider is disabled outside explicit non-production QA",
        409,
      );
    }
    return new MockPaymentProvider();
  }
  if (n === "zimswitch") return new ZimswitchPaymentProvider();
  if (n === "tooma" || n === "tooma_pay" || n === "toomapay") {
    return new ToomaPaymentProvider();
  }
  if (n === "paynow") return new PaynowPaymentProvider();
  throw new PaymentError(
    "unknown_provider",
    `Unknown payment provider '${name}'`,
    400,
  );
}

export function readProviderEnv(env: EnvLike): EnvLike {
  return env;
}
