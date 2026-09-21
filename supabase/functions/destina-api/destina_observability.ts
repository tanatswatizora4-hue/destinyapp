/**
 * Sanitized Destina request observability.
 * Never log customer text, prompts, thought signatures, or secrets.
 */

export type DestinaFailureStage =
  | "model"
  | "tool"
  | "travelport"
  | "orchestration"
  | "persistence"
  | "airport_resolution"
  | "unknown_internal";

export type DestinaSafeErrorCode =
  | "model_timeout"
  | "model_429"
  | "model_5xx"
  | "model_invalid_argument"
  | "model_network_error"
  | "model_auth_error"
  | "model_unavailable"
  | "model_not_configured"
  | "tool_validation"
  | "airport_resolution"
  | "airport_ambiguous"
  | "travelport_timeout"
  | "travelport_auth"
  | "travelport_provider_error"
  | "orchestration_limit"
  | "persistence_error"
  | "unknown_internal"
  | "unauthorized"
  | "forbidden"
  | "not_found"
  | "validation_error"
  | "missing_provider_continuation";

export type DestinaObsEvent =
  | {
    event: "destina_request_started";
    request_id: string;
    authenticated: boolean;
    action: string;
  }
  | {
    event: "destina_model_call_completed";
    request_id: string;
    iteration: number;
    duration_ms: number;
    outcome: "ok" | "error";
    tool_call_count: number;
    provider: string;
    model: string;
  }
  | {
    event: "destina_model_retry";
    request_id: string;
    iteration: number;
    reason: string;
    retry_number: number;
  }
  | {
    event: "destina_tool_started";
    request_id: string;
    tool_name: string;
  }
  | {
    event: "destina_tool_completed";
    request_id: string;
    tool_name: string;
    duration_ms: number;
    outcome: string;
    error_code?: string | null;
  }
  | {
    event: "destina_travelport_search_completed";
    request_id: string;
    duration_ms: number;
    outcome: "ok" | "error";
    error_code?: string | null;
    offer_count: number;
  }
  | {
    event: "destina_request_completed";
    request_id: string;
    total_ms: number;
    model_calls: number;
    total_model_ms: number;
    tool_calls: number;
    total_tool_ms: number;
    model_iterations: number;
    outcome: "ok" | "error";
  }
  | {
    event: "destina_request_failed";
    request_id: string;
    stage: DestinaFailureStage;
    error_code: string;
    http_status?: number;
    total_ms: number;
    model_calls: number;
    tool_calls: number;
  }
  | {
    event: "destina_model_provider_error";
    request_id?: string;
    provider: "gemini";
    model: string;
    http_status: number;
    provider_status: string | null;
    provider_code: string | number | null;
    provider_message: string;
  };

export type DestinaObsSink = (event: DestinaObsEvent) => void;

const FORBIDDEN_LOG =
  /customer|message|prompt|thought|signature|api[_-]?key|authorization|service_role|jwt|password|secret|travelport.?credential|bearer/i;

export function newDestinaRequestId(): string {
  try {
    return crypto.randomUUID();
  } catch {
    return `destina_${Date.now()}_${Math.random().toString(36).slice(2, 10)}`;
  }
}

export function assertSafeObsEvent(event: DestinaObsEvent): DestinaObsEvent {
  const encoded = JSON.stringify(event);
  if (
    /AIza[0-9A-Za-z_-]{8,}/.test(encoded) ||
    /"thoughtSignature"\s*:/.test(encoded) ||
    /service_role/i.test(encoded)
  ) {
    throw new Error("refusing to emit unsafe Destina observability event");
  }
  for (const key of Object.keys(event as object)) {
    if (FORBIDDEN_LOG.test(key) && key !== "provider_message" && key !== "error_code") {
      throw new Error(`refusing to log field '${key}'`);
    }
  }
  return event;
}

export function defaultObsSink(event: DestinaObsEvent): void {
  console.warn(JSON.stringify(assertSafeObsEvent(event)));
}

