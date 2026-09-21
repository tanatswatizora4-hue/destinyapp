/**
 * Bounded airport alias tests. No network.
 */

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  resolveAirport,
  resolvedIataOrNull,
  displayPlace,
} from "./destina_airports.ts";

Deno.test("D E F known Destiny markets resolve uniquely", () => {
  assertEquals(resolveAirport("Cape Town"), { status: "resolved", iata: "CPT", label: "Cape Town" });
  assertEquals(resolveAirport("Victoria Falls").status, "resolved");
  assertEquals(resolvedIataOrNull("Victoria Falls"), "VFA");
  assertEquals(resolvedIataOrNull("Dubai"), "DXB");
  assertEquals(resolvedIataOrNull("joburg"), "JNB");
  assertEquals(resolvedIataOrNull("Harare"), "HRE");
  assertEquals(resolvedIataOrNull("Zanzibar"), "ZNZ");
});

Deno.test("London is a valid place but is not invented as an IATA code", () => {
  assertEquals(displayPlace("London"), "London");
  assertEquals(resolveAirport("London").status, "unresolved");
  assertEquals(resolvedIataOrNull("London"), null);
});

Deno.test("Japan and Tokyo are ambiguous and never invent a single IATA", () => {
  assertEquals(resolveAirport("Japan").status, "ambiguous");
  assertEquals(resolveAirport("Tokyo").status, "ambiguous");
  assertEquals(resolvedIataOrNull("Japan"), null);
  assertEquals(resolvedIataOrNull("Narita"), "NRT");
  assertEquals(resolvedIataOrNull("Osaka"), "KIX");
});

Deno.test("unknown natural names are not invented", () => {
  assertEquals(resolveAirport("Narnia").status, "unresolved");
  assertEquals(resolvedIataOrNull("Atlantis"), null);
});
