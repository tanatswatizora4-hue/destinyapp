/**
 * Verify Supabase Auth access tokens server-side.
 *
 * Prefer gateway verify_jwt=true; still call auth.getUser(token) so identity
 * is derived from a trusted Supabase Auth check, never from the request body.
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

export type VerifiedSupabaseUser = {
  id: string;
  email: string | null;
  name: string | null;
};

export function extractBearerToken(req: Request): string | null {
  const auth = req.headers.get("Authorization") ??
    req.headers.get("authorization");
  if (!auth) return null;
  const m = auth.match(/^Bearer\s+(.+)$/i);
  return m?.[1]?.trim() || null;
}

function authClient() {
  const url = Deno.env.get("SUPABASE_URL");
  const anon = Deno.env.get("SUPABASE_ANON_KEY");
  if (!url || !anon) {
    throw new Error("Missing SUPABASE_URL or SUPABASE_ANON_KEY");
  }
  return createClient(url, anon, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

/** Verifies the bearer access token via Supabase Auth Admin getUser. */
export async function verifySupabaseAccessToken(
  token: string,
): Promise<VerifiedSupabaseUser> {
  const { data, error } = await authClient().auth.getUser(token);
  if (error || !data.user) {
    throw new Error(error?.message ?? "Invalid or expired Supabase session");
  }
  const user = data.user;
  const meta = (user.user_metadata ?? {}) as Record<string, unknown>;
  const name = typeof meta.full_name === "string"
    ? meta.full_name
    : typeof meta.name === "string"
    ? meta.name
    : null;
  return {
    id: user.id,
    email: user.email ?? null,
    name,
  };
}