export function classifyDestinaErrorCode(code: string): {
  stage: DestinaFailureStage;
  error_code: string;
} {
  switch (code) {
    case "model_timeout":
      return { stage: "model", error_code: "model_timeout" };
    case "model_429":
      return { stage: "model", error_code: "model_429" };
    case "model_5xx":
      return { stage: "model", error_code: "model_5xx" };
    case "model_invalid_argument":
      return { stage: "model", error_code: "model_invalid_argument" };
    case "model_network_error":
      return { stage: "model", error_code: "model_network_error" };
    case "model_auth_error":
      return { stage: "model", error_code: "model_auth_error" };
    case "model_unavailable":
    case "model_not_configured":
    case "missing_provider_continuation":
      return { stage: "model", error_code: code };
    case "airport_unresolved":
    case "airport_resolution":
      return { stage: "airport_resolution", error_code: "airport_resolution" };
    case "airport_ambiguous":
      return { stage: "airport_resolution", error_code: "airport_ambiguous" };
    case "travelport_timeout":
      return { stage: "travelport", error_code: "travelport_timeout" };
    case "travelport_auth":
    case "auth_failed":
      return { stage: "travelport", error_code: "travelport_auth" };
    case "travelport_failure":
    case "travelport_provider_error":
      return { stage: "travelport", error_code: "travelport_provider_error" };
    case "flight_search_limit":
    case "orchestration_limit":
      return { stage: "orchestration", error_code: "orchestration_limit" };
    case "invalid_place":
    case "validation_error":
    case "tool_validation":
      return { stage: "tool", error_code: "tool_validation" };
    case "persistence_error":
      return { stage: "persistence", error_code: "persistence_error" };
    default:
      return { stage: "unknown_internal", error_code: code || "unknown_internal" };
  }
}

export type DestinaLoopMetrics = {
  model_calls: number;
  total_model_ms: number;
  tool_calls: number;
  total_tool_ms: number;
  model_iterations: number;
  travelport_calls: number;
  travelport_ms: number;
};

export function emptyLoopMetrics(): DestinaLoopMetrics {
  return {
    model_calls: 0,
    total_model_ms: 0,
    tool_calls: 0,
    total_tool_ms: 0,
    model_iterations: 0,
    travelport_calls: 0,
    travelport_ms: 0,
  };
}

export class DestinaRequestTrace {
  readonly requestId: string;
  readonly startedAt: number;
  private readonly sink: DestinaObsSink;
  metrics = emptyLoopMetrics();
  private failed = false;

  constructor(
    opts: { requestId?: string; sink?: DestinaObsSink } = {},
  ) {
    this.requestId = opts.requestId ?? newDestinaRequestId();
    this.startedAt = Date.now();
    this.sink = opts.sink ?? defaultObsSink;
  }

  emit(event: DestinaObsEvent): void {
    try {
      this.sink(assertSafeObsEvent(event));
    } catch {
      // Observability must never break the request.
    }
  }

  start(authenticated: boolean, action: string): void {
    this.emit({
      event: "destina_request_started",
      request_id: this.requestId,
      authenticated,
      action,
    });
  }

  modelCompleted(input: {
    iteration: number;
    duration_ms: number;
    outcome: "ok" | "error";
    tool_call_count: number;
    provider: string;
    model: string;
  }): void {
    this.metrics.model_calls += 1;
    this.metrics.total_model_ms += input.duration_ms;
    this.metrics.model_iterations = Math.max(
      this.metrics.model_iterations,
      input.iteration + 1,
    );
    this.emit({
      event: "destina_model_call_completed",
      request_id: this.requestId,
      ...input,
    });
  }

  modelRetry(input: {
    iteration: number;
    reason: string;
    retry_number: number;
  }): void {
    this.emit({
      event: "destina_model_retry",
      request_id: this.requestId,
      ...input,
    });
  }

  toolStarted(tool_name: string): void {
    this.emit({
      event: "destina_tool_started",
      request_id: this.requestId,
      tool_name,
    });
  }

  toolCompleted(input: {
    tool_name: string;
    duration_ms: number;
    outcome: string;
    error_code?: string | null;
  }): void {
    this.metrics.tool_calls += 1;
    this.metrics.total_tool_ms += input.duration_ms;
    this.emit({
      event: "destina_tool_completed",
      request_id: this.requestId,
      ...input,
    });
  }

  travelportCompleted(input: {
    duration_ms: number;
    outcome: "ok" | "error";
    error_code?: string | null;
    offer_count: number;
  }): void {
    this.metrics.travelport_calls += 1;
    this.metrics.travelport_ms += input.duration_ms;
    this.emit({
      event: "destina_travelport_search_completed",
      request_id: this.requestId,
      ...input,
    });
  }

  complete(outcome: "ok" | "error" = "ok"): void {
    this.emit({
      event: "destina_request_completed",
      request_id: this.requestId,
      total_ms: Date.now() - this.startedAt,
      model_calls: this.metrics.model_calls,
      total_model_ms: this.metrics.total_model_ms,
      tool_calls: this.metrics.tool_calls,
      total_tool_ms: this.metrics.total_tool_ms,
      model_iterations: this.metrics.model_iterations,
      outcome,
    });
  }

  fail(
    code: string,
    http_status?: number,
  ): void {
    if (this.failed) return;
    this.failed = true;
    const classified = classifyDestinaErrorCode(code);
    this.emit({
      event: "destina_request_failed",
      request_id: this.requestId,
      stage: classified.stage,
      error_code: classified.error_code,
      http_status,
      total_ms: Date.now() - this.startedAt,
      model_calls: this.metrics.model_calls,
      tool_calls: this.metrics.tool_calls,
    });
  }
}
