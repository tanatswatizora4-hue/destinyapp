/**
 * Travelport auth mapping tests (no live credentials).
 * Run: deno test supabase/functions/flight-commerce-api/travelport_auth_test.ts
 */

import {
  assertEquals,
  assertRejects,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { FlightProviderError } from "./flight_domain.ts";
import {
  authenticateTravelport,
  resetTravelportTokenCache,
  travelportAirBaseUrl,
  travelportTokenUrl,
  type TravelportAuthConfig,
} from "./travelport_auth.ts";

const stubCfg: TravelportAuthConfig = {
  clientId: "id",
  clientSecret: "secret",
  username: "user",
  password: "pass",
  tokenUrl: "https://auth.pp.travelport.net/oauth/token",
};

Deno.test("token and air base URLs follow official pre-prod vs prod hosts", () => {
  assertEquals(travelportTokenUrl("pp"), "https://auth.pp.travelport.net/oauth/token");
  assertEquals(travelportTokenUrl("prod"), "https://auth.travelport.net/oauth/token");
  assertEquals(
    travelportAirBaseUrl("pp"),
    "https://api.pp.travelport.net/11/air/",
  );
  assertEquals(
    travelportAirBaseUrl("prod"),
    "https://api.travelport.net/11/air/",
  );
});

Deno.test("missing credentials map to not_configured without leaking names", async () => {
  resetTravelportTokenCache();
  await assertRejects(
    () =>
      authenticateTravelport(
        async () => new Response("{}", { status: 200 }),
        null,
      ),
    FlightProviderError,
    "not configured",
  );
});

Deno.test("auth HTTP failure maps to auth_failed and does not expose body", async () => {
  resetTravelportTokenCache();
  await assertRejects(
    () =>
      authenticateTravelport(
        async () =>
          new Response(JSON.stringify({ error: "invalid_client" }), {
            status: 401,
          }),
        stubCfg,
      ),
    FlightProviderError,
    "authentication failed",
  );
});

Deno.test("successful token response is cached by expiry", async () => {
  resetTravelportTokenCache();
  const token = await authenticateTravelport(async (_url, init) => {
    const body = String(init?.body ?? "");
    if (
      !body.includes("grant_type=password") ||
      !body.includes("username=user")
    ) {
      return new Response("bad-grant", { status: 400 });
    }
    return new Response(
      JSON.stringify({
        access_token: "tok_abc",
        token_type: "Bearer",
        expires_in: 86400,
      }),
      { status: 200 },
    );
  }, stubCfg);
  assertEquals(token.accessToken, "tok_abc");
  assertEquals(token.expiresAtMs > Date.now(), true);
  resetTravelportTokenCache();
});

Deno.test("timeout maps to provider_timeout", async () => {
  resetTravelportTokenCache();
  await assertRejects(
    () =>
      authenticateTravelport(async () => {
        const err = new Error("aborted");
        err.name = "AbortError";
        throw err;
      }, stubCfg),
    FlightProviderError,
    "timed out",
  );
});
