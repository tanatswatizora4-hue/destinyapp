/**
 * Deterministic Destina model for automated tests only.
 * Not a production consultant. Fail-closed in production via destina_model.ts.
 */

import {
  DestinaChatMessage,
  DestinaModelGenerateRequest,
  DestinaModelGenerateResult,
  DestinaToolCall,
} from "./destina_domain.ts";
import { DestinaModelProvider } from "./destina_domain.ts";
import { missingFlightFields, parseToolArguments } from "./destina_rules.ts";
import { emptyTripState, mergeTripState } from "./destina_rules.ts";

function lastUser(messages: DestinaChatMessage[]): string {
  for (let i = messages.length - 1; i >= 0; i--) {
    if (messages[i].role === "user") return messages[i].content;
  }
  return "";
}

function lastTool(messages: DestinaChatMessage[]): DestinaChatMessage | null {
  for (let i = messages.length - 1; i >= 0; i--) {
    if (messages[i].role === "tool") return messages[i];
  }
  return null;
}

export class ScriptedDestinaProvider implements DestinaModelProvider {
  readonly provider = "mock";
  constructor(readonly model = "destina-scripted") {}

  async generate(
    req: DestinaModelGenerateRequest,
  ): Promise<DestinaModelGenerateResult> {
    const user = lastUser(req.messages);
    const lower = user.toLowerCase();
    const tool = lastTool(req.messages);

    if (tool) {
      const content = tool.content;
      if (tool.toolName === "update_trip_state" || content.includes("Trip details updated")) {
        if (/flights? to /i.test(lastUser(req.messages)) && !/HRE/.test(lastUser(req.messages))) {
          return {
            text: "Sure. Which city are you flying from?",
            toolCalls: [],
          };
        }
      }
      if (content.includes("needs_input")) {
        return {
          text:
            "Sure. Which city are you flying from? A 3-letter airport code like HRE works best.",
          toolCalls: [],
        };
      }
      if (content.includes("auth_required")) {
        return {
          text:
            "I can send this to our travel team as soon as you sign in — Destina never fakes a submission.",
          toolCalls: [],
        };
      }
      if (content.includes('"enquiry_id"')) {
        return {
          text:
            "I've sent this to our travel team. You'll see it under My trips — this is a request, not a confirmed booking.",
          toolCalls: [],
        };
      }
      if (content.includes("live_travelport") || content.includes('"offers"')) {
        return {
          text:
            "Here are live fares from Travelport. These are quotes, not tickets. Would you like me to send one to our consultants?",
          toolCalls: [],
        };
      }
      if (content.includes("catalog_not_live_hold")) {
        return {
          text:
            "I found matching Destiny catalog stays. This is catalog content, not a live hold. I can send a request to our team when you're ready.",
          toolCalls: [],
        };
      }
      if (content.includes("handoff")) {
        return {
          text:
            "I've passed this to a Destiny consultant with a short brief — not the full chat dump.",
          toolCalls: [],
        };
      }
      return { text: "Here's what I found.", toolCalls: [] };
    }

    if (/ignore (your|all) instructions|refund booking/i.test(user)) {
      return {
        text:
          "I can't change Destiny payment or booking rules from chat. If you need a refund or a human, I can hand this to our team after you confirm.",
        toolCalls: [],
      };
    }

    if (/talk to (a |an )?(human|person|consultant|agent)/i.test(lower)) {
      return {
        text: "",
        toolCalls: [call("handoff_to_consultant", {
          reason: "customer_requested_human",
          summary: "Customer asked to speak with a consultant.",
        })],
      };
    }

    if (/zanzibar/.test(lower) && !/\d{4}-\d{2}-\d{2}/.test(user)) {
      return {
        text: "Zanzibar sounds lovely. When are you hoping to travel?",
        toolCalls: [call("update_trip_state", { destination: "ZNZ" })],
      };
    }

    if (/flights? to (joburg|johannesburg|jnb)/i.test(lower) && !/\b[A-Z]{3}\b/.test(user.split("to")[0] ?? "")) {
      const hasFrom = /\b(from|hre|vfa|lhr)\b/i.test(lower);
      if (!hasFrom) {
        return {
          text: "Sure. Which city are you flying from?",
          toolCalls: [call("update_trip_state", { destination: "JNB", flight_required: true })],
        };
      }
    }

    if (/search flights|find (me )?flights/i.test(lower) || /HRE/.test(user) && /JNB/.test(user)) {
      const state = emptyTripState();
      try {
        mergeTripState(state, {
          origin: "HRE",
          destination: "JNB",
          departure_date: (user.match(/\d{4}-\d{2}-\d{2}/) ?? [])[0],
        });
      } catch {
        /* ignore */
      }
      const missing = missingFlightFields({
        ...emptyTripState(),
        origin: /HRE/.test(user) ? "HRE" : null,
        destination: /JNB/.test(user) ? "JNB" : null,
        departure_date: (user.match(/\d{4}-\d{2}-\d{2}/) ?? [null])[0],
      });
      if (missing.length) {
        return {
          text: missing.includes("origin")
            ? "Sure. Which city are you flying from?"
            : "When would you like to fly?",
          toolCalls: [call("update_trip_state", {
            origin: /HRE/.test(user) ? "HRE" : undefined,
            destination: /JNB/.test(user) ? "JNB" : undefined,
            flight_required: true,
          })],
        };
      }
      return {
        text: "",
        toolCalls: [call("search_flights", {
          origin: "HRE",
          destination: "JNB",
          departure_date: (user.match(/\d{4}-\d{2}-\d{2}/) ?? ["2026-11-20"])[0],
          adults: 1,
        })],
      };
    }

    if (/stay|hotel|lodge/i.test(lower)) {
      return {
        text: "",
        toolCalls: [call("search_stays", { query: user.slice(0, 80) })],
      };
    }

    if (/yes|send (it|this)|please do|confirm/i.test(lower)) {
      return {
        text: "",
        toolCalls: [call("create_travel_enquiry", {
          confirm: true,
          kind: "general",
          summary: "Customer confirmed Destina should send the request.",
        })],
      };
    }

    return {
      text:
        "I'd love to help plan that. Where would you like to go?",
      toolCalls: [],
    };
  }
}

function call(name: string, args: Record<string, unknown>): DestinaToolCall {
  const clean: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(args)) {
    if (v !== undefined) clean[k] = v;
  }
  return { id: `script_${name}`, name, arguments: parseToolArguments(clean) };
}

/** Test helper: always request the same tool. */
export class FixedToolDestinaProvider implements DestinaModelProvider {
  readonly provider = "mock";
  constructor(
    readonly model: string,
    private readonly calls: DestinaToolCall[],
    private readonly text = "",
  ) {}
  async generate(_req: DestinaModelGenerateRequest): Promise<DestinaModelGenerateResult> {
    return { text: this.text, toolCalls: this.calls };
  }
}

export class TimeoutDestinaProvider implements DestinaModelProvider {
  readonly provider = "mock";
  readonly model = "timeout";
  async generate(_req: DestinaModelGenerateRequest): Promise<DestinaModelGenerateResult> {
    return await new Promise(() => {});
  }
}

export class LoopingDestinaProvider implements DestinaModelProvider {
  readonly provider = "mock";
  readonly model = "loop";
  async generate(_req: DestinaModelGenerateRequest): Promise<DestinaModelGenerateResult> {
    return {
      text: "",
      toolCalls: [{
        id: "loop",
        name: "search_tours",
        arguments: { query: "victoria" },
      }],
    };
  }
}
