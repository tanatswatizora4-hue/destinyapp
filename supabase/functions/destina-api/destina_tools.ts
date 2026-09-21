/**
 * Allowlisted Destina tools. The model never constructs SQL or URLs.
 */

import {
  DestinaCard,
  DestinaError,
  DestinaToolResult,
  DestinaToolSpec,
  TripState,
} from "./destina_domain.ts";
import {
  assertKnownTool,
  customerFacingToolError,
  DESTINA_LIMITS,
  mergeTripState,
  missingFlightFields,
  sanitizeSearchQuery,
  truncateJson,
} from "./destina_rules.ts";
import { DESTINA_PLACE_COPY, resolveAirport } from "./destina_airports.ts";
import { sanitizeSearchRequest } from "../flight-commerce-api/flight_rules.ts";
import { FlightProviderError, searchResultToApi } from "../flight-commerce-api/flight_domain.ts";
import { FlightSearchResult } from "../flight-commerce-api/flight_domain.ts";

export type DestinaActor = {
  userId: string | null;
  displayName: string | null;
  email: string | null;
};

export type DestinaToolContext = {
  actor: DestinaActor;
  tripState: TripState;
  conversationId: string;
  flightSearchesUsed: number;
  catalogCallsUsed: number;
  requestId?: string;
  onTravelport?: (info: {
    duration_ms: number;
    outcome: "ok" | "error";
    error_code?: string | null;
    offer_count: number;
  }) => void;
};

export type FlightSearchFn = (
  body: Record<string, unknown>,
) => Promise<FlightSearchResult>;

export type CatalogSearchFn = (
  kind: "tour" | "stay" | "vehicle",
  query: string,
  limit: number,
) => Promise<Record<string, unknown>[]>;

export type CatalogDetailFn = (
  kind: "tour" | "stay" | "vehicle",
  id: string,
) => Promise<Record<string, unknown> | null>;

export type ProfileFn = (userId: string) => Promise<Record<string, unknown> | null>;
export type BookingsFn = (userId: string) => Promise<Record<string, unknown>[]>;
export type BookingFn = (
  userId: string,
  bookingId: string,
) => Promise<Record<string, unknown> | null>;
export type CreateEnquiryFn = (input: {
  userId: string;
  kind: string;
  payload: Record<string, unknown>;
}) => Promise<{ id: string; status: string }>;

export type DestinaToolDeps = {
  searchFlights: FlightSearchFn;
  searchCatalog: CatalogSearchFn;
  getCatalogDetail: CatalogDetailFn;
  getProfile: ProfileFn;
  listBookings: BookingsFn;
  getBooking: BookingFn;
  createEnquiry: CreateEnquiryFn;
};

