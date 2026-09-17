class FlightMoney {
  final double amount;
  final String currency;

  const FlightMoney({required this.amount, required this.currency});

  factory FlightMoney.fromJson(Map<String, dynamic> json) {
    return FlightMoney(
      amount: double.tryParse(json['amount']?.toString() ?? '') ?? 0,
      currency: json['currency']?.toString() ?? 'USD',
    );
  }

  String get label {
    final code = currency.toUpperCase();
    return '$code ${amount.toStringAsFixed(2)}';
  }
}

class FlightAirport {
  final String code;
  final String? name;

  const FlightAirport({required this.code, this.name});

  factory FlightAirport.fromJson(Map<String, dynamic> json) {
    return FlightAirport(
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString(),
    );
  }
}

class FlightCarrier {
  final String code;
  final String? name;

  const FlightCarrier({required this.code, this.name});

  factory FlightCarrier.fromJson(Map<String, dynamic> json) {
    return FlightCarrier(
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString(),
    );
  }

  String get displayName => (name != null && name!.isNotEmpty) ? name! : code;
}

class FlightSegment {
  final FlightAirport origin;
  final FlightAirport destination;
  final DateTime? departure;
  final DateTime? arrival;
  final int? durationMinutes;
  final FlightCarrier carrier;
  final String flightNumber;
  final String? cabin;

  const FlightSegment({
    required this.origin,
    required this.destination,
    this.departure,
    this.arrival,
    this.durationMinutes,
    required this.carrier,
    required this.flightNumber,
    this.cabin,
  });

  factory FlightSegment.fromJson(Map<String, dynamic> json) {
    return FlightSegment(
      origin: FlightAirport.fromJson(
        Map<String, dynamic>.from(json['origin'] as Map? ?? const {}),
      ),
      destination: FlightAirport.fromJson(
        Map<String, dynamic>.from(json['destination'] as Map? ?? const {}),
      ),
      departure: DateTime.tryParse(json['departure']?.toString() ?? ''),
      arrival: DateTime.tryParse(json['arrival']?.toString() ?? ''),
      durationMinutes:
          int.tryParse(json['duration_minutes']?.toString() ?? ''),
      carrier: FlightCarrier.fromJson(
        Map<String, dynamic>.from(json['carrier'] as Map? ?? const {}),
      ),
      flightNumber: json['flight_number']?.toString() ?? '',
      cabin: json['cabin']?.toString(),
    );
  }
}

class FlightItinerary {
  final FlightAirport origin;
  final FlightAirport destination;
  final DateTime? departure;
  final DateTime? arrival;
  final int? durationMinutes;
  final int stops;
  final List<FlightSegment> segments;

  const FlightItinerary({
    required this.origin,
    required this.destination,
    this.departure,
    this.arrival,
    this.durationMinutes,
    required this.stops,
    required this.segments,
  });

