/**
 * Bounded Destina airport/place resolution.
 * Deterministic aliases only — never invent IATA codes.
 */

export type DestinaAirport = {
  iata: string;
  label: string;
  aliases: readonly string[];
};

export type AirportResolution =
  | { status: "resolved"; iata: string; label: string }
  | { status: "unresolved"; input: string };

/** Unique Destiny-market airports. Do not alias ambiguous city names (e.g. London). */
export const DESTINA_AIRPORTS: readonly DestinaAirport[] = [
  {
    iata: "HRE",
    label: "Harare",
    aliases: ["harare", "hre", "harare international"],
  },
  {
    iata: "JNB",
    label: "Johannesburg",
    aliases: [
      "johannesburg",
      "joburg",
      "jo burg",
      "jnb",
      "or tambo",
      "ortambo",
    ],
  },
  {
    iata: "ZNZ",
    label: "Zanzibar",
    aliases: ["zanzibar", "znz", "unguja"],
  },
  {
    iata: "CPT",
    label: "Cape Town",
    aliases: ["cape town", "capetown", "cpt"],
  },
  {
    iata: "VFA",
    label: "Victoria Falls",
    aliases: ["victoria falls", "vic falls", "vfa"],
  },
  {
    iata: "DXB",
    label: "Dubai",
    aliases: ["dubai", "dxb", "dubai international"],
  },
] as const;

const IATA = /^[A-Z]{3}$/;

const ALIAS_TO_AIRPORT = new Map<string, DestinaAirport>();
const IATA_TO_AIRPORT = new Map<string, DestinaAirport>();

for (const airport of DESTINA_AIRPORTS) {
  IATA_TO_AIRPORT.set(airport.iata, airport);
  ALIAS_TO_AIRPORT.set(normalizePlaceKey(airport.iata), airport);
  ALIAS_TO_AIRPORT.set(normalizePlaceKey(airport.label), airport);
  for (const alias of airport.aliases) {
    ALIAS_TO_AIRPORT.set(normalizePlaceKey(alias), airport);
  }
}

export function normalizePlaceKey(raw: unknown): string {
  return String(raw ?? "")
    .normalize("NFKD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/['’]/g, "")
    .replace(/[^a-z0-9]+/g, " ")
    .trim()
    .replace(/\s+/g, " ");
}

export function isIataCode(raw: unknown): boolean {
  return IATA.test(String(raw ?? "").trim().toUpperCase());
}

export function resolveAirport(raw: unknown): AirportResolution {
  const input = String(raw ?? "").trim();
  const key = normalizePlaceKey(input);
  if (!key) return { status: "unresolved", input: "" };
  const mapped = ALIAS_TO_AIRPORT.get(key);
  if (mapped) {
    return { status: "resolved", iata: mapped.iata, label: mapped.label };
  }
  const code = input.toUpperCase();
  if (IATA.test(code)) {
    const known = IATA_TO_AIRPORT.get(code);
    return { status: "resolved", iata: code, label: known?.label ?? code };
  }
  return { status: "unresolved", input };
}

export function resolvedIataOrNull(raw: unknown): string | null {
  const resolved = resolveAirport(raw);
  return resolved.status === "resolved" ? resolved.iata : null;
}

export function displayPlace(raw: unknown): string | null {
  if (raw == null || raw === "") return null;
  const input = String(raw).trim().replace(/\s+/g, " ");
  if (!input) return null;
  if (isIataCode(input)) return input.toUpperCase();
  const resolved = resolveAirport(input);
  if (resolved.status === "resolved") return resolved.label;
  return input;
}

export function placesAreSame(a: string | null, b: string | null): boolean {
  if (!a || !b) return false;
  const ra = resolveAirport(a);
  const rb = resolveAirport(b);
  if (ra.status === "resolved" && rb.status === "resolved") {
    return ra.iata === rb.iata;
  }
  return normalizePlaceKey(a) === normalizePlaceKey(b);
}

export const DESTINA_PLACE_COPY = {
  flyFrom: "Which airport or city would you like to fly from?",
  flyTo: "Which airport or city would you like to fly to?",
  flyWhen: "What date would you like to fly?",
  unresolved:
    "I'm not sure which airport to use for that. Which airport or city should I use?",
  samePlace: "Those two places look like the same airport. Where else are you heading?",
  generic:
    "I need a little more detail before I can continue with that.",
} as const;