export const DESTINA_TOOL_SPECS: DestinaToolSpec[] = [
  {
    name: "update_trip_state",
    description:
      "Optional memory only. Save a trip fact the customer already stated (city names are fine, e.g. Zanzibar). Do not call for greetings, inspiration, packing, seasons, or general questions. Never require IATA. Never invent fares. Never search flights.",
    parameters: {
      type: "object",
      properties: {
        origin: { type: "string" },
        destination: { type: "string" },
        departure_date: { type: "string" },
        return_date: { type: "string" },
        adults: { type: "integer" },
        children: { type: "integer" },
        infants: { type: "integer" },
        budget: { type: "number" },
        currency: { type: "string" },
        flight_required: { type: "boolean" },
        stay_required: { type: "boolean" },
        vehicle_required: { type: "boolean" },
        visa_help_required: { type: "boolean" },
        preferred_hotel_class: { type: "string" },
        tour_interests: { type: "array", items: { type: "string" } },
        special_requests: { type: "string" },
      },
    },
  },
  {
    name: "search_flights",
    description:
      "ONLY if the customer asked to find or search live flights. Pass origin, destination city/airport, and departure_date directly — do not call update_trip_state first for the same facts. City names are OK. Never invent fares. Do not call for destination inspiration. For multi-airport countries (Japan), ask which city first.",
    parameters: {
      type: "object",
      properties: {
        origin: { type: "string" },
        destination: { type: "string" },
        departure_date: { type: "string" },
        return_date: { type: "string" },
        adults: { type: "integer" },
        children: { type: "integer" },
        infants: { type: "integer" },
        cabin_class: { type: "string" },
      },
      required: ["origin", "destination", "departure_date"],
    },
  },
  {
    name: "search_tours",
    description: "Search Destiny published tour catalog ONLY when the customer asks for Destiny tours/packages. Catalog is not a live hold.",
    parameters: {
      type: "object",
      properties: { query: { type: "string" } },
    },
  },
  {
    name: "search_stays",
    description: "Search Destiny published stays catalog. Catalog is not live availability.",
    parameters: {
      type: "object",
      properties: { query: { type: "string" } },
    },
  },
  {
    name: "search_vehicles",
    description: "Search Destiny published vehicle catalog. Catalog is not live availability.",
    parameters: {
      type: "object",
      properties: { query: { type: "string" } },
    },
  },
  {
    name: "get_tour_details",
    description: "Get one published Destiny tour by id.",
    parameters: {
      type: "object",
      properties: { id: { type: "string" } },
      required: ["id"],
    },
  },
  {
    name: "get_stay_details",
    description: "Get one published Destiny stay by id.",
    parameters: {
      type: "object",
      properties: { id: { type: "string" } },
      required: ["id"],
    },
  },
  {
    name: "get_vehicle_details",
    description: "Get one published Destiny vehicle by id.",
    parameters: {
      type: "object",
      properties: { id: { type: "string" } },
      required: ["id"],
    },
  },
  {
    name: "get_customer_profile",
    description: "Get the signed-in customer's safe profile (name/email). Auth required.",
    parameters: { type: "object" },
  },
  {
    name: "list_customer_bookings",
    description: "List the signed-in customer's bookings. Auth required. Never other customers.",
    parameters: { type: "object" },
  },
  {
    name: "get_booking_status",
    description: "Get one booking owned by the signed-in customer.",
    parameters: {
      type: "object",
      properties: { booking_id: { type: "string" } },
      required: ["booking_id"],
    },
  },
  {
    name: "create_travel_enquiry",
    description:
      "Create a Destiny enquiry only after the customer confirms. Auth required. Never fake submission.",
    parameters: {
      type: "object",
      properties: {
        confirm: { type: "boolean" },
        kind: { type: "string" },
        summary: { type: "string" },
      },
      required: ["confirm", "summary"],
    },
  },
  {
    name: "create_flight_enquiry",
    description:
      "Create a flight enquiry after customer confirmation. Does not issue tickets or invent PNRs.",
    parameters: {
      type: "object",
      properties: {
        confirm: { type: "boolean" },
        summary: { type: "string" },
      },
      required: ["confirm", "summary"],
    },
  },
  {
    name: "handoff_to_consultant",
    description:
      "Hand the trip to a Destiny consultant by creating an enquiry with a short brief, not a full transcript.",
    parameters: {
      type: "object",
      properties: {
        reason: { type: "string" },
        summary: { type: "string" },
      },
      required: ["reason", "summary"],
    },
  },
];

function ok(
  name: string,
  activity: string,
  summary: string,
  extra: Partial<DestinaToolResult> = {},
): DestinaToolResult {
  return { name, status: "ok", activity, summary, ...extra };
}

function needs(
  name: string,
  activity: string,
  summary: string,
  extra: Partial<DestinaToolResult> = {},
): DestinaToolResult {
  return { name, status: "needs_input", activity, summary, ...extra };
}

function authReq(name: string, activity: string): DestinaToolResult {
  return {
    name,
    status: "auth_required",
    activity,
    summary: "Sign in to continue this Destina action.",
    error_code: "unauthorized",
  };
}

function catalogCards(
  kind: "tour" | "stay" | "vehicle",
  items: Record<string, unknown>[],
): DestinaCard[] {
  return items.map((item) => ({
    kind,
    source: "destiny_catalog" as const,
    availability: "catalog_not_live_hold" as const,
    item,
  }));
}

