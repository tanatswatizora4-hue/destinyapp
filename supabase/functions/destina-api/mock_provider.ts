/**
 * Deterministic Destina model for automated tests only.
 * Not a production consultant. Fail-closed in production via destina_model.ts.
 */

import {
  DestinaChatMessage,
  DestinaModelGenerateRequest,
  DestinaModelGenerateResult,
  DestinaToolCall,
  TripState,
} from "./destina_domain.ts";
import { DestinaModelProvider } from "./destina_domain.ts";
import { missingFlightFields, parseToolArguments } from "./destina_rules.ts";
import { emptyTripState } from "./destina_rules.ts";

function lastUser(messages: DestinaChatMessage[]): string {
  for (let i = messages.length - 1; i >= 0; i--) {
    if (messages[i].role === "user") return messages[i].content;
  }
  return "";
}

function tripFromSystem(system: string): TripState {
  const marker = "Current trip state JSON:";
  const idx = system.indexOf(marker);
  if (idx < 0) return emptyTripState();
  try {
    const parsed = JSON.parse(system.slice(idx + marker.length).trim());
    if (parsed && typeof parsed === "object") {
      return { ...emptyTripState(), ...parsed as TripState };
    }
  } catch {
    // Scripted model ignores malformed injected state.
  }
  return emptyTripState();
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
    const lower = user.toLowerCase().trim();
    const tool = lastTool(req.messages);
    const trip = tripFromSystem(req.system);

    if (tool) {
      if (tool.toolName === "update_trip_state" || tool.content.includes("Trip details updated")) {
        if (/zanzibar/i.test(user) && !/flight/i.test(user)) {
          return {
            text:
              "Zanzibar is a great choice. Are you thinking of a relaxing beach trip, exploring Stone Town, or a bit of both?",
            toolCalls: [],
          };
        }
        if (/flights?/i.test(user)) {
          if (!trip.origin) {
            return {
              text: "Sure. Which city are you flying from?",
              toolCalls: [],
            };
          }
          if (!trip.destination) {
            return {
              text: "Where would you like to fly to?",
              toolCalls: [],
            };
          }
          if (!trip.departure_date) {
            return {
              text: "When would you like to fly?",
              toolCalls: [],
            };
          }
        }
        return {
          text: "Got it. How else can I help with this trip?",
          toolCalls: [],
        };
      }
      if (tool.content.includes("needs_input")) {
        return {
          text: "Which airport or city would you like to fly from?",
          toolCalls: [],
        };
      }
      if (tool.content.includes("auth_required")) {
        return {
          text:
            "I can send this to our travel team as soon as you sign in — Destina never fakes a submission.",
          toolCalls: [],
        };
      }
      if (tool.content.includes('"enquiry_id"')) {
        return {
          text:
            "I've sent this to our travel team. You'll see it under My trips — this is a request, not a confirmed booking.",
          toolCalls: [],
        };
      }
      if (tool.content.includes("live_travelport") || tool.content.includes('"offers"')) {
        return {
          text:
            "Here are live fares from Travelport. These are quotes, not tickets. Would you like me to send one to our consultants?",
          toolCalls: [],
        };
      }
      if (tool.content.includes("catalog_not_live_hold")) {
        return {
          text:
            "I found matching Destiny catalog stays. This is catalog content, not a live hold. I can send a request to our team when you're ready.",
          toolCalls: [],
        };
      }
      if (tool.content.includes("handoff") || tool.toolName === "list_customer_bookings") {
        if (tool.toolName === "list_customer_bookings") {
          return {
            text: "Here are the booking requests I can see on your account.",
            toolCalls: [],
          };
        }
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

    if (/^(hi|hello|hey)\b/.test(lower)) {
      return {
        text: "Hi, I'm Destina. How can I help with your trip today?",
        toolCalls: [],
      };
    }

    if (/talk to (a |an )?(human|person|consultant|agent)|send this to (a |the )?(consultant|team)/i.test(lower)) {
      return {
        text: "",
        toolCalls: [call("handoff_to_consultant", {
          reason: "customer_requested_human",
          summary: "Customer asked to speak with a consultant.",
        })],
      };
    }

    if (/booking|my trips/i.test(lower) && /status|what('s| is) happening/i.test(lower)) {
      return {
        text: "",
        toolCalls: [call("list_customer_bookings", {})],
      };
    }

    if (/destiny('s)? .{0,40}(package|tour|catalog)|show me destiny/i.test(lower)) {
      return {
        text: "",
        toolCalls: [call("search_tours", { query: user.slice(0, 80) })],
      };
    }

    if (
      /search flights|find (me )?(a )?flights?|flight from /i.test(lower) ||
      (/HRE/.test(user) && /JNB/.test(user) && /search flights|find/i.test(lower))
    ) {
      const fromHarare = /harare|hre/i.test(lower);
      const toJnb = /johannesburg|joburg|jnb/i.test(lower);
      const toZnz = /zanzibar|znz/i.test(lower);
      const date = (user.match(/\d{4}-\d{2}-\d{2}/) ?? [null])[0];
      const origin = fromHarare ? "Harare" : trip.origin;
      const destination = toZnz
        ? "Zanzibar"
        : (toJnb ? "Johannesburg" : trip.destination);
      const departureDate = date ?? trip.departure_date;
      if (fromHarare && (toJnb || toZnz) && date) {
        return {
          text: "",
          toolCalls: [call("search_flights", {
            origin: /hre/i.test(user) && !/harare/i.test(user) ? "HRE" : "Harare",
            destination: toZnz ? "Zanzibar" : (toJnb ? "Johannesburg" : "JNB"),
            departure_date: date,
            adults: 1,
          })],
        };
      }
      if (/HRE/.test(user) && /JNB/.test(user) && date) {
        return {
          text: "",
          toolCalls: [call("search_flights", {
            origin: "HRE",
            destination: "JNB",
            departure_date: date,
            adults: 1,
          })],
        };
      }
      const missing = missingFlightFields({
        ...trip,
        origin,
        destination,
        departure_date: departureDate,
      });
      if (missing.length) {
        return {
          text: missing.includes("origin")
            ? "Sure. Which city are you flying from?"
            : missing.includes("destination")
            ? "Where would you like to fly to?"
            : "When would you like to fly?",
          toolCalls: [call("update_trip_state", {
            origin: origin ?? undefined,
            destination: destination ?? undefined,
            flight_required: true,
          })],
        };
      }
    }

    if (
      /top \d|places to visit|good in |what should i pack|tell me about|haha|that'?s expensive|what about |mostly beaches/i
        .test(lower)
    ) {
      const packing = /pack/i.test(lower);
      const place = trip.destination || "that destination";
      return {
        text: packing
          ? `For ${place} I'd pack light layers, reef-safe sunscreen, and something smart-casual for evenings. This is general advice, not a live packing list.`
          : /october|what about /i.test(lower)
          ? `${place} in October is generally warm and inviting. That's seasonal guidance, not a live weather report.`
          : /places to visit/i.test(lower)
          ? "If you want inspiration this month: Zanzibar for beaches and spice, Victoria Falls for drama, and Cape Town for city-plus-nature. I can look up Destiny packages when you want specifics."
          : /mauritius/i.test(lower)
          ? "Mauritius is a classic Indian Ocean mix of lagoons and resort time. I can look up Destiny packages or live flights when you want specifics — I never invent fares."
          : /expensive/i.test(lower)
          ? "Understood — we can look at a simpler mix, travel mid-week, or wait until you're ready for a live quote. I won't invent a cheaper fare."
          : "Happy to keep chatting about that. What would you like to plan next?",
        toolCalls: [],
      };
    }

    if (/i want to go to|let's go to|planning (a trip )?to /i.test(lower)) {
      const dest = /zanzibar/i.test(lower) ? "Zanzibar" : null;
      return {
        text: "",
        toolCalls: dest
          ? [call("update_trip_state", { destination: dest })]
          : [],
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
      text: "I'd love to help plan that. Where would you like to go?",
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

/** Scripted turns for conversational-first tests. */
export class SequenceDestinaProvider implements DestinaModelProvider {
  readonly provider = "mock";
  requests: DestinaModelGenerateRequest[] = [];
  constructor(
    readonly model: string,
    private readonly steps: DestinaModelGenerateResult[],
  ) {}
  async generate(req: DestinaModelGenerateRequest): Promise<DestinaModelGenerateResult> {
    this.requests.push(req);
    return this.steps.shift() ?? { text: "How else can I help with your trip?", toolCalls: [] };
  }
}
