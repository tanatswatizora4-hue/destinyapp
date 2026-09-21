import 'package:destiny/models/customer_enquiry.dart';
import 'package:destiny/models/flight_offer.dart';
import 'package:destiny/services/flight_api_client.dart';

class FlightSearchQuery {
  final String origin;
  final String destination;
  final DateTime departureDate;
  final DateTime? returnDate;
  final bool isReturn;
  final int adults;
  final int children;
  final int infants;
  final String cabinClass;

  const FlightSearchQuery({
    required this.origin,
    required this.destination,
    required this.departureDate,
    this.returnDate,
    required this.isReturn,
    required this.adults,
    required this.children,
    required this.infants,
    required this.cabinClass,
  });

  Map<String, dynamic> toJson() => {
        'origin': origin,
        'destination': destination,
        'departure_date': _ymd(departureDate),
        if (returnDate != null) 'return_date': _ymd(returnDate!),
        'trip_type': isReturn ? 'return' : 'one_way',
        'passengers': {
          'adults': adults,
          'children': children,
          'infants': infants,
        },
        'cabin_class': cabinClass,
      };

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class FlightCommerceRepository {
  FlightCommerceRepository({FlightApiClient? client})
      : _client = client ?? FlightApiClient();

  final FlightApiClient _client;

  Future<FlightSearchResult> search(FlightSearchQuery query) async {
    final res = await _client.postAction('search_flights', body: query.toJson());
    return FlightSearchResult.fromJson(
      Map<String, dynamic>.from(res['data'] as Map),
    );
  }

  Future<FlightSearchResult> nextLeg(FlightOffer outbound) async {
    final res = await _client.postAction(
      'next_leg_search',
      body: outbound.provider.toSelectionJson(),
    );
    return FlightSearchResult.fromJson(
      Map<String, dynamic>.from(res['data'] as Map),
    );
  }

  Future<FlightOfferValidation> validate({
    required List<FlightOffer> selections,
    FlightMoney? displayedPrice,
  }) async {
    final res = await _client.postAction('validate_offer', body: {
      'selections':
          selections.map((o) => o.provider.toSelectionJson()).toList(),
      if (displayedPrice != null) 'displayed_amount': displayedPrice.amount,
      if (displayedPrice != null)
        'displayed_currency': displayedPrice.currency,
    });
    return FlightOfferValidation.fromJson(
      Map<String, dynamic>.from(res['data'] as Map),
    );
  }

  Future<CustomerEnquiry> continueAsEnquiry({
    required FlightSearchQuery query,
    required List<FlightOffer> selections,
    bool needsAccommodation = false,
    bool needsInterchangeAssistance = false,
    bool needsTaxi = false,
    String notes = '',
  }) async {
    final res = await _client.postAction(
      'create_flight_enquiry',
      requireAuth: true,
      body: {
        ...query.toJson(),
        'selections':
            selections.map((o) => o.provider.toSelectionJson()).toList(),
        'needs_accommodation': needsAccommodation,
        'needs_interchange_assistance': needsInterchangeAssistance,
        'needs_taxi': needsTaxi,
        'notes': notes,
      },
    );
    return CustomerEnquiry.fromJson(
      Map<String, dynamic>.from(res['data'] as Map),
    );
  }
}
