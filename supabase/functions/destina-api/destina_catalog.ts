/**
 * Compact Destiny catalog reads for Destina tools.
 */

import { DESTINA_LIMITS, sanitizeSearchQuery } from "./destina_rules.ts";

type Admin = {
  from: (table: string) => {
    select: (cols: string) => CatalogQuery;
  };
};

type CatalogQuery = {
  eq: (col: string, val: unknown) => CatalogQuery;
  or: (expr: string) => CatalogQuery;
  ilike: (col: string, val: string) => CatalogQuery;
  order: (col: string, opts?: { ascending?: boolean }) => CatalogQuery;
  limit: (n: number) => CatalogQuery;
  maybeSingle: () => Promise<{ data: Record<string, unknown> | null; error: { message: string } | null }>;
  then?: never;
};

function asList(data: unknown): Record<string, unknown>[] {
  return Array.isArray(data) ? data as Record<string, unknown>[] : [];
}

export function compactTour(row: Record<string, unknown>): Record<string, unknown> {
  return {
    id: row.id,
    legacy_id: row.legacy_id ?? null,
    name: row.title ?? row.name,
    summary: String(row.description ?? "").slice(0, 240),
    price: row.price ?? null,
    currency: row.currency ?? "USD",
    duration: row.duration ?? null,
    image: row.primary_image_path ?? null,
    featured: row.is_featured === true,
  };
}

export function compactStay(row: Record<string, unknown>): Record<string, unknown> {
  return {
    id: row.id,
    legacy_id: row.legacy_id ?? null,
    name: row.name,
    type: row.type ?? null,
    location: [row.city, row.country].filter(Boolean).join(", "),
    summary: String(row.description ?? "").slice(0, 240),
    currency: row.currency ?? "USD",
    image: row.primary_image_path ?? null,
    featured: row.is_featured === true,
  };
}

export function compactVehicle(row: Record<string, unknown>): Record<string, unknown> {
  return {
    id: row.id,
    legacy_id: row.legacy_id ?? null,
    name: `${row.make ?? ""} ${row.model ?? ""}`.trim(),
    type: row.type ?? null,
    location: [row.city, row.country].filter(Boolean).join(", "),
    price_per_day: row.price_per_day ?? null,
    currency: row.currency ?? "USD",
    image: row.primary_image_path ?? null,
    featured: row.is_featured === true,
  };
}

export async function searchPublishedCatalog(
  db: Admin,
  kind: "tour" | "stay" | "vehicle",
  query: string,
  limit = DESTINA_LIMITS.maxCatalogResults,
): Promise<Record<string, unknown>[]> {
  const q = sanitizeSearchQuery(query);
  const table = kind === "tour" ? "tours" : kind === "stay" ? "stays" : "vehicles";
  const compact = kind === "tour" ? compactTour : kind === "stay" ? compactStay : compactVehicle;
  const cols = kind === "tour"
    ? "id, legacy_id, title, description, price, currency, duration, primary_image_path, is_featured"
    : kind === "stay"
    ? "id, legacy_id, name, type, description, city, country, currency, primary_image_path, is_featured"
    : "id, legacy_id, make, model, type, city, country, price_per_day, currency, primary_image_path, is_featured";

  let builder = db.from(table).select(cols).eq("is_published", true);
  if (q) {
    if (kind === "tour") builder = builder.or(`title.ilike.%${q}%,description.ilike.%${q}%`);
    else if (kind === "stay") {
      builder = builder.or(
        `name.ilike.%${q}%,city.ilike.%${q}%,country.ilike.%${q}%,description.ilike.%${q}%`,
      );
    } else {
      builder = builder.or(
        `make.ilike.%${q}%,model.ilike.%${q}%,city.ilike.%${q}%,type.ilike.%${q}%`,
      );
    }
  }
  const { data, error } = await (builder.order("is_featured", { ascending: false }).limit(limit) as unknown as Promise<{
    data: Record<string, unknown>[] | null;
    error: { message: string } | null;
  }>);
  if (error) throw new Error(error.message);
  return asList(data).map(compact);
}

export async function getPublishedCatalogItem(
  db: Admin,
  kind: "tour" | "stay" | "vehicle",
  id: string,
): Promise<Record<string, unknown> | null> {
  const table = kind === "tour" ? "tours" : kind === "stay" ? "stays" : "vehicles";
  const compact = kind === "tour" ? compactTour : kind === "stay" ? compactStay : compactVehicle;
  const cols = kind === "tour"
    ? "id, legacy_id, title, description, price, currency, duration, primary_image_path, is_featured, is_published"
    : kind === "stay"
    ? "id, legacy_id, name, type, description, city, country, address, currency, primary_image_path, is_featured, is_published"
    : "id, legacy_id, make, model, year, type, city, country, price_per_day, currency, primary_image_path, is_featured, is_published";

  const uuid = /^[0-9a-f-]{36}$/i.test(id);
  let q = db.from(table).select(cols).eq("is_published", true);
  q = uuid ? q.eq("id", id) : q.eq("legacy_id", Number(id));
  const { data, error } = await q.maybeSingle();
  if (error) throw new Error(error.message);
  if (!data) return null;
  return compact(data);
}
