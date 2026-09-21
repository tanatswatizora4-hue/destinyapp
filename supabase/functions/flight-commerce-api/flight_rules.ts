/**
 * Input validation and security helpers for flight-commerce-api.
 */

import {
  CabinClass,
  FlightProviderError,
  FlightSearchRequest,
  OfferSelection,
  PassengerMix,
  passengerTotal,
  TripType,
} from "./flight_domain.ts";

const IATA = /^[A-Z]{3}$/;
const ISO_DATE = /^\d{4}-\d{2}-\d{2}$/;
const CABINS: ReadonlySet<string> = new Set([
  "economy",
  "premium_economy",
  "business",
  "first",
]);

export const FORBIDDEN_CLIENT_FIELDS = [
  "user_id",
  "firebase_uid",
  "legacy_user_id",
  "actor_user_id",
  "actor_firebase_uid",
  "quoted_total",
  "payment_status",
  "status",
  "total_price",
  "service_role",
  "role",
  "validated_amount",
  "provider_access_token",
  "access_token",
  "client_secret",
  "password",
] as const;

export function assertNoAuthoritativeClientFields(
  body: Record<string, unknown>,
): void {
  for (const key of FORBIDDEN_CLIENT_FIELDS) {
    if (Object.prototype.hasOwnProperty.call(body, key)) {
      throw new FlightProviderError(
        "validation_error",
        `Client may not set '${key}'`,
      );
    }
  }
}

export function parsePassengerMix(raw: unknown): PassengerMix {
  const src = (raw && typeof raw === "object")
    ? raw as Record<string, unknown>
    : {};
  const adults = clampInt(src.adults ?? 1, 1, 9);
  const children = clampInt(src.children ?? 0, 0, 8);
  const infants = clampInt(src.infants ?? 0, 0, 8);
  if (infants > adults) {
    throw new FlightProviderError(
      "validation_error",
      "Infants cannot exceed the number of adults",
    );
  }
  const mix = { adults, children, infants };
  const total = passengerTotal(mix);
  if (total < 1 || total > 9) {
    throw new FlightProviderError(
      "validation_error",
      "Search supports 1 to 9 passengers",
    );
  }
  return mix;
}

export function sanitizeSearchRequest(
  body: Record<string, unknown>,
): FlightSearchRequest {
  const origin = normalizeIata(body.origin);
  const destination = normalizeIata(body.destination);
  if (origin === destination) {
    throw new FlightProviderError(
      "validation_error",
      "Origin and destination must differ",
    );
  }
  const departureDate = requireIsoDate(body.departure_date ?? body.departureDate);
  const tripType = parseTripType(body.trip_type ?? body.tripType);
  const returnRaw = body.return_date ?? body.returnDate;
  const returnDate = tripType === "return"
    ? requireIsoDate(returnRaw)
    : (returnRaw ? requireIsoDate(returnRaw) : null);
  if (tripType === "return" && returnDate && returnDate < departureDate) {
    throw new FlightProviderError(
      "validation_error",
      "Return date cannot be before departure date",
    );
  }
  const cabinClass = parseCabin(body.cabin_class ?? body.cabinClass);
  return {
    origin,
    destination,
    departureDate,
    returnDate: tripType === "one_way" ? null : returnDate,
    tripType,
    passengers: parsePassengerMix(body.passengers ?? body),
    cabinClass,
  };
}

export function sanitizeOfferSelection(
  raw: unknown,
): OfferSelection {
  const src = (raw && typeof raw === "object")
    ? raw as Record<string, unknown>
    : {};
  const transactionId = String(src.transaction_id ?? src.transactionId ?? "")
    .trim();
  const offerId = String(src.offer_id ?? src.offerId ?? "").trim();
  const productIdsRaw = src.product_ids ?? src.productIds ?? [];
  const productIds = Array.isArray(productIdsRaw)
    ? productIdsRaw.map((p) => String(p).trim()).filter(Boolean).slice(0, 12)
    : [];
  if (!transactionId || !offerId || productIds.length === 0) {
    throw new FlightProviderError(
      "validation_error",
      "transaction_id, offer_id, and product_ids are required",
    );
  }
  if (transactionId.length > 120 || offerId.length > 80) {
    throw new FlightProviderError("validation_error", "Offer reference too long");
  }
  return { transactionId, offerId, productIds };
}

export function sanitizeOfferSelections(
  body: Record<string, unknown>,
): OfferSelection[] {
  const list = body.selections;
  if (Array.isArray(list) && list.length > 0) {
    return list.slice(0, 6).map(sanitizeOfferSelection);
  }
  return [sanitizeOfferSelection(body)];
}

function parseTripType(raw: unknown): TripType {
  const v = String(raw ?? "one_way").trim().toLowerCase().replace("-", "_");
  if (v === "return" || v === "round_trip" || v === "roundtrip") return "return";
  if (v === "one_way" || v === "oneway") return "one_way";
  throw new FlightProviderError("validation_error", "trip_type must be one_way or return");
}

function parseCabin(raw: unknown): CabinClass {
  const v = String(raw ?? "economy").trim().toLowerCase().replace("-", "_");
  if (!CABINS.has(v)) {
    throw new FlightProviderError("validation_error", "Invalid cabin_class");
  }
  return v as CabinClass;
}

function normalizeIata(raw: unknown): string {
  const code = String(raw ?? "").trim().toUpperCase();
  if (!IATA.test(code)) {
    throw new FlightProviderError(
      "validation_error",
      "Origin and destination must be 3-letter IATA airport codes",
    );
  }
  return code;
}

function requireIsoDate(raw: unknown): string {
  const v = String(raw ?? "").slice(0, 10);
  if (!ISO_DATE.test(v)) {
    throw new FlightProviderError(
      "validation_error",
      "Dates must be YYYY-MM-DD",
    );
  }
  return v;
}

function clampInt(raw: unknown, min: number, max: number): number {
  const n = Math.trunc(Number(raw));
  if (!Number.isFinite(n)) return min;
  return Math.max(min, Math.min(max, n));
}

export function isExpiredOfferMessage(message: string): boolean {
  const m = message.toLowerCase();
  return (
    m.includes("expir") ||
    m.includes("cache") ||
    m.includes("no longer available") ||
    m.includes("not available") ||
    m.includes("invalid catalog") ||
    m.includes("transaction identifier")
  );
}
