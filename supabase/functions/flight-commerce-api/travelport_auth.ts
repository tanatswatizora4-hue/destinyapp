/**
 * Server-side Travelport TripServices OAuth client.
 *
 * Official flow (developer.travelport.com/docs/getting-started/authentication):
 *   POST https://auth.pp.travelport.net/oauth/token   (pre-production)
 *   POST https://auth.travelport.net/oauth/token      (production)
 *   grant_type=password + username + password + client_id + client_secret
 *   Token validity: 86,400 seconds. Cache and reuse; do not auth per search.
 *
 * Never logs credentials or access tokens.
 */

import { FlightProviderError } from "./flight_domain.ts";

export type FetchLike = (
  input: string | URL | Request,
  init?: RequestInit,
) => Promise<Response>;

export type TravelportToken = {
  accessToken: string;
  expiresAtMs: number;
  tokenType: string;
};

export type TravelportAuthConfig = {
  clientId: string;
  clientSecret: string;
  username: string;
  password: string;
  tokenUrl: string;
};

const SKEW_MS = 60_000;
const AUTH_TIMEOUT_MS = 15_000;

let cached: TravelportToken | null = null;

export function resetTravelportTokenCache(): void {
  cached = null;
}

export function travelportEnvName(): "pp" | "prod" {
  const raw = (Deno.env.get("TRAVELPORT_ENV") ?? "pp").trim().toLowerCase();
  return raw === "prod" || raw === "production" ? "prod" : "pp";
}

export function travelportTokenUrl(env = travelportEnvName()): string {
  return env === "prod"
    ? "https://auth.travelport.net/oauth/token"
    : "https://auth.pp.travelport.net/oauth/token";
}

export function travelportAirBaseUrl(env = travelportEnvName()): string {
  return env === "prod"
    ? "https://api.travelport.net/11/air/"
    : "https://api.pp.travelport.net/11/air/";
}

export function readTravelportAuthConfig(): TravelportAuthConfig | null {
  const clientId = Deno.env.get("TRAVELPORT_CLIENT_ID")?.trim() ?? "";
  const clientSecret = Deno.env.get("TRAVELPORT_CLIENT_SECRET")?.trim() ?? "";
  const username = Deno.env.get("TRAVELPORT_USERNAME")?.trim() ?? "";
  const password = Deno.env.get("TRAVELPORT_PASSWORD")?.trim() ?? "";
  if (!clientId || !clientSecret || !username || !password) return null;
  return {
    clientId,
    clientSecret,
    username,
    password,
    tokenUrl: Deno.env.get("TRAVELPORT_TOKEN_URL")?.trim() ||
      travelportTokenUrl(),
  };
}

export function travelportConfigured(): boolean {
  return readTravelportAuthConfig() !== null &&
    Boolean(
      Deno.env.get("TRAVELPORT_ACCESS_GROUP")?.trim() ||
        Deno.env.get("TRAVELPORT_PCC_CORE")?.trim(),
    );
}

export async function getTravelportAccessToken(
  fetchImpl: FetchLike = fetch,
  nowMs: number = Date.now(),
): Promise<string> {
  if (cached && cached.expiresAtMs - SKEW_MS > nowMs) {
    return cached.accessToken;
  }
  cached = await authenticateTravelport(fetchImpl);
  return cached.accessToken;
}

export async function authenticateTravelport(
  fetchImpl: FetchLike = fetch,
  cfg: TravelportAuthConfig | null = readTravelportAuthConfig(),
): Promise<TravelportToken> {
  if (!cfg) {
    throw new FlightProviderError(
      "not_configured",
      "Travelport credentials are not configured",
    );
  }

  const body = new URLSearchParams({
    grant_type: "password",
    username: cfg.username,
    password: cfg.password,
    client_id: cfg.clientId,
    client_secret: cfg.clientSecret,
  });

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), AUTH_TIMEOUT_MS);
  let res: Response;
  try {
    res = await fetchImpl(cfg.tokenUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
        Accept: "application/json",
      },
      body,
      signal: controller.signal,
    });
  } catch (e) {
    if ((e as Error).name === "AbortError") {
      throw new FlightProviderError(
        "provider_timeout",
        "Travelport authentication timed out",
        { retryable: true },
      );
    }
    throw new FlightProviderError(
      "provider_unavailable",
      "Travelport authentication is unavailable",
      { retryable: true },
    );
  } finally {
    clearTimeout(timer);
  }

  if (!res.ok) {
    throw new FlightProviderError(
      "auth_failed",
      "Travelport authentication failed",
      { httpStatus: 502 },
    );
  }

  let json: Record<string, unknown>;
  try {
    json = await res.json() as Record<string, unknown>;
  } catch {
    throw new FlightProviderError(
      "malformed_response",
      "Travelport authentication returned a malformed response",
    );
  }

  const accessToken = String(json.access_token ?? "").trim();
  if (!accessToken) {
    throw new FlightProviderError(
      "auth_failed",
      "Travelport authentication did not return a token",
    );
  }
  const expiresIn = Number(json.expires_in ?? 86400);
  const ttl = Number.isFinite(expiresIn) && expiresIn > 0 ? expiresIn : 86400;
  return {
    accessToken,
    tokenType: String(json.token_type ?? "Bearer"),
    expiresAtMs: Date.now() + ttl * 1000,
  };
}

export function invalidateTravelportToken(): void {
  cached = null;
}
