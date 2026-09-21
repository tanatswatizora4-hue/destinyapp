/**
 * Destina model loop: reason → allowlisted tools → structured reply.
 */

import {
  DestinaChatMessage,
  DestinaError,
  DestinaHandoff,
  DestinaModelProvider,
  DestinaSuggestedAction,
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

export type DestinaLoopInput = {
  model: DestinaModelProvider;
  deps: DestinaToolDeps;
  actor: DestinaActor;
  conversationId: string;
  tripState: TripState;
  history: DestinaChatMessage[];
  userMessage: string;
};

export type DestinaLoopOutput = {
  response: DestinaTurnResponse;
  assistantContent: string;
  toolRuns: DestinaToolResult[];
  tripState: TripState;
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
  if (results.some((r) => r.status === "error")) {
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

export async function runDestinaLoop(
  input: DestinaLoopInput,
): Promise<DestinaLoopOutput> {
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

  for (let i = 0; i < DESTINA_LIMITS.maxModelIterations; i++) {
    if (toolRuns.length >= DESTINA_LIMITS.maxToolCalls) break;
    let generated;
    try {
      generated = await withTimeout(
        input.model.generate({
          system: `${DESTINA_SYSTEM_PROMPT}\n\nCurrent trip state JSON:\n${JSON.stringify(tripState)}`,
          messages,
          tools: DESTINA_TOOL_SPECS,
        }),
      );
    } catch (e) {
      if (e instanceof DestinaError) throw e;
      throw new DestinaError(
        "model_unavailable",
        "I couldn't complete that just now. I can try again, or I can send the request to our travel team.",
        503,
      );
    }

    if (generated.toolCalls.length === 0) {
      assistantContent = generated.text.trim() ||
        "How else can I help with your trip?";
      break;
    }

    messages.push({
      role: "assistant",
      content: generated.text.trim() ||
        generated.toolCalls.map((c) => `tool:${c.name}`).join(","),
      providerTurn: generated.providerTurn,
    });

    for (const call of generated.toolCalls) {
      if (toolRuns.length >= DESTINA_LIMITS.maxToolCalls) break;
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
  }

  if (!assistantContent) {
    const last = toolRuns[toolRuns.length - 1];
    assistantContent = last?.summary ||
      "How else can I help plan this trip?";
  }

  return {
    assistantContent,
    toolRuns,
    tripState,
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
