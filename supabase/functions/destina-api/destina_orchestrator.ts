/**
 * Destina model loop: reason → allowlisted tools → structured reply.
 * Conversational-first: skip redundant Gemini turns when safe.
 */

import {
  DestinaChatMessage,
  DestinaError,
  DestinaHandoff,
  DestinaModelProvider,
  DestinaSuggestedAction,
  DestinaToolCall,
  DestinaToolResult,
  DestinaTurnResponse,
  TripState,
} from "./destina_domain.ts";
import {
  DESTINA_LIMITS,
  DESTINA_SYSTEM_PROMPT,
  customerFacingToolError,
  parseToolArguments,
} from "./destina_rules.ts";
import { withTimeout } from "./destina_model.ts";
import {
  DestinaActor,
  DestinaToolDeps,
  DESTINA_TOOL_SPECS,
  executeDestinaTool,
} from "./destina_tools.ts";
import {
  DestinaLoopMetrics,
  DestinaRequestTrace,
  emptyLoopMetrics,
} from "./destina_observability.ts";

export type DestinaLoopInput = {
  model: DestinaModelProvider;
  deps: DestinaToolDeps;
  actor: DestinaActor;
  conversationId: string;
  tripState: TripState;
  history: DestinaChatMessage[];
  userMessage: string;
  trace?: DestinaRequestTrace;
};

export type DestinaLoopOutput = {
  response: DestinaTurnResponse;
  assistantContent: string;
  toolRuns: DestinaToolResult[];
  tripState: TripState;
  metrics: DestinaLoopMetrics;
};

function suggested(results: DestinaToolResult[], authRequired: boolean): DestinaSuggestedAction[] {
  const actions: DestinaSuggestedAction[] = [];
  if (authRequired) {
    actions.push({ id: "sign_in", label: "Sign in to continue" });
  }
  if (results.some((r) => r.cards?.some((c) => c.kind === "flight_offer"))) {
    actions.push({ id: "send_flights", label: "Send to consultant" });
  }
  if (results.some((r) => r.cards?.some((c) => c.kind !== "flight_offer"))) {
    actions.push({ id: "ask_item", label: "Ask about this" });
    actions.push({ id: "send_item", label: "Send to consultant" });
  }
  if (results.some((r) => r.status === "error" || r.status === "needs_input")) {
    actions.push({ id: "retry", label: "Try again" });
    actions.push({ id: "handoff", label: "Send to travel team" });
  }
  return actions.slice(0, 4);
}

function handoffFrom(results: DestinaToolResult[]): DestinaHandoff | null {
  const hit = results.find((r) =>
    (r.name === "handoff_to_consultant" || r.name.startsWith("create_")) &&
    r.status === "ok" &&
    r.data?.enquiry_id
  );
  if (!hit) return null;
  return {
    created: true,
    enquiry_id: String(hit.data!.enquiry_id),
    reason: String(hit.data!.reason ?? hit.name),
  };
}

function onlyStateUpdates(calls: DestinaToolCall[]): boolean {
  return calls.length > 0 && calls.every((c) => c.name === "update_trip_state");
}

function canParallelize(calls: DestinaToolCall[]): boolean {
  if (calls.length < 2) return false;
  // Never parallelize side-effecting or dependent tools.
  const forbidden = new Set([
    "search_flights",
    "update_trip_state",
    "create_travel_enquiry",
    "create_flight_enquiry",
    "handoff_to_consultant",
  ]);
  if (calls.some((c) => forbidden.has(c.name))) return false;
  return true;
}

