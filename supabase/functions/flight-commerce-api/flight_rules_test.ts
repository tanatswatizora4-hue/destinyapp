/**
 * Deno tests for M3C flight validation and Travelport normalization.
 * Run: deno test supabase/functions/flight-commerce-api
 */

import {
  assertEquals,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { cabinToTravelport, passengerTotal } from "./flight_domain.ts";
import {
  assertNoAuthoritativeClientFields,
  parsePassengerMix,
  sanitizeOfferSelection,
  sanitizeSearchRequest,
} from "./flight_rules.ts";
import {
  normalizePriceResponse,
  normalizeSearchResponse,
  parseIsoDurationMinutes,
  parseMoney,
} from "./travelport_normalize.ts";
import { searchResultToApi } from "./flight_domain.ts";

const sampleSearch = {
  CatalogProductOfferingsResponse: {
    CatalogProductOfferings: {
      Identifier: { value: "txn-1" },
      CatalogProductOffering: [
        {
          "@type": "CatalogProductOffering",
          sequence: 1,
          id: "o1",
          Departure: "HRE",
          Arrival: "JNB",
          ProductBrandOptions: [
            {
              flightRefs: ["s1", "s2"],
              ProductBrandOffering: [
                {
                  Price: {
                    CurrencyCode: { value: "USD" },
                    TotalPrice: 412.5,
                  },
                  Product: [{ productRef: "p0" }],
                },
              ],
            },
          ],
        },
      ],
    },
    ReferenceList: [
      {
        "@type": "ReferenceListFlight",
        Flight: [
          {
            id: "s1",
            carrier: "UM",
            number: "201",
            duration: "PT1H25M",
            Departure: { location: "HRE", date: "2026-11-20", time: "08:00:00" },
            Arrival: { location: "JNB", date: "2026-11-20", time: "09:25:00" },
          },
          {
            id: "s2",
            carrier: "SA",
            number: "054",
            duration: "PT2H10M",
            Departure: { location: "JNB", date: "2026-11-20", time: "11:00:00" },
            Arrival: { location: "CPT", date: "2026-11-20", time: "13:10:00" },
          },
        ],
      },
      {
        "@type": "ReferenceListProduct",
        Product: [
          {
            "@type": "ProductAir",
            id: "p0",
            totalDuration: "PT5H10M",
            PassengerFlight: [
              {
                FlightProduct: [{ cabin: "Economy", classOfService: "Y" }],
              },
            ],
          },
        ],
      },
    ],
  },
};

Deno.test("search request requires IATA and valid passengers", () => {
  const ok = sanitizeSearchRequest({
    origin: "hre",
    destination: "jnb",
    departure_date: "2026-11-20",
    trip_type: "one_way",
    adults: 1,
    children: 1,
    infants: 1,
    cabin_class: "economy",
  });
  assertEquals(ok.origin, "HRE");
  assertEquals(ok.destination, "JNB");
  assertEquals(ok.passengers.adults, 1);
  assertEquals(passengerTotal(ok.passengers), 3);
  assertEquals(cabinToTravelport(ok.cabinClass), "Economy");

  assertThrows(() =>
    sanitizeSearchRequest({
      origin: "Harare",
      destination: "JNB",
      departure_date: "2026-11-20",
    })
  );
  assertThrows(() =>
    parsePassengerMix({ adults: 1, children: 0, infants: 2 })
  );
  assertThrows(() =>
    parsePassengerMix({ adults: 9, children: 1, infants: 0 })
  );
});

Deno.test("return trip requires return date after departure", () => {
  assertThrows(() =>
    sanitizeSearchRequest({
      origin: "HRE",
      destination: "JNB",
      departure_date: "2026-11-20",
      return_date: "2026-11-19",
      trip_type: "return",
      adults: 1,
    })
  );
  const ok = sanitizeSearchRequest({
    origin: "HRE",
    destination: "JNB",
    departure_date: "2026-11-20",
    return_date: "2026-11-28",
    trip_type: "round-trip",
    adults: 2,
  });
  assertEquals(ok.tripType, "return");
  assertEquals(ok.returnDate, "2026-11-28");
});

Deno.test("client cannot set identity, role, or price fields", () => {
  assertThrows(() => assertNoAuthoritativeClientFields({ user_id: "spoof" }));
  assertThrows(() => assertNoAuthoritativeClientFields({ role: "admin" }));
  assertThrows(() =>
    assertNoAuthoritativeClientFields({ quoted_total: 1 })
  );
  assertThrows(() =>
    assertNoAuthoritativeClientFields({ total_price: 99 })
  );
  assertThrows(() =>
    assertNoAuthoritativeClientFields({ validated_amount: 10 })
  );
  assertThrows(() =>
    assertNoAuthoritativeClientFields({ access_token: "x" })
  );
});

Deno.test("offer selection requires provider references only", () => {
  const sel = sanitizeOfferSelection({
    transaction_id: "txn-1",
    offer_id: "o1",
    product_ids: ["p0"],
  });
  assertEquals(sel.transactionId, "txn-1");
  assertThrows(() => sanitizeOfferSelection({ offer_id: "o1" }));
});

Deno.test("ISO duration and money parsing", () => {
  assertEquals(parseIsoDurationMinutes("PT6H13M"), 373);
  assertEquals(parseIsoDurationMinutes("PT1H25M"), 85);
  assertEquals(parseMoney({ CurrencyCode: { value: "usd" }, TotalPrice: 412.555 }), {
    amount: 412.56,
    currency: "USD",
  });
  assertEquals(parseMoney({ value: 100, code: "EUR" }), {
    amount: 100,
    currency: "EUR",
  });
  assertEquals(parseMoney("not-a-price"), null);
});

Deno.test("normalizes multi-segment Travelport search without inventing fares", () => {
  const result = normalizeSearchResponse(sampleSearch, "one_way", "economy");
  assertEquals(result.offers.length, 1);
  const offer = result.offers[0];
  assertEquals(offer.totalPrice.amount, 412.5);
  assertEquals(offer.totalPrice.currency, "USD");
  assertEquals(offer.itineraries[0].stops, 1);
  assertEquals(offer.itineraries[0].segments.length, 2);
  assertEquals(offer.itineraries[0].segments[0].flightNumber, "UM201");
  assertEquals(offer.itineraries[0].segments[1].carrier.code, "SA");
  assertEquals(offer.provider.offerId, "o1");
  assertEquals(offer.provider.productIds, ["p0"]);
  assertEquals(result.nextLegRequired, false);
});

Deno.test("drops offerings that have no parseable price", () => {
  const raw = structuredClone(sampleSearch);
  const offering =
    raw.CatalogProductOfferingsResponse.CatalogProductOfferings
      .CatalogProductOffering[0];
  offering.ProductBrandOptions[0].ProductBrandOffering[0] = {
    Price: undefined,
    Product: [{ productRef: "p0" }],
  } as unknown as typeof offering.ProductBrandOptions[0]["ProductBrandOffering"][0];
  const result = normalizeSearchResponse(raw, "one_way", "economy");
  assertEquals(result.offers.length, 0);
});

Deno.test("malformed provider payload yields empty offers, not fake inventory", () => {
  const result = normalizeSearchResponse({ junk: true }, "one_way", "economy");
  assertEquals(result.offers.length, 0);
  assertEquals(result.provider, "travelport");
});

Deno.test("return search with only outbound sequence requires next leg", () => {
  const result = normalizeSearchResponse(sampleSearch, "return", "economy");
  assertEquals(result.nextLegRequired, true);
});

Deno.test("API serializer uses snake_case Destiny fields", () => {
  const result = normalizeSearchResponse(sampleSearch, "one_way", "economy");
  const api = searchResultToApi(result);
  const offer = (api.offers as Array<Record<string, unknown>>)[0];
  const provider = offer.provider as Record<string, unknown>;
  assertEquals(api.next_leg_required, false);
  assertEquals(provider.transaction_id, "txn-1");
  assertEquals(provider.offer_id, "o1");
  assertEquals((offer.total_price as Record<string, unknown>).currency, "USD");
});

Deno.test("price response detects amount change", () => {
  const priced = {
    OfferListResponse: {
      Identifier: { value: "txn-1_PC" },
      OfferID: [
        {
          id: "o1",
          Price: { CurrencyCode: { value: "USD" }, TotalPrice: 450 },
          Product: [
            {
              id: "p0",
              FlightSegment: [
                {
                  Flight: {
                    FlightRef: "s1",
                    carrier: "UM",
                    number: "201",
                    Departure: {
                      location: "HRE",
                      date: "2026-11-20",
                      time: "08:00:00",
                    },
                    Arrival: {
                      location: "JNB",
                      date: "2026-11-20",
                      time: "09:25:00",
                    },
                  },
                },
              ],
            },
          ],
        },
      ],
      ReferenceList: [],
    },
  };
  const out = normalizePriceResponse(
    priced,
    [{ transactionId: "txn-1", offerId: "o1", productIds: ["p0"] }],
    { amount: 412.5, currency: "USD" },
  );
  assertEquals(out?.priceChanged, true);
  assertEquals(out?.offer.totalPrice.amount, 450);
  assertEquals(out?.expired, false);
});
