/**
 * Bounded Destina airport/place resolution and flexible date helpers.
 * Deterministic aliases only — never invent IATA codes.
 */

export type DestinaAirport = {
  iata: string;
  label: string;
  aliases: readonly string[];
};

export type AirportResolution =
  | { status: "resolved"; iata: string; label: string }
  | { status: "unresolved"; input: string }
  | {
    status: "ambiguous";
    input: string;
    suggestions: readonly string[];
    prompt: string;
  };

/** Unique Destiny-market airports. Do not invent codes for multi-airport countries. */
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
  {
    iata: "NRT",
    label: "Tokyo Narita",
    aliases: ["tokyo narita", "narita", "nrt"],
  },
  {
    iata: "HND",
    label: "Tokyo Haneda",
    aliases: ["tokyo haneda", "haneda", "hnd"],
  },
  {
    iata: "KIX",
    label: "Osaka",
    aliases: ["osaka", "kansai", "kix"],
  },
] as const;

/** Countries / regions that must not be auto-mapped to a single airport. */
export const DESTINA_AMBIGUOUS_REGIONS: Readonly<
  Record<string, { suggestions: readonly string[]; prompt: string }>
> = {
  japan: {
    suggestions: ["Tokyo", "Osaka"],
    prompt:
      "Which city in Japan are you flying to — Tokyo, Osaka, or somewhere else?",
  },
  tokyo: {
    suggestions: ["Narita (NRT)", "Haneda (HND)"],
    prompt:
      "Tokyo has more than one airport. Would you prefer Narita or Haneda?",
  },
};

const IATA = /^[A-Z]{3}$/;
const ISO_DATE = /^\d{4}-\d{2}-\d{2}$/;

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

  const ambiguous = DESTINA_AMBIGUOUS_REGIONS[key];
  if (ambiguous) {
    return {
      status: "ambiguous",
      input,
      suggestions: ambiguous.suggestions,
      prompt: ambiguous.prompt,
    };
  }

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
  // Keep ambiguous regions as the human name (e.g. Japan).
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

const MONTHS: Record<string, number> = {
  january: 1,
  jan: 1,
  february: 2,
  feb: 2,
  march: 3,
  mar: 3,
  april: 4,
  apr: 4,
  may: 5,
  june: 6,
  jun: 6,
  july: 7,
  jul: 7,
  august: 8,
  aug: 8,
  september: 9,
  sep: 9,
  sept: 9,
  october: 10,
  oct: 10,
  november: 11,
  nov: 11,
  december: 12,
  dec: 12,
};

const ORDINALS: Record<string, number> = {
  first: 1,
  second: 2,
  third: 3,
  fourth: 4,
  fifth: 5,
  sixth: 6,
  seventh: 7,
  eighth: 8,
  ninth: 9,
  tenth: 10,
  eleventh: 11,
  twelfth: 12,
  thirteenth: 13,
  fourteenth: 14,
  fifteenth: 15,
  sixteenth: 16,
  seventeenth: 17,
  eighteenth: 18,
  nineteenth: 19,
  twentieth: 20,
  twenty: 20,
  thirtieth: 30,
};

/**
 * Parse ISO dates or simple natural phrases like "december second".
 * Returns null when the date is too vague for a flight search (e.g. "early december").
 */
export function parseFlexibleDate(
  raw: unknown,
  now: Date = new Date(),
): { status: "resolved"; iso: string } | { status: "needs_input"; reason: string } | {
  status: "invalid";
} {
  if (raw == null || raw === "") return { status: "invalid" };
  const text = String(raw).trim().replace(/\s+/g, " ");
  if (ISO_DATE.test(text.slice(0, 10))) {
    return { status: "resolved", iso: text.slice(0, 10) };
  }
  const lower = text.toLowerCase();
  if (/^early\s+/.test(lower) || /^late\s+/.test(lower) || /^mid[-\s]?/.test(lower)) {
    return {
      status: "needs_input",
      reason: "Which exact departure date works best?",
    };
  }

  let month: number | null = null;
  let day: number | null = null;
  let year: number | null = null;

  for (const [name, m] of Object.entries(MONTHS)) {
    if (new RegExp(`\\b${name}\\b`).test(lower)) {
      month = m;
      break;
    }
  }
  const yearMatch = lower.match(/\b(20\d{2})\b/);
  if (yearMatch) year = Number(yearMatch[1]);

  const dayNum = lower.match(/\b(\d{1,2})(st|nd|rd|th)?\b/);
  if (dayNum && Number(dayNum[1]) >= 1 && Number(dayNum[1]) <= 31) {
    day = Number(dayNum[1]);
  } else {
    for (const [name, d] of Object.entries(ORDINALS)) {
      if (name === "twenty") continue;
      if (new RegExp(`\\b${name}\\b`).test(lower)) {
        day = d;
        break;
      }
    }
    if (/twenty[-\s]?first/.test(lower)) day = 21;
    if (/twenty[-\s]?second/.test(lower)) day = 22;
    if (/twenty[-\s]?third/.test(lower)) day = 23;
    if (/twenty[-\s]?fourth/.test(lower)) day = 24;
    if (/twenty[-\s]?fifth/.test(lower)) day = 25;
    if (/twenty[-\s]?sixth/.test(lower)) day = 26;
    if (/twenty[-\s]?seventh/.test(lower)) day = 27;
    if (/twenty[-\s]?eighth/.test(lower)) day = 28;
    if (/twenty[-\s]?ninth/.test(lower)) day = 29;
  }

  if (month == null || day == null) return { status: "invalid" };

  const y = year ?? now.getUTCFullYear();
  let iso = `${y}-${String(month).padStart(2, "0")}-${String(day).padStart(2, "0")}`;
  const candidate = new Date(`${iso}T00:00:00Z`);
  if (Number.isNaN(candidate.getTime())) return { status: "invalid" };
  // If the date is more than ~2 days in the past and no year was given, roll to next year.
  if (!year) {
    const today = Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate());
    if (candidate.getTime() < today - 2 * 86400000) {
      iso = `${y + 1}-${String(month).padStart(2, "0")}-${String(day).padStart(2, "0")}`;
    }
  }
  return { status: "resolved", iso };
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
