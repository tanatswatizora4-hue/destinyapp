/**
 * Travelport TripServices adapter implementing FlightProvider.
 *
 * Documented endpoints (developer.travelport.com/docs/flights/general/flights-api-endpoints):
 *   Search     POST catalog/search/catalogproductofferings
 *   Next leg   POST catalog/search/catalogproductofferings/buildnext
 *   AirPrice   POST price/offers/buildfromcatalogproductofferings
 *
 * Ticketing / workbench commit is intentionally not implemented in M3C.
 */

import {
  cabinToTravelport,
  FlightOfferValidation,
  FlightProvider,
  FlightProviderError,
  FlightSearchRequest,
  FlightSearchResult,
  Money,
  OfferSelection,
} from "./flight_domain.ts";
import { isExpiredOfferMessage } from "./flight_rules.ts";
import {
  getTravelportAccessToken,
  invalidateTravelportToken,
  travelportAirBaseUrl,
  travelportConfigured,
  type FetchLike,
} from "./travelport_auth.ts";
import {
  normalizePriceResponse,
  normalizeSearchResponse,
  providerErrorsFromBody,
} from "./travelport_normalize.ts";

const SEARCH_TIMEOUT_MS = 45_000;
const PRICE_TIMEOUT_MS = 30_000;
const API_VERSION = Deno.env.get("TRAVELPORT_API_VERSION")?.trim() || "11";

export class TravelportFlightProvider implements FlightProvider {
  readonly name = "travelport";

  constructor(private readonly fetchImpl: FetchLike = fetch) {}

  async search(request: FlightSearchRequest): Promise<FlightSearchResult> {
    this.assertConfigured();
    const payload = buildSearchPayload(request);
    const json = await this.providerPost(
      "catalog/search/catalogproductofferings",
      payload,
      SEARCH_TIMEOUT_MS,
    );
    return normalizeSearchResponse(json, request.tripType, request.cabinClass);
  }

  async nextLeg(selection: OfferSelection): Promise<FlightSearchResult> {
    this.assertConfigured();
    const payload = {
      CatalogProductOfferingsQueryBuildNext: {
        BuildFromCatalogProductOfferingsRequest: buildSelectionRequest([
          selection,
        ]),
      },
    };
    const json = await this.providerPost(
      "catalog/search/catalogproductofferings/buildnext",
      payload,
      SEARCH_TIMEOUT_MS,
    );
    return normalizeSearchResponse(json, "return", "economy");
  }

  async validateOffer(
    selections: OfferSelection[],
    previousPrice?: Money | null,
  ): Promise<FlightOfferValidation> {
    this.assertConfigured();
    const payload = {
      OfferQueryBuildFromCatalogProductOfferings: {
        BuildFromCatalogProductOfferingsRequest: {
          "@type": "BuildFromCatalogProductOfferingsRequestAir",
          ...buildSelectionRequest(selections),
        },
      },
    };
    const json = await this.providerPost(
      "price/offers/buildfromcatalogproductofferings",
      payload,
      PRICE_TIMEOUT_MS,
    );
    const normalized = normalizePriceResponse(
      json,
      selections,
      previousPrice ?? null,
    );
    if (!normalized) {
      throw new FlightProviderError(
        "malformed_response",
        "Travelport did not return a priceable offer",
      );
    }
    return {
      offer: normalized.offer,
      priceChanged: normalized.priceChanged,
      previousPrice: previousPrice ?? null,
      expired: normalized.expired,
    };
  }

  private assertConfigured(): void {
    if (!travelportConfigured()) {
      throw new FlightProviderError(
        "not_configured",
        "Travelport is not configured on the server",
      );
    }
  }

  private airHeaders(token: string, correlationId: string): HeadersInit {
    const headers: Record<string, string> = {
      Accept: "application/json",
      "Content-Type": "application/json",
      "Accept-Encoding": "gzip, deflate",
      Authorization: `Bearer ${token}`,
      "Accept-Version": API_VERSION,
      "Content-Version": API_VERSION,
      TraceId: correlationId,
    };
    const accessGroup = Deno.env.get("TRAVELPORT_ACCESS_GROUP")?.trim();
    const pcc = Deno.env.get("TRAVELPORT_PCC_CORE")?.trim();
    if (accessGroup) headers["XAUTH_TRAVELPORT_ACCESSGROUP"] = accessGroup;
    if (pcc) headers["TVP-PCC-CORE"] = pcc;
    return headers;
  }

