/**
 * Provider-neutral flight domain (Destiny canonical models).
 * Travelport JSON is adapted into these types; Flutter never sees raw provider payloads.
 */

export type CabinClass =
  | "economy"
  | "premium_economy"
  | "business"
  | "first";

export type TripType = "one_way" | "return";

export type Money = {
  amount: number;
  currency: string;
};

export type PassengerMix = {
  adults: number;
  children: number;
  infants: number;
};

export type Airport = {
  code: string;
  name?: string;
};

export type Carrier = {
  code: string;
  name?: string;
};

export type FlightSegment = {
  origin: Airport;
  destination: Airport;
  departure: string;
  arrival: string;
  durationMinutes: number | null;
  carrier: Carrier;
  flightNumber: string;
  cabin: string | null;
};

export type FlightItinerary = {
  origin: Airport;
  destination: Airport;
  departure: string;
  arrival: string;
  durationMinutes: number | null;
  stops: number;
  segments: FlightSegment[];
};

export type ProviderReference = {
  provider: string;
  transactionId: string;
  offerId: string;
  productIds: string[];
  sequence: number | null;
};

export type FlightOffer = {
  id: string;
  provider: ProviderReference;
  itineraries: FlightItinerary[];
  totalPrice: Money;
  cabin: string | null;
  fareName: string | null;
  expiresAt: string | null;
};

export type FlightSearchRequest = {
  origin: string;
  destination: string;
  departureDate: string;
  returnDate: string | null;
  tripType: TripType;
  passengers: PassengerMix;
  cabinClass: CabinClass;
};

export type OfferSelection = {
  transactionId: string;
  offerId: string;
  productIds: string[];
};

export type FlightSearchResult = {
  offers: FlightOffer[];
  nextLegRequired: boolean;
  provider: string;
  transactionId: string | null;
  warnings: string[];
};

export type FlightOfferValidation = {
  offer: FlightOffer;
  priceChanged: boolean;
  previousPrice: Money | null;
  expired: boolean;
};

export type ProviderErrorCode =
  | "validation_error"
  | "auth_failed"
  | "provider_unavailable"
  | "provider_timeout"
  | "offer_expired"
  | "malformed_response"
  | "unauthorized"
  | "forbidden"
  | "not_configured";

export class FlightProviderError extends Error {
  readonly code: ProviderErrorCode;
  readonly retryable: boolean;
  readonly httpStatus: number;

  constructor(
    code: ProviderErrorCode,
    message: string,
    opts?: { retryable?: boolean; httpStatus?: number },
  ) {
    super(message);
    this.name = "FlightProviderError";
    this.code = code;
    this.retryable = opts?.retryable ?? false;
    this.httpStatus = opts?.httpStatus ?? statusForCode(code);
  }
}

export function statusForCode(code: ProviderErrorCode): number {
  switch (code) {
    case "validation_error":
      return 400;
    case "unauthorized":
      return 401;
    case "forbidden":
      return 403;
    case "offer_expired":
      return 409;
    case "not_configured":
    case "provider_unavailable":
      return 503;
    case "provider_timeout":
      return 504;
    case "auth_failed":
    case "malformed_response":
      return 502;
    default:
      return 500;
  }
}

export interface FlightProvider {
  readonly name: string;
  search(request: FlightSearchRequest): Promise<FlightSearchResult>;
  nextLeg(selection: OfferSelection): Promise<FlightSearchResult>;
  validateOffer(
    selections: OfferSelection[],
    previousPrice?: Money | null,
  ): Promise<FlightOfferValidation>;
}

export function passengerTotal(mix: PassengerMix): number {
  return mix.adults + mix.children + mix.infants;
}

export function moneyToApi(money: Money): Record<string, unknown> {
  return { amount: money.amount, currency: money.currency };
}

export function offerToApi(offer: FlightOffer): Record<string, unknown> {
  return {
    id: offer.id,
    provider: {
      provider: offer.provider.provider,
      transaction_id: offer.provider.transactionId,
      offer_id: offer.provider.offerId,
      product_ids: offer.provider.productIds,
      sequence: offer.provider.sequence,
    },
    itineraries: offer.itineraries.map((leg) => ({
      origin: leg.origin,
      destination: leg.destination,
      departure: leg.departure,
      arrival: leg.arrival,
      duration_minutes: leg.durationMinutes,
      stops: leg.stops,
      segments: leg.segments.map((s) => ({
        origin: s.origin,
        destination: s.destination,
        departure: s.departure,
        arrival: s.arrival,
        duration_minutes: s.durationMinutes,
        carrier: s.carrier,
        flight_number: s.flightNumber,
        cabin: s.cabin,
      })),
    })),
    total_price: moneyToApi(offer.totalPrice),
    cabin: offer.cabin,
    fare_name: offer.fareName,
    expires_at: offer.expiresAt,
  };
}

export function searchResultToApi(
  result: FlightSearchResult,
): Record<string, unknown> {
  return {
    offers: result.offers.map(offerToApi),
    next_leg_required: result.nextLegRequired,
    provider: result.provider,
    transaction_id: result.transactionId,
    warnings: result.warnings,
  };
}

export function validationToApi(
  v: FlightOfferValidation,
): Record<string, unknown> {
  return {
    offer: offerToApi(v.offer),
    price_changed: v.priceChanged,
    previous_price: v.previousPrice ? moneyToApi(v.previousPrice) : null,
    expired: v.expired,
  };
}

export function cabinToTravelport(
  cabin: CabinClass,
): "Economy" | "PremiumEconomy" | "Business" | "First" {
  switch (cabin) {
    case "premium_economy":
      return "PremiumEconomy";
    case "business":
      return "Business";
    case "first":
      return "First";
    default:
      return "Economy";
  }
}
