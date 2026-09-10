import 'package:destiny/models/customer_booking.dart';
import 'package:destiny/models/customer_enquiry.dart';
import 'package:destiny/services/staff_api_client.dart';

class StaffUser {
  final String id;
  final String firebaseUid;
  final String email;
  final String displayName;
  final String role;
  final bool isActive;

  StaffUser({
    required this.id,
    required this.firebaseUid,
    required this.email,
    required this.displayName,
    required this.role,
    required this.isActive,
  });

  factory StaffUser.fromJson(Map<String, dynamic> json) {
    return StaffUser(
      id: json['id'].toString(),
      firebaseUid: json['firebase_uid']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      displayName: json['display_name']?.toString() ?? '',
      role: json['role']?.toString() ?? 'consultant',
      isActive: json['is_active'] == true,
    );
  }
}

class StaffCommerceRepository {
  StaffCommerceRepository({StaffApiClient? client})
      : _client = client ?? StaffApiClient();

  final StaffApiClient _client;

  Future<StaffUser> me() async {
    final res = await _client.postAction('staff_me');
    return StaffUser.fromJson(Map<String, dynamic>.from(res['data'] as Map));
  }

  Future<List<CustomerBooking>> listBookings({String? status}) async {
    final res = await _client.postAction('list_bookings', {
      if (status != null) 'status': status,
    });
    final list = res['data'] as List? ?? const [];
    return list
        .map((e) =>
            CustomerBooking.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(growable: false);
  }

  Future<CustomerBooking> getBooking(String bookingId) async {
    final res = await _client.postAction('get_booking', {
      'booking_id': bookingId,
    });
    return CustomerBooking.fromJson(
      Map<String, dynamic>.from(res['data'] as Map),
    );
  }

  Future<CustomerBooking> quoteBooking({
    required String bookingId,
    required double quotedTotal,
    String currency = 'USD',
    DateTime? quoteExpiresAt,
    String customerQuoteNote = '',
    String internalNote = '',
  }) async {
    final res = await _client.postAction('quote_booking', {
      'booking_id': bookingId,
      'quoted_total': quotedTotal,
      'currency': currency,
      if (quoteExpiresAt != null)
        'quote_expires_at': quoteExpiresAt.toIso8601String(),
      'customer_quote_note': customerQuoteNote,
      'internal_note': internalNote,
    });
    return CustomerBooking.fromJson(
      Map<String, dynamic>.from(res['data'] as Map),
    );
  }

  Future<CustomerBooking> transitionBooking({
    required String bookingId,
    required String toStatus,
    String reason = '',
  }) async {
    final res = await _client.postAction('transition_booking', {
      'booking_id': bookingId,
      'to_status': toStatus,
      if (reason.isNotEmpty) 'reason': reason,
    });
    return CustomerBooking.fromJson(
      Map<String, dynamic>.from(res['data'] as Map),
    );
  }

  Future<CustomerBooking> addBookingNote({
    required String bookingId,
    required String note,
    bool customerFacing = false,
  }) async {
    final res = await _client.postAction('add_booking_note', {
      'booking_id': bookingId,
      'note': note,
      'customer_facing': customerFacing,
    });
    return CustomerBooking.fromJson(
      Map<String, dynamic>.from(res['data'] as Map),
    );
  }

  Future<List<CustomerEnquiry>> listEnquiries({String? status}) async {
    final res = await _client.postAction('list_enquiries', {
      if (status != null) 'status': status,
    });
    final list = res['data'] as List? ?? const [];
    return list
        .map((e) =>
            CustomerEnquiry.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(growable: false);
  }

  Future<CustomerEnquiry> updateEnquiry({
    required String enquiryId,
    String? toStatus,
    String? customerResponseNote,
    String? internalNote,
  }) async {
    final res = await _client.postAction('update_enquiry', {
      'enquiry_id': enquiryId,
      if (toStatus != null) 'to_status': toStatus,
      if (customerResponseNote != null)
        'customer_response_note': customerResponseNote,
      if (internalNote != null) 'internal_note': internalNote,
    });
    return CustomerEnquiry.fromJson(
      Map<String, dynamic>.from(res['data'] as Map),
    );
  }

  Future<Map<String, dynamic>> convertEnquiry(String enquiryId) async {
    final res = await _client.postAction('convert_enquiry', {
      'enquiry_id': enquiryId,
    });
    return Map<String, dynamic>.from(res['data'] as Map);
  }
}