  private async providerPost(
    path: string,
    payload: unknown,
    timeoutMs: number,
    retriedAuth = false,
  ): Promise<unknown> {
    const token = await getTravelportAccessToken(this.fetchImpl);
    const url = `${travelportAirBaseUrl()}${path.replace(/^\/+/, "")}`;
    const correlationId = crypto.randomUUID();
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);
    let res: Response;
    try {
      res = await this.fetchImpl(url, {
        method: "POST",
        headers: this.airHeaders(token, correlationId),
        body: JSON.stringify(payload),
        signal: controller.signal,
      });
    } catch (e) {
      if ((e as Error).name === "AbortError") {
        throw new FlightProviderError(
          "provider_timeout",
          "Travelport request timed out",
          { retryable: true },
        );
      }
      throw new FlightProviderError(
        "provider_unavailable",
        "Travelport is unavailable",
        { retryable: true },
      );
    } finally {
      clearTimeout(timer);
    }

    if (res.status === 401 && !retriedAuth) {
      invalidateTravelportToken();
      return this.providerPost(path, payload, timeoutMs, true);
    }

    let json: unknown = null;
    try {
      json = await res.json();
    } catch {
      json = null;
    }

    if (res.status === 429) {
      throw new FlightProviderError(
        "provider_unavailable",
        "Travelport rate limit reached",
        { retryable: true, httpStatus: 503 },
      );
    }

    const providerMsgs = providerErrorsFromBody(json);
    if (!res.ok) {
      const joined = providerMsgs.join("; ");
      if (isExpiredOfferMessage(joined) || res.status === 404) {
        throw new FlightProviderError(
          "offer_expired",
          "This offer is no longer available. Search again.",
        );
      }
      if (res.status >= 500) {
        throw new FlightProviderError(
          "provider_unavailable",
          "Travelport is unavailable",
          { retryable: true },
        );
      }
      throw new FlightProviderError(
        "provider_unavailable",
        "Travelport rejected the request",
        { httpStatus: 502 },
      );
    }

    if (providerMsgs.some(isExpiredOfferMessage)) {
      throw new FlightProviderError(
        "offer_expired",
        "This offer is no longer available. Search again.",
      );
    }
    return json;
  }
}

function buildSearchPayload(request: FlightSearchRequest): unknown {
  const passengers = [];
  if (request.passengers.adults > 0) {
    passengers.push({
      "@type": "PassengerCriteria",
      number: request.passengers.adults,
      passengerTypeCode: "ADT",
    });
  }
  if (request.passengers.children > 0) {
    passengers.push({
      "@type": "PassengerCriteria",
      number: request.passengers.children,
      passengerTypeCode: "CNN",
    });
  }
  if (request.passengers.infants > 0) {
    passengers.push({
      "@type": "PassengerCriteria",
      number: request.passengers.infants,
      passengerTypeCode: "INF",
    });
  }

  const legs = [
    {
      "@type": "SearchCriteriaFlight",
      departureDate: request.departureDate,
      From: { value: request.origin },
      To: { value: request.destination },
    },
  ];
  if (request.tripType === "return" && request.returnDate) {
    legs.push({
      "@type": "SearchCriteriaFlight",
      departureDate: request.returnDate,
      From: { value: request.destination },
      To: { value: request.origin },
    });
  }

  return {
    "@type": "CatalogProductOfferingsQueryRequest",
    CatalogProductOfferingsRequest: {
      "@type": "CatalogProductOfferingsRequestAir",
      maxNumberOfUpsellsToReturn: 2,
      offersPerPage: 20,
      PassengerCriteria: passengers,
      SearchCriteriaFlight: legs,
      SearchModifiersAir: {
        "@type": "SearchModifiersAir",
        CabinPreference: [
          {
            "@type": "CabinPreference",
            preferenceType: "Preferred",
            cabins: [cabinToTravelport(request.cabinClass)],
          },
        ],
      },
    },
  };
}

function buildSelectionRequest(selections: OfferSelection[]): Record<string, unknown> {
  return {
    CatalogProductOfferingsIdentifier: {
      Identifier: { value: selections[0].transactionId },
    },
    CatalogProductOfferingSelection: selections.map((sel) => ({
      CatalogProductOfferingIdentifier: {
        Identifier: { value: sel.offerId },
      },
      ProductIdentifier: sel.productIds.map((id) => ({
        Identifier: { value: id },
      })),
    })),
  };
}
