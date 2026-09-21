class DestinaTripState {
  final String? destination;
  final String? origin;
  final String? departureDate;
  final String? returnDate;
  final int adults;
  final int children;
  final int infants;
  final bool confirmedForEnquiry;

  const DestinaTripState({
    this.destination,
    this.origin,
    this.departureDate,
    this.returnDate,
    this.adults = 1,
    this.children = 0,
    this.infants = 0,
    this.confirmedForEnquiry = false,
  });

  factory DestinaTripState.fromJson(Map<String, dynamic>? json) {
    final m = json ?? const <String, dynamic>{};
    return DestinaTripState(
      destination: m['destination']?.toString(),
      origin: m['origin']?.toString(),
      departureDate: m['departure_date']?.toString(),
      returnDate: m['return_date']?.toString(),
      adults: int.tryParse('${m['adults'] ?? 1}') ?? 1,
      children: int.tryParse('${m['children'] ?? 0}') ?? 0,
      infants: int.tryParse('${m['infants'] ?? 0}') ?? 0,
      confirmedForEnquiry: m['confirmed_for_enquiry'] == true,
    );
  }

  String get routeLabel {
    if ((origin ?? '').isEmpty && (destination ?? '').isEmpty) return '';
    return '${origin ?? '—'} → ${destination ?? '—'}';
  }
}

class DestinaCard {
  final String kind;
  final String source;
  final String? availability;
  final Map<String, dynamic> payload;

  const DestinaCard({
    required this.kind,
    required this.source,
    this.availability,
    required this.payload,
  });

  factory DestinaCard.fromJson(Map<String, dynamic> json) {
    final kind = json['kind']?.toString() ?? '';
    if (kind == 'flight_offer') {
      return DestinaCard(
        kind: kind,
        source: json['source']?.toString() ?? 'live_travelport',
        payload: Map<String, dynamic>.from(json['offer'] as Map? ?? const {}),
      );
    }
    return DestinaCard(
      kind: kind,
      source: json['source']?.toString() ?? 'destiny_catalog',
      availability: json['availability']?.toString(),
      payload: Map<String, dynamic>.from(json['item'] as Map? ?? const {}),
    );
  }
}

class DestinaToolResult {
  final String name;
  final String status;
  final String activity;
  final String summary;
  final List<DestinaCard> cards;

  const DestinaToolResult({
    required this.name,
    required this.status,
    required this.activity,
    required this.summary,
    this.cards = const [],
  });

  factory DestinaToolResult.fromJson(Map<String, dynamic> json) {
    return DestinaToolResult(
      name: json['name']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      activity: json['activity']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      cards: (json['cards'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => DestinaCard.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false),
    );
  }
}

class DestinaSuggestedAction {
  final String id;
  final String label;
  const DestinaSuggestedAction({required this.id, required this.label});

  factory DestinaSuggestedAction.fromJson(Map<String, dynamic> json) {
    return DestinaSuggestedAction(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
    );
  }
}

class DestinaTurn {
  final String conversationId;
  final String assistantMessage;
  final DestinaTripState tripState;
  final List<DestinaToolResult> toolResults;
  final List<DestinaSuggestedAction> suggestedActions;
  final String? enquiryId;
  final bool authRequired;
  final bool modelConfigured;

  const DestinaTurn({
    required this.conversationId,
    required this.assistantMessage,
    required this.tripState,
    this.toolResults = const [],
    this.suggestedActions = const [],
    this.enquiryId,
    this.authRequired = false,
    this.modelConfigured = true,
  });

  factory DestinaTurn.fromJson(Map<String, dynamic> json) {
    final message = json['message'] is Map
        ? Map<String, dynamic>.from(json['message'] as Map)
        : const <String, dynamic>{};
    final handoff = json['handoff'] is Map
        ? Map<String, dynamic>.from(json['handoff'] as Map)
        : null;
    final model = json['model'] is Map
        ? Map<String, dynamic>.from(json['model'] as Map)
        : const <String, dynamic>{};
    return DestinaTurn(
      conversationId: json['conversation_id']?.toString() ?? '',
      assistantMessage: message['content']?.toString() ??
          json['message']?.toString() ??
          '',
      tripState: DestinaTripState.fromJson(
        json['trip_state'] is Map
            ? Map<String, dynamic>.from(json['trip_state'] as Map)
            : null,
      ),
      toolResults: (json['tool_results'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => DestinaToolResult.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false),
      suggestedActions: (json['suggested_actions'] as List? ?? const [])
          .whereType<Map>()
          .map((e) =>
              DestinaSuggestedAction.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false),
      enquiryId: handoff?['enquiry_id']?.toString(),
      authRequired: json['auth_required'] == true,
      modelConfigured: model['configured'] != false,
    );
  }
}

class DestinaChatMessage {
  final String role;
  final String content;
  final List<DestinaCard> cards;
  final String? activity;
  final DateTime? createdAt;

  const DestinaChatMessage({
    required this.role,
    required this.content,
    this.cards = const [],
    this.activity,
    this.createdAt,
  });
}
