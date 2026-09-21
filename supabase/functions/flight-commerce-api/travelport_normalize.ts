/**
 * Travelport CatalogProductOfferings / OfferListResponse → Destiny FlightOffer.
 * Never invents prices or availability. Offers without a parseable price are dropped.
 */

import {
  Airport,
  CabinClass,
  Carrier,
  FlightItinerary,
  FlightOffer,
  FlightSearchResult,
  FlightSegment,
  Money,
  OfferSelection,
  ProviderReference,
} from "./flight_domain.ts";

type Json = Record<string, unknown>;

function asObj(v: unknown): Json | null {
  return v && typeof v === "object" && !Array.isArray(v) ? v as Json : null;
}

function asArr(v: unknown): unknown[] {
  if (Array.isArray(v)) return v;
  if (v == null) return [];
  return [v];
}

function str(v: unknown): string {
  return v == null ? "" : String(v).trim();
}

export function parseIsoDurationMinutes(raw: unknown): number | null {
  const s = str(raw);
  if (!s) return null;
  const m = s.match(/^P(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$/i);
  if (!m) return null;
  const days = Number(m[1] ?? 0);
  const hours = Number(m[2] ?? 0);
  const mins = Number(m[3] ?? 0);
  const secs = Number(m[4] ?? 0);
  const total = days * 24 * 60 + hours * 60 + mins + Math.round(secs / 60);
  return Number.isFinite(total) ? total : null;
}

function numericField(obj: Json, ...keys: string[]): number | null {
  for (const key of keys) {
    if (!(key in obj) || obj[key] == null) continue;
    const raw = obj[key];
    const n = Number(asObj(raw)?.value ?? raw);
    if (Number.isFinite(n)) return n;
  }
  return null;
}

/** Travelport GDS often prices under BestCombinablePrice rather than Price. */
export function priceFromProductBrandOffering(
  pbo: Record<string, unknown>,
): Money | null {
  return parseMoney(
    pbo.Price ??
      pbo.price ??
      pbo.BestCombinablePrice ??
      pbo.bestCombinablePrice,
  );
}

export function parseMoney(price: unknown, fallbackCurrency = ""): Money | null {
  const obj = asObj(price);
  if (!obj) {
    const n = Number(price);
    if (!Number.isFinite(n) || n < 0) return null;
    if (!fallbackCurrency) return null;
    return { amount: roundMoney(n), currency: fallbackCurrency };
  }

  const currency = str(
    obj.code ??
      asObj(obj.CurrencyCode)?.value ??
      obj.CurrencyCode ??
      obj.currencyCode ??
      fallbackCurrency,
  ).toUpperCase();

  let amount = numericField(
    obj,
    "TotalPrice",
    "totalPrice",
    "value",
    "Amount",
    "amount",
  );
  if (amount == null) {
    const base = numericField(obj, "Base", "base") ?? 0;
    const taxes = numericField(obj, "TotalTaxes", "totalTaxes") ?? 0;
    const fees = numericField(obj, "TotalFees", "totalFees") ?? 0;
    const sum = base + taxes + fees;
    amount = sum > 0 ? sum : null;
  }
  if (amount == null || amount < 0 || !currency) return null;
  return { amount: roundMoney(amount), currency: currency.slice(0, 8) };
}

function roundMoney(n: number): number {
  return Math.round(n * 100) / 100;
}

function airport(code: string): Airport {
  return { code: code.toUpperCase().slice(0, 8) };
}

function carrier(code: string, name?: string): Carrier {
  return { code: code.toUpperCase().slice(0, 4), name: name || undefined };
}

function combineDateTime(dateRaw: unknown, timeRaw: unknown): string {
  const date = str(dateRaw).slice(0, 10);
  let time = str(timeRaw);
  if (!date) return "";
  if (!time) return `${date}T00:00:00`;
  if (/^\d{2}:\d{2}$/.test(time)) time = `${time}:00`;
  if (time.includes("T")) return time;
  return `${date}T${time}`;
}

type FlightIndex = Map<string, Json>;
type ProductIndex = Map<string, Json>;
type BrandIndex = Map<string, Json>;

function indexReferenceLists(root: Json): {
  flights: FlightIndex;
  products: ProductIndex;
  brands: BrandIndex;
} {
  const flights: FlightIndex = new Map();
  const products: ProductIndex = new Map();
  const brands: BrandIndex = new Map();
  for (const item of asArr(root.ReferenceList)) {
    const obj = asObj(item);
    if (!obj) continue;
    const type = str(obj["@type"]);
    if (type === "ReferenceListFlight") {
      for (const f of asArr(obj.Flight)) {
        const fo = asObj(f);
        if (fo && str(fo.id)) flights.set(str(fo.id), fo);
      }
    } else if (type === "ReferenceListProduct") {
      for (const p of asArr(obj.Product)) {
        const po = asObj(p);
        if (po && str(po.id)) products.set(str(po.id), po);
      }
    } else if (type === "ReferenceListBrand") {
      for (const b of asArr(obj.Brand)) {
        const bo = asObj(b);
        if (bo && str(bo.id)) brands.set(str(bo.id), bo);
      }
    }
  }
  return { flights, products, brands };
}

function unwrapSearchRoot(raw: unknown): Json | null {
  const obj = asObj(raw);
  if (!obj) return null;
  return asObj(obj.CatalogProductOfferingsResponse) ??
    asObj(obj.OfferListResponse) ??
    obj;
}

function catalogOfferings(root: Json): Json | null {
  return asObj(root.CatalogProductOfferings) ??
    (Array.isArray(root.CatalogProductOffering) ? root : null);
}

function locationFromPoint(point: unknown): string {
  const obj = asObj(point);
  if (!obj) return str(point).toUpperCase();
  return str(
    obj.location ?? obj.airport ?? obj.value ?? asObj(obj.Location)?.value,
  ).toUpperCase();
}

function segmentFromFlight(flight: Json, cabin: string | null): FlightSegment | null {
  const dep = asObj(flight.Departure) ?? {};
  const arr = asObj(flight.Arrival) ?? {};
  const origin = locationFromPoint(dep) || str(dep.location);
  const dest = locationFromPoint(arr) || str(arr.location);
  const carrierCode = str(flight.carrier ?? flight.Carrier ?? asObj(flight.carrier)?.value);
  const number = str(flight.number ?? flight.flightNumber);
  if (!origin || !dest || !carrierCode || !number) return null;
  const flightNumber = `${carrierCode}${number.replace(/^0+/, "") || number}`;
  const opCode = str(
    flight.operatingCarrier ??
      flight.OperatingCarrier ??
      asObj(flight.operatingCarrier)?.value ??
      flight.operatingCarrierCode,
  );
  const opName = str(
    flight.operatingCarrierName ??
      flight.OperatingCarrierName ??
      asObj(flight.operatingCarrier)?.name,
  );
  return {
    origin: airport(origin),
    destination: airport(dest),
    departure: combineDateTime(dep.date, dep.time),
    arrival: combineDateTime(arr.date, arr.time),
    durationMinutes: parseIsoDurationMinutes(flight.duration),
    carrier: carrier(carrierCode, str(flight.carrierName) || undefined),
    operatingCarrier: opCode
      ? carrier(opCode, opName || undefined)
      : undefined,
    flightNumber,
    cabin,
  };
}

function itineraryFromSegments(segments: FlightSegment[]): FlightItinerary | null {
  if (segments.length === 0) return null;
  const first = segments[0];
  const last = segments[segments.length - 1];
  const duration = segments.reduce((acc, s) => acc + (s.durationMinutes ?? 0), 0);
  return {
    origin: first.origin,
    destination: last.destination,
    departure: first.departure,
    arrival: last.arrival,
    durationMinutes: duration > 0 ? duration : null,
    stops: Math.max(0, segments.length - 1),
    segments,
  };
}

function productRefsFromOffering(offering: Json): string[] {
  const refs: string[] = [];
  for (const opt of asArr(offering.ProductBrandOptions)) {
    const oo = asObj(opt);
    if (!oo) continue;
    for (const pbo of asArr(oo.ProductBrandOffering)) {
      const pb = asObj(pbo);
      if (!pb) continue;
      for (const p of asArr(pb.Product)) {
        const po = asObj(p);
        const ref = str(po?.productRef ?? po?.id);
        if (ref) refs.push(ref);
      }
    }
  }
  return [...new Set(refs)];
}

function flightRefsForOption(
  option: Json,
  products: ProductIndex,
): string[] {
  const direct = asArr(option.flightRefs).map(str).filter(Boolean);
  if (direct.length) return direct;
  const refs: string[] = [];
  for (const pbo of asArr(option.ProductBrandOffering)) {
    const pb = asObj(pbo);
    if (!pb) continue;
    for (const p of asArr(pb.Product)) {
      const po = asObj(p);
      const productId = str(po?.productRef ?? po?.id);
      const product = products.get(productId);
      if (!product) continue;
      for (const seg of asArr(product.FlightSegment)) {
        const so = asObj(seg);
        const flight = asObj(so?.Flight);
        const ref = str(flight?.FlightRef ?? so?.FlightRef);
        if (ref) refs.push(ref);
      }
    }
  }
  return refs;
}

function cabinFromProduct(product: Json | undefined): string | null {
  if (!product) return null;
  for (const pf of asArr(product.PassengerFlight)) {
    const pfo = asObj(pf);
    for (const fp of asArr(pfo?.FlightProduct)) {
      const cabin = str(asObj(fp)?.cabin);
      if (cabin) return cabin;
    }
  }
  return null;
}

function fareNameFromBrand(
  offering: Json,
  brands: BrandIndex,
): string | null {
  const brandRef = str(
    asObj(asArr(offering.Brand)[0])?.BrandRef ??
      asObj(offering.Brand)?.BrandRef,
  );
  if (brandRef && brands.has(brandRef)) {
    const name = str(brands.get(brandRef)?.name);
    if (name) return name;
  }
  return str(asObj(offering.Brand)?.name) || null;
}

export function normalizeSearchResponse(
  raw: unknown,
  tripType: "one_way" | "return",
  _cabin: CabinClass,
): FlightSearchResult {
  const root = unwrapSearchRoot(raw);
  if (!root) {
    return {
      offers: [],
      nextLegRequired: tripType === "return",
      provider: "travelport",
      transactionId: null,
      warnings: ["Empty provider response"],
    };
  }

  const warnings: string[] = [];
  const result = asObj(root.Result);
  for (const w of asArr(result?.Warning)) {
    const msg = str(asObj(w)?.Message ?? asObj(w)?.message ?? w);
    if (msg) warnings.push(msg);
  }

  const catalogs = catalogOfferings(root) ?? root;
  const identifier = str(
    asObj(catalogs.Identifier)?.value ??
      asObj(root.Identifier)?.value ??
      root.transactionId,
  );
  const { flights, products, brands } = indexReferenceLists(root);
  const offerings = asArr(catalogs.CatalogProductOffering);
  const offers: FlightOffer[] = [];
  const sequences = new Set<number>();

  for (const offeringRaw of offerings) {
    const offering = asObj(offeringRaw);
    if (!offering) continue;
    const offerId = str(offering.id);
    const sequence = Number(offering.sequence ?? 1) || 1;
    sequences.add(sequence);
    const fareName = fareNameFromBrand(offering, brands);

    for (const optRaw of asArr(offering.ProductBrandOptions)) {
      const option = asObj(optRaw);
      if (!option) continue;
      const flightRefIds = flightRefsForOption(option, products);

      for (const pboRaw of asArr(option.ProductBrandOffering)) {
        const pbo = asObj(pboRaw);
        if (!pbo) continue;
        const money = priceFromProductBrandOffering(pbo);
        if (!money) continue;

        const productIds: string[] = [];
        for (const p of asArr(pbo.Product)) {
          const po = asObj(p);
          const ref = str(po?.productRef ?? po?.id);
          if (ref) productIds.push(ref);
        }
        const cabin = cabinFromProduct(products.get(productIds[0] ?? ""));
        const segments: FlightSegment[] = [];
        const refs = flightRefIds.length
          ? flightRefIds
          : productIds.flatMap((id) => {
            const product = products.get(id);
            if (!product) return [];
            return asArr(product.FlightSegment).map((seg) => {
              const so = asObj(seg);
              return str(asObj(so?.Flight)?.FlightRef ?? so?.FlightRef);
            }).filter(Boolean);
          });

        for (const ref of refs) {
          const fl = flights.get(ref);
          if (!fl) continue;
          const seg = segmentFromFlight(fl, cabin);
          if (seg) segments.push(seg);
        }
        const itinerary = itineraryFromSegments(segments);
        if (!itinerary) continue;

        const provider: ProviderReference = {
          provider: "travelport",
          transactionId: identifier,
          offerId,
          productIds: productIds.length ? productIds : productRefsFromOffering(offering),
          sequence,
        };
        if (!provider.transactionId || !provider.offerId ||
          provider.productIds.length === 0) {
          continue;
        }

        offers.push({
          id: `${identifier}:${offerId}:${provider.productIds.join(",")}`,
          provider,
          itineraries: [itinerary],
          totalPrice: money,
          cabin,
          fareName,
          expiresAt: null,
        });
      }
    }
  }

  const nextLegRequired = tripType === "return" &&
    sequences.size <= 1 &&
    offers.length > 0;

  return {
    offers,
    nextLegRequired,
    provider: "travelport",
    transactionId: identifier || null,
    warnings,
  };
}

export function normalizePriceResponse(
  raw: unknown,
  selections: OfferSelection[],
  previousPrice: Money | null,
): {
  offer: FlightOffer;
  priceChanged: boolean;
  expired: boolean;
} | null {
  const root = unwrapSearchRoot(raw);
  if (!root) return null;

  const { flights, products, brands } = indexReferenceLists(root);
  const identifier = str(
    asObj(root.Identifier)?.value ??
      asObj(asObj(root.OfferListResponse)?.Identifier)?.value,
  );

  const offerNodes = asArr(root.OfferID ?? asObj(root.OfferListResponse)?.OfferID);
  const first = asObj(offerNodes[0]);
  if (!first) {
    const searchLike = normalizeSearchResponse(raw, "one_way", "economy");
    if (searchLike.offers[0]) {
      const offer = searchLike.offers[0];
      return {
        offer,
        priceChanged: previousPrice
          ? offer.totalPrice.amount !== previousPrice.amount ||
            offer.totalPrice.currency !== previousPrice.currency
          : false,
        expired: false,
      };
    }
    return null;
  }

  const money = priceFromProductBrandOffering(first);
  if (!money) return null;

  const productNodes = asArr(first.Product);
  const itineraries: FlightItinerary[] = [];
  const productIds: string[] = [];
  let cabin: string | null = null;
  for (const p of productNodes) {
    const po = asObj(p);
    if (!po) continue;
    const id = str(po.id);
    if (id) productIds.push(id);
    cabin = cabin ?? cabinFromProduct(po) ?? cabinFromProduct(products.get(id));
    const segs: FlightSegment[] = [];
    for (const seg of asArr(po.FlightSegment)) {
      const so = asObj(seg);
      const ref = str(asObj(so?.Flight)?.FlightRef ?? so?.FlightRef);
      const fl = flights.get(ref) ?? asObj(so?.Flight);
      if (!fl) continue;
      const parsed = segmentFromFlight(fl, cabin);
      if (parsed) segs.push(parsed);
    }
    const itin = itineraryFromSegments(segs);
    if (itin) itineraries.push(itin);
  }

  if (itineraries.length === 0) return null;
  const selection = selections[0];
  const offer: FlightOffer = {
    id: `${identifier || selection.transactionId}:${str(first.id) || selection.offerId}`,
    provider: {
      provider: "travelport",
      transactionId: identifier.replace(/_PC$/, "") || selection.transactionId,
      offerId: str(first.id) || selection.offerId,
      productIds: productIds.length ? productIds : selection.productIds,
      sequence: null,
    },
    itineraries,
    totalPrice: money,
    cabin,
    fareName: str(asObj(first.Brand)?.name) ||
      fareNameFromBrand(first, brands) ||
      null,
    expiresAt: null,
  };
  const priceChanged = previousPrice
    ? offer.totalPrice.amount !== previousPrice.amount ||
      offer.totalPrice.currency !== previousPrice.currency
    : false;
  return { offer, priceChanged, expired: false };
}

export function providerErrorsFromBody(raw: unknown): string[] {
  const root = unwrapSearchRoot(raw) ?? asObj(raw);
  if (!root) return [];
  const msgs: string[] = [];
  const result = asObj(root.Result);
  for (const err of asArr(result?.Error ?? root.Error ?? root.errors)) {
    const obj = asObj(err);
    const msg = str(obj?.Message ?? obj?.message ?? obj?.Description ?? err);
    if (msg) msgs.push(msg);
  }
  const fault = str(root.faultstring ?? asObj(root.Fault)?.faultstring);
  if (fault) msgs.push(fault);
  return msgs;
}