export async function executeDestinaTool(
  deps: DestinaToolDeps,
  ctx: DestinaToolContext,
  name: string,
  args: Record<string, unknown>,
): Promise<{ result: DestinaToolResult; tripState: TripState }> {
  const tool = assertKnownTool(name);
  let tripState = ctx.tripState;

  switch (tool) {
    case "update_trip_state": {
      try {
        tripState = mergeTripState(tripState, args);
      } catch (e) {
        if (e instanceof DestinaError) {
          return {
            tripState,
            result: needs(
              tool,
              "Need a bit more detail…",
              customerFacingToolError(e),
              { error_code: e.code },
            ),
          };
        }
        throw e;
      }
      return {
        tripState,
        result: ok(
          tool,
          "Updating trip details…",
          "Trip details updated.",
          { data: { trip_state: tripState } },
        ),
      };
    }
    case "search_flights": {
      try {
        tripState = mergeTripState(tripState, {
          origin: args.origin ?? tripState.origin,
          destination: args.destination ?? tripState.destination,
          departure_date: args.departure_date ?? tripState.departure_date,
          return_date: args.return_date ?? tripState.return_date,
          adults: args.adults ?? tripState.adults,
          children: args.children ?? tripState.children,
          infants: args.infants ?? tripState.infants,
          flight_required: true,
        });
      } catch (e) {
        if (e instanceof DestinaError) {
          return {
            tripState,
            result: needs(
              tool,
              "Need a few flight details…",
              customerFacingToolError(e),
              { error_code: e.code },
            ),
          };
        }
        throw e;
      }
      const missing = missingFlightFields(tripState);
      if (missing.includes("origin")) {
        return {
          tripState,
          result: needs(tool, "Need a few flight details…", DESTINA_PLACE_COPY.flyFrom, {
            data: { missing, source: "none" },
            error_code: "missing_flight_fields",
          }),
        };
      }
      if (missing.includes("destination")) {
        return {
          tripState,
          result: needs(tool, "Need a few flight details…", DESTINA_PLACE_COPY.flyTo, {
            data: { missing, source: "none" },
            error_code: "missing_flight_fields",
          }),
        };
      }
      if (missing.includes("departure_date")) {
        return {
          tripState,
          result: needs(tool, "Need a few flight details…", DESTINA_PLACE_COPY.flyWhen, {
            data: { missing, source: "none" },
            error_code: "missing_flight_fields",
          }),
        };
      }
      const originRes = resolveAirport(tripState.origin);
      const destRes = resolveAirport(tripState.destination);
      if (originRes.status === "ambiguous") {
        return {
          tripState,
          result: needs(tool, "Need a departure city…", originRes.prompt, {
            data: {
              field: "origin",
              source: "none",
              suggestions: originRes.suggestions,
            },
            error_code: "airport_ambiguous",
          }),
        };
      }
      if (originRes.status !== "resolved") {
        return {
          tripState,
          result: needs(tool, "Need a departure city…", DESTINA_PLACE_COPY.flyFrom, {
            data: { field: "origin", source: "none" },
            error_code: "airport_unresolved",
          }),
        };
      }
      if (destRes.status === "ambiguous") {
        return {
          tripState,
          result: needs(tool, "Need an arrival city…", destRes.prompt, {
            data: {
              field: "destination",
              source: "none",
              suggestions: destRes.suggestions,
            },
            error_code: "airport_ambiguous",
          }),
        };
      }
      if (destRes.status !== "resolved") {
        return {
          tripState,
          result: needs(tool, "Need an arrival city…", DESTINA_PLACE_COPY.flyTo, {
            data: { field: "destination", source: "none" },
            error_code: "airport_unresolved",
          }),
        };
      }
      tripState = {
        ...tripState,
        origin_iata: originRes.iata,
        destination_iata: destRes.iata,
      };
      if (ctx.flightSearchesUsed >= DESTINA_LIMITS.maxFlightSearches) {
        return {
          tripState,
          result: {
            name: tool,
            status: "error",
            activity: "Live flight search paused",
            summary:
              "I have already searched live flights enough for this turn. I can send the request to our team.",
            error_code: "flight_search_limit",
          },
        };
      }
      const tpStarted = Date.now();
      try {
        const request = sanitizeSearchRequest({
          origin: originRes.iata,
          destination: destRes.iata,
          departure_date: tripState.departure_date,
          return_date: tripState.return_date,
          trip_type: tripState.return_date ? "return" : "one_way",
          adults: tripState.adults,
          children: tripState.children,
          infants: tripState.infants,
          cabin_class: args.cabin_class ?? "economy",
        });
        const result = await deps.searchFlights({
          origin: request.origin,
          destination: request.destination,
          departure_date: request.departureDate,
          return_date: request.returnDate,
          trip_type: request.tripType,
          adults: request.passengers.adults,
          children: request.passengers.children,
          infants: request.passengers.infants,
          cabin_class: request.cabinClass,
        });
        const api = searchResultToApi(result);
        const offers = (api.offers as Record<string, unknown>[]).slice(
          0,
          DESTINA_LIMITS.maxCatalogResults,
        );
        ctx.onTravelport?.({
          duration_ms: Date.now() - tpStarted,
          outcome: "ok",
          offer_count: offers.length,
        });
        const cards: DestinaCard[] = offers.map((offer) => ({
          kind: "flight_offer",
          source: "live_travelport",
          offer,
        }));
        return {
          tripState,
          result: ok(
            tool,
            "Searching live flights…",
            offers.length
              ? `Found ${offers.length} live Travelport quote(s). These are not tickets.`
              : "No live flights were returned for that search. Destiny never invents fares.",
            {
              data: truncateJson({
                source: "live_travelport",
                next_leg_required: api.next_leg_required,
                offers,
              }) as Record<string, unknown>,
              cards,
            },
          ),
        };
      } catch (e) {
        const durationMs = Date.now() - tpStarted;
        if (e instanceof FlightProviderError && e.code === "validation_error") {
          ctx.onTravelport?.({
            duration_ms: durationMs,
            outcome: "error",
            error_code: "invalid_flight_request",
            offer_count: 0,
          });
          return {
            tripState,
            result: needs(
              tool,
              "Need a few flight details…",
              /IATA|airport/i.test(e.message)
                ? DESTINA_PLACE_COPY.unresolved
                : DESTINA_PLACE_COPY.generic,
              { error_code: "invalid_flight_request" },
            ),
          };
        }
        let errorCode = "travelport_provider_error";
        if (e instanceof FlightProviderError) {
          if (
            e.code === "provider_timeout" || /timeout/i.test(e.message)
          ) {
            errorCode = "travelport_timeout";
          } else if (
            e.code === "auth_failed" || e.code === "unauthorized" ||
            e.code === "forbidden" || /auth|credential|401|403/i.test(e.message)
          ) {
            errorCode = "travelport_auth";
          }
        } else if (e instanceof Error && /timeout/i.test(e.message)) {
          errorCode = "travelport_timeout";
        }
        ctx.onTravelport?.({
          duration_ms: durationMs,
          outcome: "error",
          error_code: errorCode,
          offer_count: 0,
        });
        return {
          tripState,
          result: {
            name: tool,
            status: "error",
            activity: "Live flight search unavailable",
            summary:
              "I couldn't complete the live flight search just now. I can try again, or I can send the request to our travel team.",
            error_code: errorCode,
          },
        };
      }
    }
    case "search_tours":
    case "search_stays":
    case "search_vehicles": {
      const kind = tool === "search_tours"
        ? "tour"
        : tool === "search_stays"
        ? "stay"
        : "vehicle";
      const q = sanitizeSearchQuery(args.query);
      const items = await deps.searchCatalog(
        kind,
        q,
        DESTINA_LIMITS.maxCatalogResults,
      );
      const activity = kind === "tour"
        ? "Checking Destiny tours…"
        : kind === "stay"
        ? "Checking Destiny stays…"
        : "Checking Destiny vehicles…";
      return {
        tripState,
        result: ok(
          tool,
          activity,
          items.length
            ? `Found ${items.length} Destiny catalog ${kind}(s). Catalog is not a live hold.`
            : `No published ${kind}s matched. Catalog presence is not live availability.`,
          {
            data: {
              source: "destiny_catalog",
              availability: "catalog_not_live_hold",
              items,
            },
            cards: catalogCards(kind, items),
          },
        ),
      };
    }
    case "get_tour_details":
    case "get_stay_details":
    case "get_vehicle_details": {
      const kind = tool === "get_tour_details"
        ? "tour"
        : tool === "get_stay_details"
        ? "stay"
        : "vehicle";
      const id = String(args.id ?? "").trim();
      if (!id) {
        throw new DestinaError("validation_error", "id is required", 400);
      }
      const item = await deps.getCatalogDetail(kind, id);
      if (!item) {
        return {
          tripState,
          result: {
            name: tool,
            status: "error",
            activity: "Looking up Destiny catalog…",
            summary: "I couldn't find that published catalog item.",
            error_code: "not_found",
          },
        };
      }
      if (kind === "tour") tripState = mergeTripState(tripState, { selected_tour_id: id });
      if (kind === "stay") {
        tripState = mergeTripState(tripState, { selected_stay_id: id, stay_required: true });
      }
      if (kind === "vehicle") {
        tripState = mergeTripState(tripState, {
          selected_vehicle_id: id,
          vehicle_required: true,
        });
      }
      return {
        tripState,
        result: ok(tool, "Opening Destiny catalog details…", "Catalog details loaded.", {
          data: { source: "destiny_catalog", availability: "catalog_not_live_hold", item },
          cards: catalogCards(kind, [item]),
        }),
      };
    }
    case "get_customer_profile": {
      if (!ctx.actor.userId) return { tripState, result: authReq(tool, "Need a signed-in account…") };
      const profile = await deps.getProfile(ctx.actor.userId);
      return {
        tripState,
        result: ok(tool, "Checking your Destiny profile…", "Profile loaded.", {
          data: profile ?? { display_name: ctx.actor.displayName, email: ctx.actor.email },
        }),
      };
    }
    case "list_customer_bookings": {
      if (!ctx.actor.userId) return { tripState, result: authReq(tool, "Need a signed-in account…") };
      const list = await deps.listBookings(ctx.actor.userId);
      return {
        tripState,
        result: ok(
          tool,
          "Checking your bookings…",
          list.length ? `You have ${list.length} booking request(s).` : "No booking requests yet.",
          { data: { bookings: list } },
        ),
      };
    }
    case "get_booking_status": {
      if (!ctx.actor.userId) return { tripState, result: authReq(tool, "Need a signed-in account…") };
      const bookingId = String(args.booking_id ?? "").trim();
      if (!bookingId) {
        throw new DestinaError("validation_error", "booking_id is required", 400);
      }
      const booking = await deps.getBooking(ctx.actor.userId, bookingId);
      if (!booking) {
        return {
          tripState,
          result: {
            name: tool,
            status: "rejected",
            activity: "Checking booking…",
            summary: "I can only open bookings that belong to you.",
            error_code: "forbidden",
          },
        };
      }
      return {
        tripState,
        result: ok(tool, "Checking booking status…", "Booking status loaded.", {
          data: { booking },
        }),
      };
    }
    case "create_travel_enquiry":
    case "create_flight_enquiry": {
      if (args.confirm !== true) {
        return {
          tripState,
          result: needs(
            tool,
            "Waiting for your confirmation…",
            "I can send this to our travel team after you confirm. This will be a request, not a booking.",
          ),
        };
      }
      if (!ctx.actor.userId) {
        return { tripState, result: authReq(tool, "Sign in to send this request…") };
      }
      const kind = tool === "create_flight_enquiry"
        ? "flight"
        : String(args.kind ?? "general").slice(0, 20);
      const summary = String(args.summary ?? "").slice(0, 1000);
      const created = await deps.createEnquiry({
        userId: ctx.actor.userId,
        kind: ["flight", "general", "stay", "vehicle", "tour"].includes(kind)
          ? kind
          : "general",
        payload: {
          origin: tripState.origin,
          destination: tripState.destination,
          departure_date: tripState.departure_date,
          return_date: tripState.return_date,
          adults: tripState.adults,
          children: tripState.children,
          infants: tripState.infants,
          notes: summary,
          destina: {
            conversation_id: ctx.conversationId,
            summary,
            trip_state: tripState,
            selected_inventory: [
              tripState.selected_tour_id && { type: "tour", id: tripState.selected_tour_id },
              tripState.selected_stay_id && { type: "stay", id: tripState.selected_stay_id },
              tripState.selected_vehicle_id &&
              { type: "vehicle", id: tripState.selected_vehicle_id },
            ].filter(Boolean),
          },
        },
      });
      tripState = mergeTripState(tripState, { confirmed_for_enquiry: true });
      return {
        tripState,
        result: ok(tool, "Sending this to Destiny…", "Enquiry created. This is not a confirmed booking.", {
          data: { enquiry_id: created.id, status: created.status },
        }),
      };
    }
    case "handoff_to_consultant": {
      const reason = String(args.reason ?? "handoff").slice(0, 80);
      const summary = String(args.summary ?? "").slice(0, 1000);
      if (!ctx.actor.userId) {
        return { tripState, result: authReq(tool, "Sign in to reach a consultant…") };
      }
      const created = await deps.createEnquiry({
        userId: ctx.actor.userId,
        kind: tripState.flight_required ? "flight" : "general",
        payload: {
          origin: tripState.origin,
          destination: tripState.destination,
          departure_date: tripState.departure_date,
          return_date: tripState.return_date,
          adults: tripState.adults,
          children: tripState.children,
          infants: tripState.infants,
          destina: {
            conversation_id: ctx.conversationId,
            summary,
            trip_state: tripState,
            handoff_reason: reason,
          },
        },
      });
      return {
        tripState,
        result: ok(tool, "Passing this to a Destiny consultant…", "Handed off to a consultant.", {
          data: { enquiry_id: created.id, status: created.status, handoff: true, reason },
        }),
      };
    }
  }
}
