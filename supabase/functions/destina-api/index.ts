/**
 * M4 destina-api
 *
 * Flutter → destina-api → model (Gemini) → allowlisted Destiny tools.
 * LLM credentials stay server-side. Flutter never calls Gemini.
 *
 * Gateway: verify_jwt=false so logged-out discovery works.
 * Customer-owned tools still require a verified Supabase access token.
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import {
  extractBearerToken,
  verifySupabaseAccessToken,
} from "../customer-api/supabase_auth.ts";
import { TravelportFlightProvider } from "../flight-commerce-api/travelport_provider.ts";
import { sanitizeSearchRequest } from "../flight-commerce-api/flight_rules.ts";
import {
  DestinaError,
  DestinaTurnResponse,
} from "./destina_domain.ts";
import {
  applySeedContext,
  assertNoAuthoritativeClientFields,
  clampMessage,
  customerFacingToolError,
  DESTINA_LIMITS,
  emptyTripState,
  hashAnonSession,
  sanitizeAnonSessionId,
} from "./destina_rules.ts";
import {
  createDestinaModelProvider,
  ModelNotConfiguredError,
} from "./destina_model.ts";
import { runDestinaLoop } from "./destina_orchestrator.ts";
import { DestinaToolDeps } from "./destina_tools.ts";
import {
  getPublishedCatalogItem,
  searchPublishedCatalog,
} from "./destina_catalog.ts";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-destina-session",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function adminClient() {
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) throw new Error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
  return createClient(url, key, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

function errorJson(err: unknown): Response {
  if (err instanceof DestinaError) {
    const leaked = /IATA|airport codes must/i.test(err.message);
    return json(err.status, {
      status: "error",
      code: err.code,
      message: leaked ? customerFacingToolError(err) : err.message,
    });
  }
  console.warn(JSON.stringify({
    event: "destina_error",
    code: "internal_error",
  }));
  return json(500, {
    status: "error",
    code: "internal_error",
    message: "Destina hit a problem. Please try again.",
  });
}

function buildDeps(): DestinaToolDeps {
  const db = adminClient();
  const flights = new TravelportFlightProvider();
  return {
    searchFlights: async (body) => {
      const request = sanitizeSearchRequest(body);
      return await flights.search(request);
    },
    searchCatalog: (kind, query, limit) =>
      searchPublishedCatalog(db as never, kind, query, limit),
    getCatalogDetail: (kind, id) => getPublishedCatalogItem(db as never, kind, id),
    getProfile: async (userId) => {
      const { data } = await db
        .from("customer_profiles")
        .select("full_name, email, phone")
        .eq("user_id", userId)
        .maybeSingle();
      if (!data) return null;
      return {
        display_name: data.full_name ?? null,
        email: data.email ?? null,
      };
    },
    listBookings: async (userId) => {
      const { data } = await db
        .from("bookings")
        .select("id, status, payment_status, item_name, item_type, created_at")
        .eq("user_id", userId)
        .order("created_at", { ascending: false })
        .limit(20);
      return (data ?? []) as Record<string, unknown>[];
    },
    getBooking: async (userId, bookingId) => {
      const { data } = await db
        .from("bookings")
        .select("id, status, payment_status, item_name, item_type, quoted_total, currency, created_at")
        .eq("user_id", userId)
        .eq("id", bookingId)
        .maybeSingle();
      return data as Record<string, unknown> | null;
    },
    createEnquiry: async ({ userId, kind, payload }) => {
      const { data: profile } = await db
        .from("customer_profiles")
        .select("id")
        .eq("user_id", userId)
        .maybeSingle();
      const { data, error } = await db
        .from("enquiries")
        .insert({
          kind,
          user_id: userId,
          customer_profile_id: profile?.id ?? null,
          payload,
          status: "received",
        })
        .select("id, status")
        .single();
      if (error) throw error;
      await db.from("enquiry_events").insert({
        enquiry_id: data.id,
        event_type: "received",
        previous_status: null,
        new_status: "received",
        actor_type: "customer",
        actor_user_id: userId,
        metadata: { source: "destina", kind },
      });
      return { id: data.id as string, status: data.status as string };
    },
  };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json(405, { status: "error", message: "POST required" });
  }

  try {
    const body = (await req.json().catch(() => ({}))) as Record<string, unknown>;
    assertNoAuthoritativeClientFields(body);
    const action = String(body.action ?? "chat");

    const sessionRaw = req.headers.get("x-destina-session") ??
      body.anon_session_id;
    const sessionId = sanitizeAnonSessionId(sessionRaw);
    const sessionHash = await hashAnonSession(sessionId);

    const token = extractBearerToken(req);
    let user: { id: string; email: string | null; name: string | null } | null =
      null;
    if (token) {
      try {
        user = await verifySupabaseAccessToken(token);
      } catch {
        return json(401, {
          status: "error",
          code: "unauthorized",
          message: "Your session expired. Please sign in again.",
        });
      }
    }

    const db = adminClient();

    if (action !== "chat" && action !== "get_conversation") {
      return json(400, { status: "error", message: `Unknown action '${action}'` });
    }

    let conversationId = typeof body.conversation_id === "string"
      ? body.conversation_id
      : null;
    let tripState = emptyTripState();

    if (conversationId) {
      const { data: conv, error } = await db
        .from("destina_conversations")
        .select("id, user_id, anon_session_hash, trip_state, status")
        .eq("id", conversationId)
        .maybeSingle();
      if (error) throw error;
      if (!conv) {
        return json(404, {
          status: "error",
          code: "not_found",
          message: "I couldn't find that Destina conversation.",
        });
      }
      const ownedByUser = user && conv.user_id === user.id;
      const ownedByAnon = !conv.user_id && conv.anon_session_hash === sessionHash;
      const claimable = user && !conv.user_id && conv.anon_session_hash === sessionHash;
      if (!ownedByUser && !ownedByAnon && !claimable) {
        return json(403, {
          status: "error",
          code: "forbidden",
          message: "That Destina conversation belongs to another session.",
        });
      }
      if (claimable) {
        await db.from("destina_conversations").update({ user_id: user!.id }).eq(
          "id",
          conv.id,
        );
      }
      conversationId = conv.id;
      tripState = { ...emptyTripState(), ...(conv.trip_state as object) };
    } else {
      const insert = {
        user_id: user?.id ?? null,
        anon_session_hash: sessionHash,
        status: "active",
        trip_state: tripState,
      };
      const { data, error } = await db
        .from("destina_conversations")
        .insert(insert)
        .select("id")
        .single();
      if (error) throw error;
      conversationId = data.id as string;
      await db.from("destina_events").insert({
        conversation_id: conversationId,
        event_type: "started",
        actor_type: user ? "customer" : "anonymous",
        actor_user_id: user?.id ?? null,
        metadata: { model_provider: Deno.env.get("DESTINA_MODEL_PROVIDER") ?? "gemini" },
      });
    }

    const seed = body.seed_context && typeof body.seed_context === "object"
      ? body.seed_context as Record<string, unknown>
      : null;
    tripState = applySeedContext(tripState, seed);

    if (action === "get_conversation") {
      const { data: msgs } = await db
        .from("destina_messages")
        .select("role, content, metadata, created_at")
        .eq("conversation_id", conversationId)
        .order("created_at", { ascending: true })
        .limit(DESTINA_LIMITS.maxHistoryMessages);
      return json(200, {
        status: "success",
        data: {
          conversation_id: conversationId,
          trip_state: tripState,
          messages: msgs ?? [],
        },
      });
    }

    const userMessage = clampMessage(body.message ?? body.content);
    await db.from("destina_messages").insert({
      conversation_id: conversationId,
      role: "user",
      content: userMessage,
      metadata: seed ? { seed_context: seed } : {},
    });

    const { data: historyRows } = await db
      .from("destina_messages")
      .select("role, content")
      .eq("conversation_id", conversationId)
      .in("role", ["user", "assistant"])
      .order("created_at", { ascending: true })
      .limit(DESTINA_LIMITS.maxHistoryMessages);

    const history = (historyRows ?? [])
      .slice(0, -1)
      .map((m) => ({
        role: m.role as "user" | "assistant",
        content: String(m.content ?? ""),
      }));

    let model;
    try {
      model = createDestinaModelProvider();
    } catch (e) {
      if (e instanceof ModelNotConfiguredError ||
        (e instanceof DestinaError && e.code === "model_not_configured")) {
        const content = e instanceof DestinaError
          ? e.message
          : "Destina isn't connected to a language model yet.";
        await db.from("destina_messages").insert({
          conversation_id: conversationId,
          role: "assistant",
          content,
          metadata: { code: "model_not_configured" },
        });
        const payload: DestinaTurnResponse = {
          conversation_id: conversationId,
          message: { role: "assistant", content },
          trip_state: tripState,
          tool_results: [],
          suggested_actions: [{ id: "handoff", label: "Leave a note for our team" }],
          handoff: null,
          auth_required: false,
          model: { provider: "none", name: "none", configured: false },
        };
        return json(503, {
          status: "error",
          code: "model_not_configured",
          message: content,
          data: payload,
        });
      }
      throw e;
    }

    const started = Date.now();
    const output = await runDestinaLoop({
      model,
      deps: buildDeps(),
      actor: {
        userId: user?.id ?? null,
        displayName: user?.name ?? null,
        email: user?.email ?? null,
      },
      conversationId,
      tripState,
      history,
      userMessage,
    });

    const convPatch: Record<string, unknown> = {
      trip_state: output.tripState,
    };
    if (output.response.handoff?.created) {
      convPatch.last_enquiry_id = output.response.handoff.enquiry_id ?? null;
      convPatch.last_handoff_at = new Date().toISOString();
      convPatch.status = "handed_off";
    }
    await db.from("destina_conversations").update(convPatch).eq("id", conversationId);

    const { data: assistantRow } = await db.from("destina_messages").insert({
      conversation_id: conversationId,
      role: "assistant",
      content: output.assistantContent,
      metadata: {
        tool_names: output.toolRuns.map((t) => t.name),
        auth_required: output.response.auth_required,
      },
    }).select("id").single();

    for (const run of output.toolRuns) {
      await db.from("destina_tool_runs").insert({
        conversation_id: conversationId,
        message_id: assistantRow?.id ?? null,
        tool_name: run.name,
        arguments: {},
        result_summary: {
          status: run.status,
          summary: run.summary,
          error_code: run.error_code ?? null,
        },
        status: run.status,
        error_code: run.error_code ?? null,
        duration_ms: Date.now() - started,
      });
    }

    await db.from("destina_events").insert({
      conversation_id: conversationId,
      event_type: "turn",
      actor_type: user ? "customer" : "anonymous",
      actor_user_id: user?.id ?? null,
      metadata: {
        model_provider: model.provider,
        model: model.model,
        tools: output.toolRuns.map((t) => ({ name: t.name, status: t.status })),
        latency_ms: Date.now() - started,
        handoff: Boolean(output.response.handoff?.created),
        enquiry_id: output.response.handoff?.enquiry_id ?? null,
      },
    });

    return json(200, { status: "success", data: output.response });
  } catch (err) {
    return errorJson(err);
  }
});
