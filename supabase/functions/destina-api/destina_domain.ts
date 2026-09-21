/**
 * Canonical Destina types. The model never sees raw provider payloads.
 */

export type DestinaRole = "user" | "assistant" | "system" | "tool";

export type TripState = {
  destination: string | null;
  origin: string | null;
  departure_date: string | null;
  return_date: string | null;
  adults: number;
  children: number;
  infants: number;
  budget: number | null;
  currency: string | null;
  flight_required: boolean | null;
  stay_required: boolean | null;
  preferred_hotel_class: string | null;
  tour_interests: string[];
  vehicle_required: boolean | null;
  visa_help_required: boolean | null;
  special_requests: string | null;
  selected_tour_id: string | null;
  selected_stay_id: string | null;
  selected_vehicle_id: string | null;
  confirmed_for_enquiry: boolean;
};

export type DestinaCard =
  | {
    kind: "flight_offer";
    source: "live_travelport";
    offer: Record<string, unknown>;
  }
  | {
    kind: "tour" | "stay" | "vehicle";
    source: "destiny_catalog";
    availability: "catalog_not_live_hold";
    item: Record<string, unknown>;
  };

export type DestinaToolResult = {
  name: string;
  status: "ok" | "error" | "rejected" | "needs_input" | "auth_required";
  activity: string;
  summary: string;
  data?: Record<string, unknown>;
  cards?: DestinaCard[];
  error_code?: string;
};

export type DestinaSuggestedAction = {
  id: string;
  label: string;
};

export type DestinaHandoff = {
  created: boolean;
  enquiry_id?: string;
  reason?: string;
};

export type DestinaTurnResponse = {
  conversation_id: string;
  message: {
    role: "assistant";
    content: string;
  };
  trip_state: TripState;
  tool_results: DestinaToolResult[];
  suggested_actions: DestinaSuggestedAction[];
  handoff: DestinaHandoff | null;
  auth_required: boolean;
  model: {
    provider: string;
    name: string;
    configured: boolean;
  };
};

export type DestinaChatMessage = {
  role: DestinaRole;
  content: string;
  toolCallId?: string;
  toolName?: string;
  /**
   * Opaque provider continuation for this model turn.
   * Protocol metadata only — never copy into DestinaTurnResponse or UI.
   */
  providerTurn?: DestinaProviderTurn;
};

/**
 * Opaque model-turn parts for the same provider's next generate() call.
 * Never interpret, log, or return to Flutter.
 */
export type DestinaProviderTurn = {
  provider: string;
  parts: unknown[];
};

export type DestinaToolCall = {
  id: string;
  name: string;
  arguments: Record<string, unknown>;
};

export type DestinaToolSpec = {
  name: string;
  description: string;
  parameters: Record<string, unknown>;
};

export type DestinaModelGenerateRequest = {
  system: string;
  messages: DestinaChatMessage[];
  tools: DestinaToolSpec[];
};

export type DestinaModelGenerateResult = {
  text: string;
  toolCalls: DestinaToolCall[];
  providerTurn?: DestinaProviderTurn;
};

export interface DestinaModelProvider {
  readonly provider: string;
  readonly model: string;
  generate(req: DestinaModelGenerateRequest): Promise<DestinaModelGenerateResult>;
}

export class DestinaError extends Error {
  constructor(
    public readonly code: string,
    message: string,
    public readonly status = 400,
  ) {
    super(message);
    this.name = "DestinaError";
  }
}