export async function runDestinaLoop(
  input: DestinaLoopInput,
): Promise<DestinaLoopOutput> {
  const trace = input.trace;
  const messages: DestinaChatMessage[] = [
    ...input.history.slice(-DESTINA_LIMITS.maxHistoryMessages),
    { role: "user", content: input.userMessage },
  ];
  let tripState = input.tripState;
  const toolRuns: DestinaToolResult[] = [];
  let flightSearchesUsed = 0;
  let catalogCallsUsed = 0;
  let assistantContent = "";
  let authRequired = false;
  const metrics = emptyLoopMetrics();

  const loopStarted = Date.now();
  for (let i = 0; i < DESTINA_LIMITS.maxModelIterations; i++) {
    if (toolRuns.length >= DESTINA_LIMITS.maxToolCalls) break;
    const elapsed = Date.now() - loopStarted;
    if (elapsed >= DESTINA_LIMITS.requestBudgetMs) {
      throw new DestinaError(
        "orchestration_limit",
        "I couldn't finish that just now. I can try again, or I can send this to our travel team.",
        504,
        "orchestration",
      );
    }
    let generated;
    const modelStarted = Date.now();
    const modelBudget = Math.min(
      DESTINA_LIMITS.modelTimeoutMs,
      Math.max(1000, DESTINA_LIMITS.requestBudgetMs - elapsed),
    );
    try {
      generated = await withTimeout(
        input.model.generate({
          system: `${DESTINA_SYSTEM_PROMPT}\n\nCurrent trip state JSON:\n${JSON.stringify(tripState)}`,
          messages,
          tools: DESTINA_TOOL_SPECS,
        }),
        modelBudget,
      );
      const duration = Date.now() - modelStarted;
      metrics.model_calls += 1;
      metrics.total_model_ms += duration;
      metrics.model_iterations = i + 1;
      trace?.modelCompleted({
        iteration: i,
        duration_ms: duration,
        outcome: "ok",
        tool_call_count: generated.toolCalls.length,
        provider: input.model.provider,
        model: input.model.model,
      });
    } catch (e) {
      const duration = Date.now() - modelStarted;
      metrics.model_calls += 1;
      metrics.total_model_ms += duration;
      metrics.model_iterations = i + 1;
      trace?.modelCompleted({
        iteration: i,
        duration_ms: duration,
        outcome: "error",
        tool_call_count: 0,
        provider: input.model.provider,
        model: input.model.model,
      });
      if (e instanceof DestinaError) throw e;
      throw new DestinaError(
        "model_unavailable",
        "I couldn't complete that just now. I can try again, or I can send the request to our travel team.",
        503,
        "model",
      );
    }

    if (generated.toolCalls.length === 0) {
      assistantContent = generated.text.trim() ||
        "How else can I help with your trip?";
      break;
    }

    const naturalText = generated.text.trim();
    const stateOnly = onlyStateUpdates(generated.toolCalls);

    messages.push({
      role: "assistant",
      content: naturalText ||
        generated.toolCalls.map((c) => `tool:${c.name}`).join(","),
      providerTurn: generated.providerTurn,
    });

    const runOne = async (call: DestinaToolCall) => {
      const toolStarted = Date.now();
      trace?.toolStarted(call.name);
      let result: DestinaToolResult;
      try {
        const args = parseToolArguments(call.arguments);
        const executed = await executeDestinaTool(
          input.deps,
          {
            actor: input.actor,
            tripState,
            conversationId: input.conversationId,
            flightSearchesUsed,
            catalogCallsUsed,
            requestId: trace?.requestId,
            onTravelport: (info) => {
              metrics.travelport_calls += 1;
              metrics.travelport_ms += info.duration_ms;
              trace?.travelportCompleted(info);
            },
          },
          call.name,
          args,
        );
        tripState = executed.tripState;
        result = executed.result;
      } catch (e) {
        if (e instanceof DestinaError) {
          result = {
            name: call.name,
            status: "needs_input",
            activity: "Need a bit more detail…",
            summary: customerFacingToolError(e),
            error_code: e.code,
          };
        } else {
          result = {
            name: call.name,
            status: "error",
            activity: "Something went wrong…",
            summary:
              "I hit a snag with that just now. I can try again, or send it to our travel team.",
            error_code: "tool_error",
          };
        }
      }
      const duration = Date.now() - toolStarted;
      metrics.tool_calls += 1;
      metrics.total_tool_ms += duration;
      trace?.toolCompleted({
        tool_name: call.name,
        duration_ms: duration,
        outcome: result.status,
        error_code: result.error_code ?? null,
      });
      return { call, result };
    };

    const batch = generated.toolCalls.slice(
      0,
      DESTINA_LIMITS.maxToolCalls - toolRuns.length,
    );
    const executed = canParallelize(batch)
      ? await Promise.all(batch.map((c) => runOne(c)))
      : await (async () => {
        const out: { call: DestinaToolCall; result: DestinaToolResult }[] = [];
        for (const call of batch) {
          out.push(await runOne(call));
        }
        return out;
      })();

    for (const { call, result } of executed) {
      toolRuns.push(result);
      if (call.name === "search_flights" && result.status !== "needs_input") {
        flightSearchesUsed += 1;
      }
      if (call.name.startsWith("search_") && call.name !== "search_flights") {
        catalogCallsUsed += 1;
      }
      if (result.status === "auth_required") authRequired = true;
      messages.push({
        role: "tool",
        toolName: call.name,
        toolCallId: call.id,
        content: JSON.stringify({
          status: result.status,
          summary: result.summary,
          data: result.data ?? null,
          error_code: result.error_code ?? null,
        }),
      });
    }

    // Optimization: conversational text + only update_trip_state → return now.
    if (stateOnly && naturalText) {
      assistantContent = naturalText;
      break;
    }

    // If tools asked for clarification, prefer natural text or tool summary.
    if (
      executed.every((e) =>
        e.result.status === "needs_input" || e.result.status === "auth_required"
      )
    ) {
      assistantContent = naturalText ||
        executed[executed.length - 1]?.result.summary ||
        "I need a little more detail before I can continue.";
      break;
    }
  }

  if (!assistantContent) {
    const last = toolRuns[toolRuns.length - 1];
    assistantContent = last?.summary ||
      "How else can I help plan this trip?";
  }

  if (trace) {
    Object.assign(trace.metrics, metrics);
  }

  return {
    assistantContent,
    toolRuns,
    tripState,
    metrics,
    response: {
      conversation_id: input.conversationId,
      message: { role: "assistant", content: assistantContent },
      trip_state: tripState,
      tool_results: toolRuns,
      suggested_actions: suggested(toolRuns, authRequired),
      handoff: handoffFrom(toolRuns),
      auth_required: authRequired,
      model: {
        provider: input.model.provider,
        name: input.model.model,
        configured: true,
      },
    },
  };
}
