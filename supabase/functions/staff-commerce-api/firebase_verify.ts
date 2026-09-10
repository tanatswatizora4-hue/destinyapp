/**
 * Verify Firebase ID tokens using Google's JWKS.
 */

import * as jose from "https://deno.land/x/jose@v5.9.6/index.ts";

const DEFAULT_PROJECT_ID = "destinytravel-1a16e";

const JWKS = jose.createRemoteJWKSet(
  new URL(
    "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com",
  ),
);

export type VerifiedFirebaseUser = {
  uid: string;
  email: string | null;
  name: string | null;
};

export function firebaseProjectId(): string {
  return Deno.env.get("FIREBASE_PROJECT_ID")?.trim() || DEFAULT_PROJECT_ID;
}

export function extractBearerToken(req: Request): string | null {
  const auth = req.headers.get("Authorization") ??
    req.headers.get("authorization");
  if (!auth) return null;
  const m = auth.match(/^Bearer\s+(.+)$/i);
  return m?.[1]?.trim() || null;
}

export async function verifyFirebaseIdToken(
  token: string,
  projectId: string = firebaseProjectId(),
): Promise<VerifiedFirebaseUser> {
  const { payload } = await jose.jwtVerify(token, JWKS, {
    issuer: `https://securetoken.google.com/${projectId}`,
    audience: projectId,
  });
  const uid = typeof payload.sub === "string" ? payload.sub : "";
  if (!uid) throw new Error("Firebase token missing subject");
  return {
    uid,
    email: typeof payload.email === "string" ? payload.email : null,
    name: typeof payload.name === "string" ? payload.name : null,
  };
}