  factory FlightItinerary.fromJson(Map<String, dynamic> json) {
    final segs = (json['segments'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => FlightSegment.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
    return FlightItinerary(
      origin: FlightAirport.fromJson(
        Map<String, dynamic>.from(json['origin'] as Map? ?? const {}),
      ),
      destination: FlightAirport.fromJson(
        Map<String, dynamic>.from(json['destination'] as Map? ?? const {}),
      ),
      departure: DateTime.tryParse(json['departure']?.toString() ?? ''),
      arrival: DateTime.tryParse(json['arrival']?.toString() ?? ''),
      durationMinutes:
          int.tryParse(json['duration_minutes']?.toString() ?? ''),
      stops: int.tryParse(json['stops']?.toString() ?? '') ??
          (segs.length > 1 ? segs.length - 1 : 0),
      segments: segs,
    );
  }

  String get stopsLabel {
    if (stops <= 0) return 'Nonstop';
    if (stops == 1) return '1 stop';
    return '$stops stops';
  }

  String get durationLabel {
    final mins = durationMinutes;
    if (mins == null || mins <= 0) return '';
    final h = mins ~/ 60;
    final m = mins % 60;
    if (h <= 0) return '${m}m';
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }
}

class FlightProviderRef {
  final String provider;
  final String transactionId;
  final String offerId;
  final List<String> productIds;
  final int? sequence;

  const FlightProviderRef({
    required this.provider,
    required this.transactionId,
    required this.offerId,
    required this.productIds,
    this.sequence,
  });

  factory FlightProviderRef.fromJson(Map<String, dynamic> json) {
    return FlightProviderRef(
      provider: json['provider']?.toString() ?? 'travelport',
      transactionId: json['transaction_id']?.toString() ?? '',
      offerId: json['offer_id']?.toString() ?? '',
      productIds: (json['product_ids'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
      sequence: int.tryParse(json['sequence']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toSelectionJson() => {
        'transaction_id': transactionId,
        'offer_id': offerId,
        'product_ids': productIds,
      };
}

class FlightOffer {
  final String id;
  final FlightProviderRef provider;
  final List<FlightItinerary> itineraries;
  final FlightMoney totalPrice;
  final String? cabin;
  final String? fareName;
  final DateTime? expiresAt;

  const FlightOffer({
    required this.id,
    required this.provider,
    required this.itineraries,
    required this.totalPrice,
    this.cabin,
    this.fareName,
    this.expiresAt,
  });

  factory FlightOffer.fromJson(Map<String, dynamic> json) {
    return FlightOffer(
      id: json['id']?.toString() ?? '',
      provider: FlightProviderRef.fromJson(
        Map<String, dynamic>.from(json['provider'] as Map? ?? const {}),
      ),
      itineraries: (json['itineraries'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => FlightItinerary.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false),
      totalPrice: FlightMoney.fromJson(
        Map<String, dynamic>.from(json['total_price'] as Map? ?? const {}),
      ),
      cabin: json['cabin']?.toString(),
      fareName: json['fare_name']?.toString(),
      expiresAt: DateTime.tryParse(json['expires_at']?.toString() ?? ''),
    );
  }

  FlightItinerary? get outbound =>
      itineraries.isEmpty ? null : itineraries.first;

  String get airlineLabel {
    final first = outbound?.segments.isNotEmpty == true
        ? outbound!.segments.first.carrier
        : null;
    if (first == null) return 'Airline';
    return first.displayName;
  }

  String get routeLabel {
    if (outbound == null) return '';
    return '${outbound!.origin.code} → ${outbound!.destination.code}';
  }
}

class FlightSearchResult {
  final List<FlightOffer> offers;
  final bool nextLegRequired;
  final String provider;
  final String? transactionId;
  final List<String> warnings;

  const FlightSearchResult({
    required this.offers,
    required this.nextLegRequired,
    required this.provider,
    this.transactionId,
    this.warnings = const [],
  });

  factory FlightSearchResult.fromJson(Map<String, dynamic> json) {
    return FlightSearchResult(
      offers: (json['offers'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => FlightOffer.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false),
      nextLegRequired: json['next_leg_required'] == true,
      provider: json['provider']?.toString() ?? 'travelport',
      transactionId: json['transaction_id']?.toString(),
      warnings: (json['warnings'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
    );
  }
}

class FlightOfferValidation {
  final FlightOffer offer;
  final bool priceChanged;
  final FlightMoney? previousPrice;
  final bool expired;

  const FlightOfferValidation({
    required this.offer,
    required this.priceChanged,
    this.previousPrice,
    required this.expired,
  });

  factory FlightOfferValidation.fromJson(Map<String, dynamic> json) {
    return FlightOfferValidation(
      offer: FlightOffer.fromJson(
        Map<String, dynamic>.from(json['offer'] as Map? ?? const {}),
      ),
      priceChanged: json['price_changed'] == true,
      previousPrice: json['previous_price'] is Map
          ? FlightMoney.fromJson(
              Map<String, dynamic>.from(json['previous_price'] as Map),
            )
          : null,
      expired: json['expired'] == true,
    );
  }
}

class FlightApiException implements Exception {
  final String message;
  final String? code;
  final int statusCode;

  FlightApiException(this.message, {this.code, this.statusCode = 400});

  bool get isExpired => code == 'offer_expired';
  bool get isUnavailable =>
      code == 'provider_unavailable' ||
      code == 'not_configured' ||
      code == 'provider_timeout' ||
      code == 'auth_failed';
  bool get needsSignIn => code == 'unauthorized' || statusCode == 401;

  @override
  String toString() => message;
}

String destinyProductTypeLabel(String raw) {
  switch (raw.trim().toLowerCase()) {
    case 'tour':
      return 'Tour';
    case 'stay':
    case 'accommodation':
      return 'Stay';
    case 'vehicle':
      return 'Vehicle';
    case 'flight':
      return 'Flight';
    default:
      return raw.isEmpty ? 'Booking' : raw;
  }
}
