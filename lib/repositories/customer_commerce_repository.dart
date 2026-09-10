import 'package:destiny/models/customer_booking.dart';
import 'package:destiny/models/customer_enquiry.dart';
import 'package:destiny/services/customer_api_client.dart';

class CustomerRepository {
  CustomerRepository({CustomerApiClient? client})
      : _client = client ?? CustomerApiClient();

  final CustomerApiClient _client;

  Future<CustomerProfile?> getProfile() async {
    final res = await _client.postAction('get_profile');
    final data = res['data'];
    if (data == null) return null;
    return CustomerProfile.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<CustomerProfile> upsertProfile({
    String? fullName,
    String? email,
    String? phone,
  }) async {
    final body = <String, dynamic>{};
    if (fullName != null) body['full_name'] = fullName;
    if (email != null) body['email'] = email;
    if (phone != null) body['phone'] = phone;
    final res = await _client.postAction('upsert_profile', body);
    return CustomerProfile.fromJson(
      Map<String, dynamic>.from(res['data'] as Map),
    );
  }
}

class EnquiryRepository {
  EnquiryRepository({CustomerApiClient? client})
      : _client = client ?? CustomerApiClient();

  final CustomerApiClient _client;

  Future<CustomerEnquiry> createEnquiry({
    required String kind,
    required Map<String, dynamic> payload,
  }) async {
    final res = await _client.postAction('create_enquiry', {
      'kind': kind,
      'payload': payload,
    });
    return CustomerEnquiry.fromJson(
      Map<String, dynamic>.from(res['data'] as Map),
    );
  }

  Future<List<CustomerEnquiry>> listMine() async {
    final res = await _client.postAction('list_enquiries');
    final list = res['data'] as List? ?? const [];
    return list
        .map((e) => CustomerEnquiry.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(growable: false);
  }

  Future<CustomerEnquiry> createFlightEnquiry({
    required String origin,
    required String destination,
    List<String> midPlaces = const [],
    required int numTravelers,
    required bool needsAccommodation,
    required bool needsInterchangeAssistance,
    required bool needsTaxi,
    DateTime? departureDate,
    DateTime? returnDate,
  }) async {
    final res = await _client.postAction('create_flight_enquiry', {
      'origin': origin,
      'destination': destination,
      'mid_places': midPlaces,
      'num_travelers': numTravelers,
      'needs_accommodation': needsAccommodation,
      'needs_interchange_assistance': needsInterchangeAssistance,
      'needs_taxi': needsTaxi,
      if (departureDate != null)
        'departure_date': departureDate.toIso8601String().substring(0, 10),
      if (returnDate != null)
        'return_date': returnDate.toIso8601String().substring(0, 10),
    });
    return CustomerEnquiry.fromJson(
      Map<String, dynamic>.from(res['data'] as Map),
    );
  }

  Future<CustomerEnquiry> close({required String enquiryId}) async {
    final res = await _client.postAction('close_enquiry', {
      'enquiry_id': enquiryId,
    });
    return CustomerEnquiry.fromJson(
      Map<String, dynamic>.from(res['data'] as Map),
    );
  }
}

class BookingRepository {
  BookingRepository({CustomerApiClient? client})
      : _client = client ?? CustomerApiClient();

  final CustomerApiClient _client;

  Future<CustomerBooking> createRequest({
    required String itemType,
    required int itemLegacyId,
    required String itemName,
    required int numTravelers,
    double? requestedEstimate,
    String currency = 'USD',
    DateTime? startDate,
    DateTime? endDate,
    List<String> imageRefs = const [],
    String customerNotes = '',
  }) async {
    final res = await _client.postAction('create_booking_request', {
      'item_type': itemType,
      'item_legacy_id': itemLegacyId,
      'item_name': itemName,
      'num_travelers': numTravelers,
      if (requestedEstimate != null) 'requested_estimate': requestedEstimate,
      'currency': currency,
      if (startDate != null)
        'start_date': startDate.toIso8601String().substring(0, 10),
      if (endDate != null)
        'end_date': endDate.toIso8601String().substring(0, 10),
      'item_image_refs': imageRefs,
      'customer_notes': customerNotes,
    });
    return CustomerBooking.fromJson(
      Map<String, dynamic>.from(res['data'] as Map),
    );
  }

  Future<List<CustomerBooking>> listMine() async {
    final res = await _client.postAction('list_bookings');
    final list = res['data'] as List? ?? const [];
    return list
        .map((e) =>
            CustomerBooking.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(growable: false);
  }

  Future<CustomerBooking> cancel({
    required String bookingId,
    String reason = '',
  }) async {
    final res = await _client.postAction('cancel_booking', {
      'booking_id': bookingId,
      if (reason.isNotEmpty) 'reason': reason,
    });
    return CustomerBooking.fromJson(
      Map<String, dynamic>.from(res['data'] as Map),
    );
  }
}
