/**
 * M3C flight-commerce-api
 *
 * Flutter → Destiny flight Edge Function → provider-neutral service → Travelport.
 *
 * Public (no JWT): search_flights, next_leg_search, validate_offer
 * Authenticated: create_flight_enquiry
 *
 * Gateway: verify_jwt=false (root supabase/config.toml) so logged-out search works.
 * Customer-owned writes still call auth.getUser(token).
 *
 * Never trusts client user_id / role / price. Never returns provider tokens.
 * Ticketing / paid booking is not implemented.
 *
 * Deploy:
 *   supabase functions deploy flight-commerce-api --project-ref xchddfpfzrzhlbbmyhyn
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import {
  FlightProviderError,
  searchResultToApi,
  validationToApi,
} from "./flight_domain.ts";
import {
  assertNoAuthoritativeClientFields,
  sanitizeOfferSelection,
  sanitizeOfferSelections,
  sanitizeSearchRequest,
} from "./flight_rules.ts";
import {
  extractBearerToken,
  verifySupabaseAccessToken,
} from "./supabase_auth.ts";
import { TravelportFlightProvider } from "./travelport_provider.ts";
import { travelportConfigured } from "./travelport_auth.ts";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-correlation-id",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type Action =
  | "search_flights"
  | "next_leg_search"
  | "validate_offer"
  | "create_flight_enquiry";

const PUBLIC_ACTIONS: ReadonlySet<string> = new Set([
  "search_flights",
  "next_leg_search",
  "validate_offer",
]);

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function errorJson(err: unknown): Response {
  if (err instanceof FlightProviderError) {
    return json(err.httpStatus, {
      status: "error",
      code: err.code,
      message: err.message,
      retryable: err.retryable,
    });
  }
  return json(500, {
    status: "error",
    code: "internal_error",
    message: "Flight commerce failed",
  });
}

function adminClient() {
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) {
    throw new Error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
  }
  return createClient(url, key, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

function offerToSnapshot(
  offer: Parameters<typeof validationToApi>[0]["offer"],
): Record<string, unknown> {
  return validationToApi({
    offer,
    priceChanged: false,
    previousPrice: null,
    expired: false,
  }).offer as Record<string, unknown>;
}

function routeLabel(origin: string, destination: string): string {
  return `${origin} → ${destination}`;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json(405, { status: "error", message: "POST required" });
  }

  const correlationId = req.headers.get("x-correlation-id") ??
    crypto.randomUUID();

  try {
    const body = (await req.json().catch(() => ({}))) as Record<
      string,
      unknown
    >;
    const action = String(body.action ?? "") as Action;
    if (!action) {
      return json(400, { status: "error", message: "action is required" });
    }

    try {
      assertNoAuthoritativeClientFields(body);
    } catch (e) {
      return errorJson(e);
    }

    const provider = new TravelportFlightProvider();

    switch (action) {
      case "search_flights": {
        const request = sanitizeSearchRequest(body);
        if (!travelportConfigured()) {
          return json(503, {
            status: "error",
            code: "not_configured",
            message:
              "Flight shopping is not configured yet. Destiny can still take an enquiry.",
          });
        }
        const result = await provider.search(request);
        console.log(
          JSON.stringify({
            event: "flight_search",
            correlationId,
            origin: request.origin,
            destination: request.destination,
            tripType: request.tripType,
            offerCount: result.offers.length,
          }),
        );
        return json(200, {
          status: "success",
          data: searchResultToApi(result),
          correlation_id: correlationId,
        });
      }

      case "next_leg_search": {
        const selection = sanitizeOfferSelection(body);
        const result = await provider.nextLeg(selection);
        return json(200, {
          status: "success",
          data: searchResultToApi(result),
          correlation_id: correlationId,
        });
      }

      case "validate_offer": {
        const selections = sanitizeOfferSelections(body);
        const previous = body.displayed_amount != null
          ? {
            amount: Number(body.displayed_amount),
            currency: String(body.displayed_currency ?? "USD"),
          }
          : null;
        const previousPrice =
          previous && Number.isFinite(previous.amount) && previous.amount >= 0
            ? previous
            : null;
        const validation = await provider.validateOffer(
          selections,
          previousPrice,
        );
        return json(200, {
          status: "success",
          data: validationToApi(validation),
          correlation_id: correlationId,
        });
      }

      case "create_flight_enquiry": {
        const token = extractBearerToken(req);
        if (!token) {
          return json(401, {
            status: "error",
            code: "unauthorized",
            message: "Sign in required to continue this itinerary",
          });
        }
        let user;
        try {
          user = await verifySupabaseAccessToken(token);
        } catch (e) {
          return json(401, {
            status: "error",
            code: "unauthorized",
            message: `Invalid Supabase token: ${(e as Error).message}`,
          });
        }

        const search = sanitizeSearchRequest(body);
        const selections = sanitizeOfferSelections(body);
        const validation = await provider.validateOffer(selections, null);
        const offer = validation.offer;
        const db = adminClient();

        const { data: profile } = await db
          .from("customer_profiles")
          .select("id")
          .eq("user_id", user.id)
          .maybeSingle();

        const snapshot = offerToSnapshot(offer);
        const payload = {
          origin: search.origin,
          destination: search.destination,
          departure_date: search.departureDate,
          return_date: search.returnDate,
          trip_type: search.tripType,
          cabin_class: search.cabinClass,
          adults: search.passengers.adults,
          children: search.passengers.children,
          infants: search.passengers.infants,
          num_travelers: search.passengers.adults +
            search.passengers.children +
            search.passengers.infants,
          needs_accommodation: Boolean(body.needs_accommodation),
          needs_interchange_assistance: Boolean(
            body.needs_interchange_assistance,
          ),
          needs_taxi: Boolean(body.needs_taxi),
          notes: String(body.notes ?? "").slice(0, 2000),
        };

        const { data, error } = await db
          .from("enquiries")
          .insert({
            kind: "flight",
            user_id: user.id,
            customer_profile_id: profile?.id ?? null,
            payload,
            status: "received",
            provider: "travelport",
            provider_offer_ref: `${offer.provider.transactionId}:${offer.provider.offerId}`,
            itinerary_snapshot: snapshot,
            validated_amount: offer.totalPrice.amount,
            validated_currency: offer.totalPrice.currency,
            offer_expires_at: offer.expiresAt,
            passenger_summary: search.passengers,
            provider_status: "priced",
          })
          .select("*")
          .single();
        if (error) throw error;

        {
          const { error: evErr } = await db.from("enquiry_events").insert({
            enquiry_id: data.id,
            event_type: "received",
            previous_status: null,
            new_status: "received",
            actor_type: "customer",
            actor_user_id: user.id,
            metadata: {
              kind: "flight",
              provider: "travelport",
              route: routeLabel(search.origin, search.destination),
              validated_amount: offer.totalPrice.amount,
              validated_currency: offer.totalPrice.currency,
            },
          });
          if (evErr) console.warn("enquiry_events insert", evErr.message);
        }

        return json(200, {
          status: "success",
          message:
            "Flight itinerary saved as a Destiny enquiry. This is not a ticket.",
          data,
          validation: validationToApi(validation),
          correlation_id: correlationId,
        });
      }

      default: {
        if (!PUBLIC_ACTIONS.has(action)) {
          return json(400, {
            status: "error",
            message: `Unknown action '${action}'`,
          });
        }
        return json(400, { status: "error", message: "Unknown action" });
      }
    }
  } catch (err) {
    console.warn(JSON.stringify({
      event: "flight_commerce_error",
      correlationId,
      code: err instanceof FlightProviderError ? err.code : "internal_error",
    }));
    return errorJson(err);
  }
});
